//
//  UploadManager.m
//  FullWaferUpload
//
//  Created by Mac on 16/3/21.
//  Copyright © 2016年 ejiang. All rights reserved.
//

#import "UploadManager.h"
#import <AFNetworking.h>
#import <CommonCrypto/CommonDigest.h>

#define AppId       @"684935cc-1131-4d97-a748-93fac2ee50c1"
#define SecretKey   @"573e006f-2572-4107-acdf-0bb665b5a58a"
#define kBlockSize (1024 * 100)

//在使用 NSURLConnection 的时候需要用到的宏定义
//#define HMFileBoundary @"ejiang"
//#define HMNewLien @"\r\n"
//#define HMEncode(str) [str dataUsingEncoding:NSUTF8StringEncoding]

@interface UploadManager ()
///要上传的文件路径
@property (nonatomic, strong) NSString *filePath;
///要传输的二进制数据
@property (nonatomic, strong) NSData *data;
///服务器与本地的时间差
@property (nonatomic, assign) NSInteger gapTime;
///时间戳
@property (nonatomic, strong) NSString *timeSpan;
///MD5值
@property (nonatomic, strong) NSString *sign;
///上传方式
@property (nonatomic, assign) BOOL isFullWafer;
///上传文件类型
@property (nonatomic, assign) UPLOADTYPE uplaodType;
//分片上传特有的属性
///开始上传的偏移量
@property (nonatomic, assign) NSUInteger offset;

///是否是最后一块
@property (nonatomic, assign) BOOL isLast;
///块数据
//@property (nonatomic, strong) NSData *blockData;

@end

@implementation UploadManager
#pragma mark - 便利构造器
///便利构造器
+ (instancetype)manager {
    return [[UploadManager alloc] init];
}
#pragma mark -  UploadManager 类提供的上传接口
///上传接口
- (void)POSTFileWithFilePath:(NSString *)filePath uploadType:(UPLOADTYPE)uploadType isFullWafer:(BOOL)isFullWafer {
    self.filePath = filePath;
    self.uplaodType = uploadType;
    self.data = [NSData dataWithContentsOfFile:filePath];
    self.isFullWafer = isFullWafer;
    [self getServerTime];
}

#pragma mark - 获取时间戳的私有方法
///获取服务器时间
- (void)getServerTime {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager GET:@"http://fileapi.ejiang.com/api/Time/GetServerTime?appId=684935cc-1131-4d97-a748-93fac2ee50c1" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        //数据解析
        [self getdateWithResponseObj:responseObject];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        //
        NSLog(@"获取服务器时间失败");
        NSLog(@"%ld", (long)error.code);
        //将失败信息进行本地化存储,用于下次读取
        [self writeToPlistWithFilePath:self.filePath StartOffset:0 UploadType:self.uplaodType isFullWafer:self.isFullWafer];
    }];
}

///json 解析获取 NSDate 数据(服务器时间)
- (void)getdateWithResponseObj:(id)responseObject {
    //转化成字典
    NSDictionary *dicData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
    NSLog(@"%@", dicData);
    NSArray *DataArray = dicData[@"Data"];
    NSString *dateStr = DataArray[0];
    //获取服务器的时间(UTC)
    //将字符串转换成NSDate类型的
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [formatter setTimeZone:timeZone];
    NSDate *dateServer = [formatter dateFromString:dateStr];
    //获取时间差
    [self getGapWithServerDate:dateServer];
}

///获取时间差
- (void)getGapWithServerDate:(NSDate *)dateServer {
    //获取本地时间
    NSDate *dateCurrent = [[NSDate alloc] init];
    NSCalendar *gapCalender = [NSCalendar currentCalendar];
    unsigned int unitFlags = NSSecondCalendarUnit;
    NSDateComponents *components = [gapCalender components:unitFlags fromDate:dateServer toDate:dateCurrent options:0];
    NSInteger gapTime = (int)[components second];
    self.gapTime = gapTime;
    //获取时间戳之后判断是否分片上传
    if (_isFullWafer == YES) {
        //整片上传
        [self postUploadByFullWafer];
    } else {
        //文件分片上传入口方法
        NSData *data = [self.data subdataWithRange:NSMakeRange(0, kBlockSize)];
//        self.isLast = YES;
        [self postUploadByBlockWithData:data Offset:0 isLast:NO fileName:[self getFileNameByUUID]];
    }
}

///得到 timespan 13位时间戳
- (void)getTimeSpanWithGap:(NSInteger)gapTime {
    NSDate *localDate = [[NSDate alloc] init];
    NSDate *timeSpan = [NSDate dateWithTimeInterval:gapTime sinceDate:localDate];
    NSTimeInterval a = [localDate timeIntervalSince1970] * 1000;
    self.timeSpan = [NSString stringWithFormat:@"%.f", a];
}

#pragma mark - 获取 Sign 的私有方法
///获得 sign
- (NSString *)getSign {
    NSString *string;
    if (_isFullWafer == YES) {
        //整片上传
        //api/FileUpload/UploadFile/去掉反斜杠并在前边拼上SecretKey最后进行 MD5转码
        string = [NSString stringWithFormat:@"api/FileUpload/UploadFile/684935cc-1131-4d97-a748-93fac2ee50c1/%@", self.timeSpan];
        string = [string stringByReplacingOccurrencesOfString:@"/" withString:@""];
        string = [NSString stringWithFormat:@"%@%@", SecretKey, string];
    } else {
        //分片上传
        //api/FileUpload/UploadCarveFile/
        string = [NSString stringWithFormat:@"api/FileUpload/UploadCarveFile/684935cc-1131-4d97-a748-93fac2ee50c1/%@", self.timeSpan];
        string = [string stringByReplacingOccurrencesOfString:@"/" withString:@""];
        string = [NSString stringWithFormat:@"%@%@", SecretKey, string];
    }
    //字符串转全小写
    NSString *lowStr = [string lowercaseString];
    //字符串 MD5加密
    return [self MD5WithString:lowStr];
}

///MD5加密
- (NSString *)MD5WithString:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

#pragma mark - 获取随机的 UUID作为文件名
///获取随机的 UUID作为文件名
- (NSString *)getFileNameByUUID {
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    return CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuidRef));
}

#pragma mark - POST 整个文件上传的私有方法
///POST 整个文件上传
- (void)postUploadByFullWafer {
    //获取时间戳
    [self getTimeSpanWithGap:self.gapTime];
    //获取签名 sign
    self.sign = [self getSign];
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    NSString *urlStr = [NSString stringWithFormat:@"http://fileapi.ejiang.com/api/FileUpload/UploadFile/%@/%@/%@?relativeServerName=/ChildPlat/111.png", AppId, self.sign, self.timeSpan];
    //POST 上传
    AFHTTPRequestOperation *operation = [manager POST:urlStr parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        //上传数据
        NSString *typeStr;
        if (self.uplaodType == 0) {
            typeStr = @"video/m4v";
        } else {
            typeStr = @"image/png";
        }
        [formData appendPartWithFileData:self.data name:@"file" fileName:@"111" mimeType:typeStr];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        //上传成功
        NSDictionary *dicData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"%@", dicData);
        NSLog(@"ErrorMessage = %@", dicData[@"ErrorMessage"]);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        //上传失败
        NSLog(@"error %@", error);
        //整片上传文件,如果出错就直接记录文件相关信息,下次直接从0开始上传
        //将失败的任务信息写入到 plist 文件中
        [self writeToPlistWithFilePath:self.filePath StartOffset:self.offset UploadType:self.uplaodType isFullWafer:NO];
    }];
    [operation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        self.currentProgress = totalBytesWritten * 1.0 / totalBytesExpectedToWrite;
        NSLog(@"%.2f", totalBytesWritten * 1.0 / totalBytesExpectedToWrite);
    }];
}

#pragma mark - POST 文件分片上传的私有方法
///POST 文件分片上传
- (void)postUploadByBlockWithData:(NSData *)data Offset:(NSUInteger)offset isLast:(BOOL)isLast fileName:(NSString *)fileName {
    
    //获取时间戳
    [self getTimeSpanWithGap:self.gapTime];
    //获取 sign
    self.sign = [self getSign];
    NSString *blockFileName;
    if (self.uplaodType == videoType) {
        blockFileName = [NSString stringWithFormat:@"%@.m4v", fileName];
    } else {
        blockFileName = [NSString stringWithFormat:@"%@.png", fileName];
    }
    NSLog(@"%@", @(offset));
    //POST 请求接口
    NSString *urlStr = [NSString stringWithFormat:@"http://fileapi.ejiang.com/api/FileUpload/UploadCarveFile/%@/%@/%@?offset=%@&isLast=%@&relativeServerName=%@", AppId, self.sign, self.timeSpan, @(offset) ,isLast ? @"true" : @"false", blockFileName];
    //AFNetworking 的分段数据上传
    {
        //数据上传
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        [manager POST:urlStr parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            //上传数据
            NSString *typeStr;
            if (self.uplaodType == 0) {
                typeStr = @"video/m4v";
            } else {
                typeStr = @"image/png";
            }
            [formData appendPartWithFileData:data name:@"file" fileName:fileName mimeType:typeStr];
        } success:^(AFHTTPRequestOperation *operation, id responseObject) {
            //上传成功
            NSLog(@"上传成功");
            NSDictionary *dicData = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingAllowFragments error:nil];
            NSLog(@"%@", dicData);
            NSLog(@"ErrorMessage = %@", dicData[@"ErrorMessage"]);
            
            //获取下次上传的偏移量
            NSInteger StartOffset = [((dicData[@"Data"])[@"StartOffset"]) integerValue];
            //获取文件的总长度
            NSUInteger fileSizeBybyte = [self.data length];
            //上传进度
            self.currentProgress = StartOffset * 1.0 / fileSizeBybyte;
            //判断是否上传结束
            if (self.isLast == YES) {
                return;
            }
            
            //下次上传
            NSRange range;
            //设置下次上传的范围
            if (fileSizeBybyte - StartOffset < kBlockSize) {
                range = NSMakeRange(StartOffset, fileSizeBybyte - StartOffset);
                self.isLast = YES;
            } else {
                range = NSMakeRange(StartOffset, kBlockSize);
                self.isLast = NO;
            }
            //获取下次将要上传的数据
            NSData *nextData = [self.data subdataWithRange:range];
            self.offset = StartOffset;
            
            //上传下一段数据
            [self postUploadByBlockWithData:nextData Offset:StartOffset isLast:self.isLast fileName:fileName];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            //上传失败
            NSLog(@"error %@", error);
            //将失败的任务信息写入到 plist 文件中
            [self writeToPlistWithFilePath:self.filePath StartOffset:self.offset UploadType:self.uplaodType isFullWafer:NO];
        }];
    }
    //NSURLConnection的分段数据上传
    /*
    {
        NSURL *url = [NSURL URLWithString:urlStr];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:1 timeoutInterval:2.0f];
        request.HTTPMethod = @"POST";
        request.timeoutInterval = 15.0f;
        //拼接请求体数据
        NSMutableData *body = [NSMutableData data];
        
        [body appendData:HMEncode(@"--")];
        [body appendData:HMEncode(HMFileBoundary)];
        [body appendData:HMEncode(HMNewLien)];
        NSString *Disposition = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"", blockFileName];
        [body appendData:HMEncode(Disposition)];
        [body appendData:HMEncode(HMNewLien)];
        
        [body appendData:HMEncode(@"Content-Type: image/png")];
        [body appendData:HMEncode(HMNewLien)];
        
        [body appendData:HMEncode(HMNewLien)];
        [body appendData:data];
        [body appendData:HMEncode(HMNewLien)];
        
        [body appendData:HMEncode(@"--")];
        [body appendData:HMEncode(HMFileBoundary)];
        [body appendData:HMEncode(@"--")];
        [body appendData:HMEncode(HMNewLien)];
        
        request.HTTPBody = body;
        //设置请求头(告诉服务器这次传给你的是文件数据，告诉服务器现在发送的是一个文件上传请求)
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", HMFileBoundary];
        [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
        
        //开始上传
        NSError *error = nil;
        NSURLResponse *response = nil;
        NSLog(@"%lu", (unsigned long)offset);
        NSData *data2 = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (error == NULL) {
            NSLog(@"上传成功");
            NSDictionary *dicData = [NSJSONSerialization JSONObjectWithData:data2 options:NSJSONReadingAllowFragments error:nil];
            NSLog(@"%@", dicData);
            NSLog(@"ErrorMessage = %@", dicData[@"ErrorMessage"]);
            
            //判断是否上传结束
            if (self.isLast == YES) {
                return;
            }
            //获取下次上传的偏移量
            NSInteger StartOffset = [((dicData[@"Data"])[@"StartOffset"]) integerValue];
            //获取文件的总长度
            NSUInteger fileSizeBybyte = [self.data length];
            NSRange range;
            //设置下次上传的范围
            if (fileSizeBybyte - StartOffset < kBlockSize) {
                range = NSMakeRange(StartOffset, fileSizeBybyte - StartOffset);
                self.isLast = YES;
            } else {
                range = NSMakeRange(StartOffset, kBlockSize);
                self.isLast = NO;
            }
            //获取下次将要上传的数据
            NSData *nextData = [self.data subdataWithRange:range];
            
            //上传下一段数据
            [self postUploadByBlockWithData:nextData Offset:StartOffset isLast:self.isLast fileName:fileName];
        } else {
            //上传失败
            NSLog(@"error = %@", error);
            return;
        }
    }
    */
}

#pragma mark - 将上传失败的任务保存到 plist 文件中
///将上传失败的任务保存到 plist 文件中
- (void)writeToPlistWithFilePath:(NSString *)filePath StartOffset:(NSInteger)startOffset UploadType:(UPLOADTYPE)uploadType isFullWafer:(BOOL)isFullWafer {
//    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES) firstObject];
//    NSString *plistPath = [path stringByAppendingPathComponent:@"failure.plist"];
//    NSLog(@"%@", plistPath);
//    NSDictionary *dic = @{@"filePath":filePath, @"startOffset":@(startOffset), @"uploadType": @(uploadType), @"isFullwafer":(isFullWafer ? @"1": @"0")};
//
//    //文件是否存在
//    if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
//        [[NSFileManager defaultManager] createFileAtPath:plistPath contents:nil attributes:nil];
//    }
//    BOOL isSuccess = [dic writeToFile:plistPath atomically:YES];//写入文件
//    if (isSuccess) {
//        NSLog(@"写入成功");
//    } else {
//        NSLog(@"写入失败");
//    }
}

@end

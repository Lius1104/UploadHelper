//
//  UploadHelper.m
//  FullWaferUpload
//
//  Created by Mac on 16/3/23.
//  Copyright © 2016年 ejiang. All rights reserved.
//

#import "UploadHelper.h"

@implementation UploadHelper
#pragma mark - 便利构造器
//便利构造器 uploadArray
- (NSMutableArray *)uploadArray {
    if (!_uploadArray) {
        _uploadArray = [NSMutableArray array];
    }
    return _uploadArray;
}
//便利构造器 mainQueue
- (NSOperationQueue *)mainQueue {
    if (!_mainQueue) {
        _mainQueue = [[NSOperationQueue alloc] init];
        _mainQueue.maxConcurrentOperationCount = 2;
    }
    return _mainQueue;
}
# pragma mark - 单例方法
+ (UploadHelper *)manager {
    static UploadHelper *helper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[UploadHelper alloc] init];
    });
    return helper;
}
#pragma mark - 添加上传任务
- (void)addUploadTaskWithFilePath:(NSString *)filePath UploadType:(UPLOADTYPE)uploadType isFullWafer:(BOOL)isFullWafer {
    UploadManager *manager = [UploadManager manager];//manager方法是便利构造器
    [self.uploadArray addObject:manager];
//    NSData *data = [NSData dataWithContentsOfFile:filePath];
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        //添加上传任务
        [manager POSTFileWithFilePath:filePath uploadType:uploadType isFullWafer:isFullWafer];
    }];
    [self.mainQueue addOperation:operation];
}

//添加上传任务(filePathArray中存放的是文件路径,如果是批量文件上传,则有多个, 如果是单个文件上传则只有1个)
- (void)addUploadTaskWithFilePathArray:(NSArray *)filePathArray UploadType:(UPLOADTYPE) uploadtype isFullWafer:(BOOL)isfullWafer {
    //无论是批量任务还是单个任务,都用数组保存
    //所以创建数组, 将每一个创建出来的上传任务添加到 taskArray 中.
    NSMutableArray * taskArray = [NSMutableArray array];
    for (NSString *filePath in filePathArray) {
        UploadManager *manager = [UploadManager manager];//manager方法是便利构造器
        [taskArray addObject:manager];//将单个的上传任务添加到任务数组中
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            //添加上传任务
            [manager POSTFileWithFilePath:filePath uploadType:uploadtype isFullWafer:isfullWafer];
        }];
        [self.mainQueue addOperation:operation];//将单个任务添加到任务队列中
    }
    [self.uploadArray addObject:taskArray];//将 taskArray 添加到上传任务队列中
}

@end

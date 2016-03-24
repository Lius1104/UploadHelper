//
//  UploadHelper.h
//  FullWaferUpload
//
//  Created by Mac on 16/3/23.
//  Copyright © 2016年 ejiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UploadManager.h"
/**
 *  将 UploadManager 类的单一的上传任务添加到上传队列,实现多任务批量上传
 */
@interface UploadHelper : NSObject
@property (nonatomic, strong) NSMutableArray *uploadArray;//上传任务数组,其中包含的元素是 UploadManager 对象
@property (nonatomic, strong) NSOperationQueue *mainQueue;

//单例方法
+ (UploadHelper *)manager;
//添加上传任务
- (void)addUploadTaskWithFilePath:(NSString *)filePath UploadType:(UPLOADTYPE)uploadType isFullWafer:(BOOL)isFullWafer;
//添加上传任务(filePathArray中存放的是文件路径,如果是批量文件上传,则有多个, 如果是单个文件上传则只有1个)
- (void)addUploadTaskWithFilePathArray:(NSArray *)filePathArray UploadType:(UPLOADTYPE) uploadtype isFullWafer:(BOOL)isfullWafer;

@end

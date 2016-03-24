//
//  UploadManager.h
//  FullWaferUpload
//
//  Created by Mac on 16/3/21.
//  Copyright © 2016年 ejiang. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {//上传资源类型
    videoType,              //视频类型,从系统相册获取的视频都是 m4v 类型
    imageType               //图片类型,从系统相册获取的图片都是 png 类型
}UPLOADTYPE;

typedef enum {//视频转换状态
    CanNotFind = -1,        //找不到该转换任务
    InTransform,            //转换中
    SuccessTransform        //转换成功
}VIDEOTRANSFORMSTATUS;

/*将上传接口封装,实现单个文件上传的方法.向外界提供一个属性变量,用于检测上传任务的上传进度;向外界提供一个上传的接口,在该方法中有三个参数, 分别是:将要上传的数据,上传的数据类型(png, m4v), 上传方式(整片上传,分片上传)*/
@interface UploadManager : NSObject

@property (nonatomic, assign) float currentProgress;///当前上传进度
#pragma mark - 便利构造器
//便利构造器
+ (instancetype)manager;

//上传接口
- (void)POSTFileWithFilePath:(NSString *)filePath uploadType:(UPLOADTYPE)uploadType isFullWafer:(BOOL)isFullWafer;

@end


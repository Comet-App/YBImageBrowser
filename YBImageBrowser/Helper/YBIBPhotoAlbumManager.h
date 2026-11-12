//
//  YBIBPhotoAlbumManager.h
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2018/8/28.
//  Copyright © 2018年 波儿菜. All rights reserved.
//

#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@interface YBIBPhotoAlbumManager : NSObject

/**
 Get photo album authorization (add-only on iOS 14+, which is all that saving needs).
 Callbacks are on the main thread.
 */
+ (void)getPhotoAlbumAuthorizationSuccess:(void(^)(void))success failed:(void(^)(void))failed;

/**
 Save image data (keeps GIF/APNG/HEIC data intact) to the photo album. Completion is on the main thread.
 */
+ (void)saveImageData:(NSData *)data completion:(void(^)(NSError * _Nullable error))completion;

/**
 Save an image to the photo album. Completion is on the main thread.
 */
+ (void)saveImage:(UIImage *)image completion:(void(^)(NSError * _Nullable error))completion;

/**
 Save the video file at 'fileURL' to the photo album. Completion is on the main thread.
 */
+ (void)saveVideoWithFileURL:(NSURL *)fileURL completion:(void(^)(NSError * _Nullable error))completion;

/**
 Get 'AVAsset' by 'PHAsset' asynchronously, callback is in child thread.
 */
+ (void)getAVAssetWithPHAsset:(PHAsset *)phAsset completion:(void(^)(AVAsset * _Nullable asset))completion;

/**
 Get 'ImageData' by 'PHAsset' synchronously, callback is in child thread.
 */
+ (void)getImageDataWithPHAsset:(PHAsset *)phAsset completion:(void(^)(NSData * _Nullable data))completion;

@end

NS_ASSUME_NONNULL_END

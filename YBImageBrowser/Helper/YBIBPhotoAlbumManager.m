//
//  YBIBPhotoAlbumManager.m
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2018/8/28.
//  Copyright © 2018年 波儿菜. All rights reserved.
//

#import "YBIBPhotoAlbumManager.h"
#import "YBIBUtilities.h"

@implementation YBIBPhotoAlbumManager

+ (void)getAVAssetWithPHAsset:(PHAsset *)phAsset completion:(nonnull void (^)(AVAsset * _Nullable))completion {
    PHVideoRequestOptions *options = [PHVideoRequestOptions new];
    options.networkAccessAllowed = YES;
    [[PHImageManager defaultManager] requestAVAssetForVideo:phAsset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        completion(asset);
    }];
}

+ (void)getImageDataWithPHAsset:(PHAsset *)phAsset completion:(nonnull void (^)(NSData * _Nullable))completion {
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.networkAccessAllowed = YES;
    options.resizeMode = PHImageRequestOptionsResizeModeNone;
    // Only when this property is YES, the callback will in child thread.
    options.synchronous = YES;
    [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:phAsset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, CGImagePropertyOrientation orientation, NSDictionary * _Nullable info) {
        BOOL complete = ![[info objectForKey:PHImageCancelledKey] boolValue] && ![info objectForKey:PHImageErrorKey] && ![[info objectForKey:PHImageResultIsDegradedKey] boolValue];
        if (complete && imageData) {
            completion(imageData);
        } else {
            completion(nil);
        }
    }];
}

#pragma mark - authorization

+ (BOOL)isAuthorizedStatus:(PHAuthorizationStatus)status {
    if (status == PHAuthorizationStatusAuthorized) return YES;
    if (@available(iOS 14.0, *)) {
        if (status == PHAuthorizationStatusLimited) return YES;
    }
    return NO;
}

+ (void)getPhotoAlbumAuthorizationSuccess:(void(^)(void))success failed:(void(^)(void))failed {
    void(^finish)(PHAuthorizationStatus) = ^(PHAuthorizationStatus status) {
        YBIB_DISPATCH_ASYNC_MAIN(^{
            if ([self isAuthorizedStatus:status]) {
                if (success) success();
            } else {
                if (failed) failed();
            }
        })
    };

    // Saving only needs add-only access, which needs 'NSPhotoLibraryAddUsageDescription' in 'Info.plist'.
    PHAuthorizationStatus status;
    if (@available(iOS 14.0, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelAddOnly];
    } else {
        status = [PHPhotoLibrary authorizationStatus];
    }
    if (status != PHAuthorizationStatusNotDetermined) {
        finish(status);
        return;
    }
    if (@available(iOS 14.0, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:finish];
    } else {
        [PHPhotoLibrary requestAuthorization:finish];
    }
}

#pragma mark - save

+ (void)performSaveChanges:(dispatch_block_t)changes completion:(void(^)(NSError * _Nullable error))completion {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:changes completionHandler:^(BOOL success, NSError * _Nullable error) {
        YBIB_DISPATCH_ASYNC_MAIN(^{
            if (!completion) return;
            if (success) {
                completion(nil);
            } else {
                completion(error ?: [NSError errorWithDomain:@"YBIBPhotoAlbumManager" code:-1 userInfo:nil]);
            }
        })
    }];
}

+ (void)saveImageData:(NSData *)data completion:(void(^)(NSError * _Nullable error))completion {
    [self performSaveChanges:^{
        [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto data:data options:nil];
    } completion:completion];
}

+ (void)saveImage:(UIImage *)image completion:(void(^)(NSError * _Nullable error))completion {
    [self performSaveChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completion:completion];
}

+ (void)saveVideoWithFileURL:(NSURL *)fileURL completion:(void(^)(NSError * _Nullable error))completion {
    [self performSaveChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
    } completion:completion];
}

@end

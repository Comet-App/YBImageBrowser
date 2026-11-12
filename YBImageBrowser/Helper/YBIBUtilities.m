//
//  YBIBUtilities.m
//  YBImageBrowserDemo
//
//  Created by 杨少 on 2018/4/11.
//  Copyright © 2018年 波儿菜. All rights reserved.
//

#import "YBIBUtilities.h"
#import <sys/utsname.h>


static UIWindowScene * _Nullable YBIBActiveWindowScene(void) {
    UIWindowScene *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) return windowScene;
            }
            if (!fallback) fallback = windowScene;
        } else if (!fallback && scene.activationState == UISceneActivationStateForegroundInactive) {
            fallback = windowScene;
        }
    }
    return fallback;
}

UIWindow * _Nullable YBIBKeyWindow(void) {
    UIWindowScene *scene = YBIBActiveWindowScene();
    UIWindow *firstNormal = nil;
    for (UIWindow *window in scene.windows) {
        if (window.isKeyWindow) return window;
        if (!firstNormal && window.windowLevel == UIWindowLevelNormal && !window.isHidden) firstNormal = window;
    }
    if (firstNormal) return firstNormal;
    // Apps without scenes: fall back to the application delegate's window.
    id<UIApplicationDelegate> delegate = UIApplication.sharedApplication.delegate;
    if ([delegate respondsToSelector:@selector(window)]) return delegate.window;
    return nil;
}

UIWindow * _Nullable YBIBNormalWindow(void) {
    UIWindow *window = YBIBKeyWindow();
    if (window && window.windowLevel != UIWindowLevelNormal) {
        for (UIWindow *temp in window.windowScene.windows) {
            if (temp.windowLevel == UIWindowLevelNormal && !temp.isHidden) {
                return temp;
            }
        }
    }
    return window;
}

UIInterfaceOrientation YBIBInterfaceOrientation(void) {
    UIWindowScene *scene = YBIBKeyWindow().windowScene ?: YBIBActiveWindowScene();
    return scene ? scene.interfaceOrientation : UIInterfaceOrientationPortrait;
}

UIViewController * _Nullable YBIBTopController(void) {
    return YBIBTopControllerByWindow(YBIBNormalWindow());
}

UIViewController * _Nullable YBIBTopControllerByWindow(UIWindow *window) {
    if (!window) return nil;
        
    UIViewController *top = nil;
    id nextResponder;
    if (window.subviews.count > 0) {
        UIView *frontView = [window.subviews objectAtIndex:0];
        nextResponder = frontView.nextResponder;
    }
    if (nextResponder && [nextResponder isKindOfClass:UIViewController.class]) {
        top = nextResponder;
    } else {
        top = window.rootViewController;
    }
    
    while ([top isKindOfClass:UITabBarController.class] || [top isKindOfClass:UINavigationController.class] || top.presentedViewController) {
        if ([top isKindOfClass:UITabBarController.class]) {
            top = ((UITabBarController *)top).selectedViewController;
        } else if ([top isKindOfClass:UINavigationController.class]) {
            top = ((UINavigationController *)top).topViewController;
        } else if (top.presentedViewController) {
            top = top.presentedViewController;
        }
    }
    return top;
}

BOOL YBIBLowMemory(void) {
    static BOOL lowMemory = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        unsigned long long physicalMemory = [[NSProcessInfo processInfo] physicalMemory];
        lowMemory = physicalMemory > 0 && physicalMemory < 1024 * 1024 * 1500;
    });
    return lowMemory;
}

BOOL YBIBIsIphoneXSeries(void) {
    return YBIBStatusbarHeight() > 20;
}

CGFloat YBIBStatusbarHeight(void) {
    UIWindow *window = YBIBKeyWindow();
    CGFloat height = window.safeAreaInsets.top;
    if (height <= 0) {
        height = window.windowScene.statusBarManager.statusBarFrame.size.height;
    }
    if (height <= 0) {
        height = 20;
    }
    return height;
}

CGFloat YBIBSafeAreaBottomHeight(void) {
    return YBIBKeyWindow().safeAreaInsets.bottom;
}

UIImage *YBIBSnapshotView(UIView *view) {
    // 'UIGraphicsBeginImageContext' throws on an empty size since iOS 17, so guard and use the renderer.
    if (!view || view.bounds.size.width <= 0 || view.bounds.size.height <= 0) return nil;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:view.bounds.size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
    }];
}

UIEdgeInsets YBIBPaddingByBrowserOrientation(UIDeviceOrientation orientation) {
    UIEdgeInsets padding = UIEdgeInsetsZero;
    if (!YBIBIsIphoneXSeries()) return padding;
    
    UIDeviceOrientation barOrientation = (UIDeviceOrientation)YBIBInterfaceOrientation();
    
    if (UIDeviceOrientationIsLandscape(orientation)) {
        BOOL same = orientation == barOrientation;
        BOOL reverse = !same && UIDeviceOrientationIsLandscape(barOrientation);
        if (same) {
            padding.bottom = YBIBSafeAreaBottomHeight();
            padding.top = 0;
        } else if (reverse) {
            padding.top = YBIBSafeAreaBottomHeight();
            padding.bottom = 0;
        }
        padding.left = padding.right = MAX(YBIBSafeAreaBottomHeight(), YBIBStatusbarHeight());
    } else {
        if (orientation == UIDeviceOrientationPortrait) {
            padding.top = YBIBStatusbarHeight();
            padding.bottom = barOrientation == UIDeviceOrientationPortrait ? YBIBSafeAreaBottomHeight() : 0;
        } else {
            padding.bottom = YBIBStatusbarHeight();
            padding.top = barOrientation == UIDeviceOrientationPortrait ? YBIBSafeAreaBottomHeight() : 0;
        }
        padding.left = padding.right = UIDeviceOrientationIsLandscape(barOrientation) ? YBIBSafeAreaBottomHeight() : 0 ;
    }
    return padding;
}


@implementation YBIBUtilities

@end

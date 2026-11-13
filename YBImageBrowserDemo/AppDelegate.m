//
//  AppDelegate.m
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/6/5.
//  Copyright © 2019 波儿菜. All rights reserved.
//

#import "AppDelegate.h"
#import "MainController.h"
#import "MainNavigationController.h"
#import "YBImageBrowser.h"
#import "YBIBVideoData.h"

@interface AppDelegate () <YBImageBrowserDelegate>

@end

@implementation AppDelegate

/// Logged by the continuous smoke test, so page tracking can be checked in the console.
- (void)yb_imageBrowser:(YBImageBrowser *)imageBrowser pageChanged:(NSInteger)page data:(id<YBIBDataProtocol>)data {
    NSLog(@"[YBIBSmoke] page %ld", (long)page);
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    MainController *vc = [MainController new];
    
    MainNavigationController *nvc = [[MainNavigationController alloc] initWithRootViewController:vc];
    nvc.navigationBar.translucent = NO;

    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.rootViewController = nvc;
    [_window makeKeyAndVisible];
    [self showSmokeTestBrowserIfNeeded];
    return YES;
}

/// Debug hook: launch with `-YBIBSmokeTestPage <n>` to open a browser of local media on page n,
/// so the browser can be checked (screenshots, automation) without tapping through the demo.
/// Add `-YBIBSmokeTestContinuous YES` for continuous vertical mode (images only, repeated, no tool views).
- (void)showSmokeTestBrowserIfNeeded {
    NSString *pageArg = [[NSUserDefaults standardUserDefaults] stringForKey:@"YBIBSmokeTestPage"];
    if (pageArg.length == 0) return;
    BOOL continuous = [[NSUserDefaults standardUserDefaults] boolForKey:@"YBIBSmokeTestContinuous"];

    NSMutableArray *datas = [NSMutableArray array];
    NSArray *names = @[@"localImage0.jpg", @"localImage1.gif", @"localBigImage0.jpeg", @"localLongImage0.jpeg"];
    for (NSInteger round = 0; round < (continuous ? 3 : 1); ++round) {
        for (NSString *name in names) {
            YBIBImageData *data = [YBIBImageData new];
            data.imageName = name;
            [datas addObject:data];
        }
    }
    if (!continuous) {
        YBIBVideoData *video = [YBIBVideoData new];
        video.videoURL = [[NSBundle mainBundle] URLForResource:@"localVideo0" withExtension:@"mp4"];
        [datas addObject:video];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        YBImageBrowser *browser = [YBImageBrowser new];
        if (continuous) {
            browser.scrollMode = YBIBScrollModeContinuousVertical;
            browser.toolViewHandlers = @[];
            browser.delegate = self;
        }
        browser.dataSourceArray = datas;
        browser.currentPage = pageArg.integerValue;
        [browser show];
        [self rotateForSmokeTestIfNeeded];
    });
}

/// Debug hook: '-YBIBSmokeTestRotate YES' rotates to landscape 1.5s after showing.
/// With '-YBIBSmokeTestAllOrientations YES' the app's interface rotates (browser follows it);
/// otherwise only the device orientation changes (browser rotates itself).
- (void)rotateForSmokeTestIfNeeded {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"YBIBSmokeTestRotate"]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"YBIBSmokeTestAllOrientations"]) {
            if (@available(iOS 16.0, *)) {
                UIWindowScene *scene = self.window.windowScene;
                UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeRight];
                [scene requestGeometryUpdateWithPreferences:preferences errorHandler:^(NSError * _Nonnull error) {
                    NSLog(@"[YBIBSmoke] geometry update failed: %@", error);
                }];
            }
        } else {
            // The simulator cannot fake the sensor, so drive the browser's internal rotation directly (debug only).
            YBImageBrowser *browser = nil;
            for (UIView *view in self.window.subviews) {
                if ([view isKindOfClass:YBImageBrowser.class]) browser = (YBImageBrowser *)view;
            }
            id handler = [browser valueForKey:@"rotationHandler"];
            SEL selector = NSSelectorFromString(@"rotateToDeviceOrientation:");
            if ([handler respondsToSelector:selector]) {
                ((void (*)(id, SEL, UIDeviceOrientation))[handler methodForSelector:selector])(handler, selector, UIDeviceOrientationLandscapeLeft);
            }
        }
    });
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskAll;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end

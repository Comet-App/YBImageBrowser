//
//  YBImageBrowser+Internal.h
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/7/1.
//  Copyright © 2019 杨波. All rights reserved.
//

#import "YBImageBrowser.h"
#import "YBIBContainerView.h"

NS_ASSUME_NONNULL_BEGIN

@interface YBImageBrowser ()

@property (nonatomic, strong) YBIBContainerView *containerView;

- (void)implementGetBaseInfoProtocol:(id<YBIBGetBaseInfoProtocol>)obj;

/// Injects the blocks that depend on the page index: a per-page 'yb_containerSize' (in continuous mode each
/// page has its own size) and, for data objects, 'yb_contentSizeResolved'.
- (void)implementPageInfo:(id<YBIBGetBaseInfoProtocol>)obj page:(NSInteger)page;

/// Records the natural size of a page's content; in continuous mode this resizes the page and keeps the visible content in place.
- (void)contentSizeResolved:(CGSize)size forPage:(NSInteger)page;

/// The size of a page in continuous mode (full width, height from the content's aspect ratio or a placeholder).
- (CGSize)continuousSizeForPage:(NSInteger)page;

@property (nonatomic, weak, nullable) NSObject *hiddenProjectiveView;

@end

NS_ASSUME_NONNULL_END

//
//  YBIBLogicTests.m
//  YBImageBrowserDemoTests
//
//  Unit tests for the pure / deterministic parts of YBImageBrowser.
//

#import <XCTest/XCTest.h>
#import "YBImageBrowser.h"
#import "YBImageBrowser+Internal.h"
#import "YBImage.h"
#import "YBIBImageData+Internal.h"
#import "YBIBImageCache+Internal.h"
#import "YBIBVideoData.h"
#import "YBIBVideoActionBar.h"
#import "YBIBUtilities.h"

extern CGFloat YBIBRotationAngle(UIDeviceOrientation startOrientation, UIDeviceOrientation endOrientation);

@interface YBIBVideoActionBar (Tests)
+ (NSAttributedString *)timeformatFromSeconds:(NSInteger)seconds;
@end

#pragma mark - pixel helpers

/// A raw image where every pixel has a unique colour, so any wrong mapping shows up.
static CGImageRef YBIBTestCreatePatternImage(size_t width, size_t height) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast);
    uint8_t *data = CGBitmapContextGetData(ctx);
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < width; ++x) {
            uint8_t *p = data + (y * width + x) * 4;
            p[0] = (uint8_t)(x * 5);
            p[1] = (uint8_t)(y * 7);
            p[2] = (uint8_t)((x * 3 + y * 11) % 256);
            p[3] = 255;
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    return image;
}

/// Renders 'image' (orientation applied by UIKit) and returns RGBA bytes of the given display rect.
static NSData *YBIBTestRenderedPixels(UIImage *image, CGRect displayRect) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = image.scale;
    format.opaque = YES;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:displayRect.size format:format];
    UIImage *rendered = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [image drawAtPoint:CGPointMake(-displayRect.origin.x, -displayRect.origin.y)];
    }];
    CGImageRef cg = rendered.CGImage;
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    NSMutableData *bytes = [NSMutableData dataWithLength:w * h * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(bytes.mutableBytes, w, h, 8, w * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    return bytes;
}

@interface YBIBLogicTests : XCTestCase
@end

@implementation YBIBLogicTests

#pragma mark - cropping

- (void)testPixelRectMatchesUIKitRenderingForAllOrientations {
    const size_t rawW = 40, rawH = 30;
    const CGFloat scale = 2;
    CGImageRef raw = YBIBTestCreatePatternImage(rawW, rawH);

    UIImageOrientation orientations[] = {
        UIImageOrientationUp, UIImageOrientationDown, UIImageOrientationLeft, UIImageOrientationRight,
        UIImageOrientationUpMirrored, UIImageOrientationDownMirrored, UIImageOrientationLeftMirrored, UIImageOrientationRightMirrored,
    };
    for (int i = 0; i < 8; ++i) {
        UIImageOrientation orientation = orientations[i];
        UIImage *image = [UIImage imageWithCGImage:raw scale:scale orientation:orientation];
        // An off-centre rect, in logical points of the displayed image.
        CGRect displayRect = CGRectMake(2, 3, 5, 4);

        NSData *expected = YBIBTestRenderedPixels(image, displayRect);

        CGRect pixelRect = YBIBPixelRectForDisplayRect(displayRect, image.size, scale, orientation);
        CGImageRef cropped = CGImageCreateWithImageInRect(raw, pixelRect);
        XCTAssertTrue(cropped != NULL, @"orientation %ld", (long)orientation);
        UIImage *croppedImage = [UIImage imageWithCGImage:cropped scale:scale orientation:orientation];
        NSData *actual = YBIBTestRenderedPixels(croppedImage, (CGRect){CGPointZero, displayRect.size});
        CGImageRelease(cropped);

        XCTAssertEqualObjects(actual, expected, @"Wrong crop for orientation %ld", (long)orientation);
    }
    CGImageRelease(raw);
}

#pragma mark - cache

- (void)testResidentImagesSurviveEvictionAndOthersDoNot {
    YBIBImageCache *cache = [YBIBImageCache new];
    cache.imageCacheCountLimit = 1;
    UIImage *image = [UIImage new];

    [cache setImage:image type:YBIBImageCacheTypeOrigin forKey:@"resident" resident:YES];
    [cache setImage:image type:YBIBImageCacheTypeOrigin forKey:@"evictable" resident:NO];
    for (int i = 0; i < 20; ++i) {
        [cache setImage:image type:YBIBImageCacheTypeOrigin forKey:[NSString stringWithFormat:@"filler%d", i] resident:NO];
    }
    XCTAssertNotNil([cache imageForKey:@"resident" type:YBIBImageCacheTypeOrigin]);
    XCTAssertNil([cache imageForKey:@"evictable" type:YBIBImageCacheTypeOrigin], @"non-resident images must obey the count limit");

    [cache removeResidentForKey:@"resident"];
    for (int i = 0; i < 20; ++i) {
        [cache setImage:image type:YBIBImageCacheTypeOrigin forKey:[NSString stringWithFormat:@"more%d", i] resident:NO];
    }
    XCTAssertNil([cache imageForKey:@"resident" type:YBIBImageCacheTypeOrigin]);
}

- (void)testSettingOneImageTypeKeepsTheOtherFromAResidentPack {
    YBIBImageCache *cache = [YBIBImageCache new];
    cache.imageCacheCountLimit = 1;
    UIImage *origin = [UIImage new], *compressed = [UIImage new];
    [cache setImage:origin type:YBIBImageCacheTypeOrigin forKey:@"k" resident:YES];
    // Push 'k' out of the NSCache; it stays in the resident cache.
    [cache setImage:origin type:YBIBImageCacheTypeOrigin forKey:@"other" resident:NO];
    [cache setImage:compressed type:YBIBImageCacheTypeCompressed forKey:@"k" resident:YES];
    XCTAssertEqual([cache imageForKey:@"k" type:YBIBImageCacheTypeOrigin], origin);
    XCTAssertEqual([cache imageForKey:@"k" type:YBIBImageCacheTypeCompressed], compressed);
}

#pragma mark - browser

- (void)testCurrentPageIsClamped {
    YBImageBrowser *browser = [YBImageBrowser new];
    browser.currentPage = 5;
    XCTAssertEqual(browser.currentPage, 5, @"kept until data exists, then clamped on show");

    browser.dataSourceArray = @[[YBIBImageData new], [YBIBImageData new], [YBIBImageData new]];
    browser.currentPage = 5;
    XCTAssertEqual(browser.currentPage, 2);
    browser.currentPage = -3;
    XCTAssertEqual(browser.currentPage, 0);
}

#pragma mark - utilities

- (void)testSnapshotOfMissingOrEmptyViewDoesNotThrow {
    XCTAssertNoThrow(YBIBSnapshotView(nil));
    XCTAssertNil(YBIBSnapshotView(nil));
    XCTAssertNil(YBIBSnapshotView([UIView new]));
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    XCTAssertNotNil(YBIBSnapshotView(view));
}

- (void)testRotationAngle {
    XCTAssertEqualWithAccuracy(YBIBRotationAngle(UIDeviceOrientationPortrait, UIDeviceOrientationPortrait), 0, 0.0001);
    XCTAssertEqualWithAccuracy(YBIBRotationAngle(UIDeviceOrientationPortrait, UIDeviceOrientationLandscapeLeft), M_PI_2, 0.0001);
    XCTAssertEqualWithAccuracy(YBIBRotationAngle(UIDeviceOrientationPortrait, UIDeviceOrientationLandscapeRight), -M_PI_2, 0.0001);
    XCTAssertEqualWithAccuracy(YBIBRotationAngle(UIDeviceOrientationLandscapeLeft, UIDeviceOrientationLandscapeRight), -M_PI, 0.0001);
    // Never rotate the long way round.
    XCTAssertEqualWithAccuracy(YBIBRotationAngle(UIDeviceOrientationLandscapeRight, UIDeviceOrientationPortraitUpsideDown), -M_PI_2, 0.0001);
}

#pragma mark - video

- (void)testInvalidVideoURLStringDoesNotCrash {
    // nil used to reach '+[AVURLAsset URLAssetWithURL:nil]', which throws; an empty URL is equally unusable.
    YBIBVideoData *data = [YBIBVideoData new];
    XCTAssertNoThrow(data.videoURL = (NSURL *)@"");
    XCTAssertNil(data.videoAVAsset);
    XCTAssertNoThrow(data.videoURL = nil);
    XCTAssertNil(data.videoAVAsset);
}

- (void)testTimeFormat {
    XCTAssertEqualObjects([YBIBVideoActionBar timeformatFromSeconds:0].string, @"00:00");
    XCTAssertEqualObjects([YBIBVideoActionBar timeformatFromSeconds:59].string, @"00:59");
    XCTAssertEqualObjects([YBIBVideoActionBar timeformatFromSeconds:3599].string, @"59:59");
    XCTAssertEqualObjects([YBIBVideoActionBar timeformatFromSeconds:3600].string, @"01:00:00");
    XCTAssertEqualObjects([YBIBVideoActionBar timeformatFromSeconds:3661].string, @"01:01:01");
}

#pragma mark - continuous mode

static const CGFloat kHostWidth = 300, kHostHeight = 600;

/// Shows a browser in an off-screen host view, synchronously (no transitions, no tool views).
- (YBImageBrowser *)showBrowserWithMode:(YBIBScrollMode)mode pageCount:(NSInteger)count {
    NSMutableArray *datas = [NSMutableArray array];
    for (NSInteger i = 0; i < count; ++i) [datas addObject:[YBIBImageData new]];
    return [self showBrowserWithMode:mode datas:datas];
}

- (YBImageBrowser *)showBrowserWithMode:(YBIBScrollMode)mode datas:(NSArray *)datas {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kHostWidth, kHostHeight)];
    YBImageBrowser *browser = [YBImageBrowser new];
    browser.scrollMode = mode;
    browser.shouldHideStatusBar = NO;
    browser.toolViewHandlers = @[];
    browser.supportedOrientations = UIInterfaceOrientationMaskPortrait;
    browser.defaultAnimatedTransition.showType = YBIBTransitionTypeNone;
    browser.defaultAnimatedTransition.hideType = YBIBTransitionTypeNone;
    browser.dataSourceArray = datas;
    [browser showToView:host containerSize:host.bounds.size];
    [browser.collectionView layoutIfNeeded];
    return browser;
}

- (CGRect)frameOfPage:(NSInteger)page inBrowser:(YBImageBrowser *)browser {
    [browser.collectionView layoutIfNeeded];
    return [browser.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:page inSection:0]].frame;
}

- (UICollectionViewLayoutAttributes *)attributesForItem:(NSInteger)item frame:(CGRect)frame {
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForItem:item inSection:0]];
    attributes.frame = frame;
    return attributes;
}

- (void)testDefaultScrollModeIsPaged {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModePaged pageCount:3];
    XCTAssertEqual([YBImageBrowser new].scrollMode, YBIBScrollModePaged);
    XCTAssertTrue(browser.collectionView.pagingEnabled);
    XCTAssertEqual(browser.collectionView.layout.scrollDirection, UICollectionViewScrollDirectionHorizontal);
    XCTAssertTrue(CGSizeEqualToSize([self frameOfPage:1 inBrowser:browser].size, CGSizeMake(kHostWidth, kHostHeight)));
}

- (void)testSwitchingToContinuousModeOnReloadUsesPerPageSizes {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModePaged pageCount:3];
    browser.scrollMode = YBIBScrollModeContinuousVertical;
    [browser reloadData];
    [browser contentSizeResolved:CGSizeMake(100, 50) forPage:0];
    XCTAssertTrue(CGRectEqualToRect([self frameOfPage:0 inBrowser:browser], CGRectMake(0, 0, kHostWidth, 150)));

    browser.scrollMode = YBIBScrollModePaged;
    [browser reloadData];
    XCTAssertTrue(CGSizeEqualToSize([self frameOfPage:0 inBrowser:browser].size, CGSizeMake(kHostWidth, kHostHeight)));
}

- (void)testContinuousModeConfiguresTheCollectionView {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModeContinuousVertical pageCount:3];
    XCTAssertFalse(browser.collectionView.pagingEnabled);
    XCTAssertTrue(browser.collectionView.alwaysBounceVertical);
    XCTAssertEqual(browser.collectionView.layout.scrollDirection, UICollectionViewScrollDirectionVertical);
}

- (void)testLastFullyVisibleItem {
    NSArray *attributes = @[
        [self attributesForItem:0 frame:CGRectMake(0, 0, 300, 200)],
        [self attributesForItem:1 frame:CGRectMake(0, 200, 300, 200)],
        [self attributesForItem:2 frame:CGRectMake(0, 400, 300, 200)],
        [self attributesForItem:3 frame:CGRectMake(0, 600, 300, 200)],
    ];
    XCTAssertEqual(YBIBLastFullyVisibleItem(attributes, CGRectMake(0, 0, 300, 600)), 2);
    XCTAssertEqual(YBIBLastFullyVisibleItem(attributes, CGRectMake(0, 100, 300, 600)), 2, @"page 3 is cut off at the bottom");
    XCTAssertEqual(YBIBLastFullyVisibleItem(attributes, CGRectMake(0, 200, 300, 600)), 3);
    XCTAssertEqual(YBIBLastFullyVisibleItem(attributes, CGRectMake(0, 200.3, 300, 600)), 3, @"sub-point overlap is tolerated");
    NSArray *tall = @[[self attributesForItem:0 frame:CGRectMake(0, 0, 300, 2000)]];
    XCTAssertEqual(YBIBLastFullyVisibleItem(tall, CGRectMake(0, 500, 300, 600)), NSNotFound, @"no page fits on screen");
}

- (void)testContentOffsetAdjustment {
    // Item above the viewport grows: the offset follows.
    XCTAssertEqual(YBIBContentOffsetAdjustment(CGRectMake(0, 0, 300, 600), 900, 1800), 300);
    // Item that is (partly) visible or below: no adjustment.
    XCTAssertEqual(YBIBContentOffsetAdjustment(CGRectMake(0, 1200, 300, 600), 900, 1500), 0);
    XCTAssertEqual(YBIBContentOffsetAdjustment(CGRectMake(0, 2400, 300, 600), 900, 1800), 0);
    // Unknown frame.
    XCTAssertEqual(YBIBContentOffsetAdjustment(CGRectNull, 900, 1800), 0);
}

- (void)testContinuousItemHeight {
    XCTAssertEqual(YBIBContinuousItemHeight(300, 0, 600, 3), 600, @"placeholder while the ratio is unknown");
    XCTAssertEqual(YBIBContinuousItemHeight(300, 3, 600, 3), 900);
    XCTAssertEqualWithAccuracy(YBIBContinuousItemHeight(300, 1.0 / 3.0, 600, 3), 100, 0.0001);
    XCTAssertEqualWithAccuracy(YBIBContinuousItemHeight(100, 0.12345, 600, 2), 12.5, 0.0001, @"rounded to pixels");
}

- (void)testContinuousPagesUsePlaceholderThenResolvedHeight {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModeContinuousVertical pageCount:5];
    XCTAssertTrue(CGRectEqualToRect([self frameOfPage:1 inBrowser:browser], CGRectMake(0, kHostHeight, kHostWidth, kHostHeight)));

    [browser contentSizeResolved:CGSizeMake(100, 300) forPage:0];
    XCTAssertTrue(CGRectEqualToRect([self frameOfPage:0 inBrowser:browser], CGRectMake(0, 0, kHostWidth, 900)));
    XCTAssertTrue(CGRectEqualToRect([self frameOfPage:1 inBrowser:browser], CGRectMake(0, 900, kHostWidth, kHostHeight)));
    XCTAssertEqual(browser.collectionView.contentSize.height, 900 + 4 * kHostHeight);
}

- (void)testResolvingAPageAboveKeepsVisibleContentInPlace {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModeContinuousVertical pageCount:5];
    browser.currentPage = 3;
    XCTAssertEqual(browser.collectionView.contentOffset.y, 3 * kHostHeight);

    [browser contentSizeResolved:CGSizeMake(100, 300) forPage:0];
    [browser.collectionView layoutIfNeeded];
    XCTAssertEqual(browser.collectionView.contentOffset.y, 3 * kHostHeight + 300);
    XCTAssertEqual([self frameOfPage:3 inBrowser:browser].origin.y, browser.collectionView.contentOffset.y);
    XCTAssertEqual(browser.currentPage, 3);
}

- (void)testPagesAboveResolvingBackToBackKeepVisibleContentInPlace {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModeContinuousVertical pageCount:6];
    browser.currentPage = 4;
    // No layout pass between the two, so the layout's own frames are stale for the second one.
    [browser contentSizeResolved:CGSizeMake(100, 300) forPage:0];
    [browser contentSizeResolved:CGSizeMake(300, 150) forPage:1];
    [browser.collectionView layoutIfNeeded];
    CGFloat expected = 4 * kHostHeight + (900 - kHostHeight) + (150 - kHostHeight);
    XCTAssertEqual(browser.collectionView.contentOffset.y, expected);
    XCTAssertEqual([self frameOfPage:4 inBrowser:browser].origin.y, expected);
    XCTAssertEqual(browser.currentPage, 4, @"keeping content in place is not a page change");
}

- (void)testScrollToPageIsClampedToTheContentEnd {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModeContinuousVertical pageCount:5];
    for (NSInteger i = 0; i < 5; ++i) [browser contentSizeResolved:CGSizeMake(300, 150) forPage:i];
    browser.currentPage = 4;
    // Content is 750 high in a 600 high view, so the offset stops at 150.
    XCTAssertEqual(browser.collectionView.contentOffset.y, 150);
    XCTAssertEqual(browser.currentPage, 4, @"an explicit page is reported as set");
}

- (void)testContinuousScrollingReportsTheLastFullyVisiblePage {
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModeContinuousVertical pageCount:8];
    for (NSInteger i = 0; i < 8; ++i) [browser contentSizeResolved:CGSizeMake(300, 150) forPage:i];
    [browser.collectionView layoutIfNeeded];

    // Pages are 150 high in a 600 high view.
    browser.collectionView.contentOffset = CGPointMake(0, 10);
    XCTAssertEqual(browser.currentPage, 3, @"pages 1-3 fit, page 4 is cut off at the bottom");
    browser.collectionView.contentOffset = CGPointMake(0, 160);
    XCTAssertEqual(browser.currentPage, 4, @"page 1 is cut off at the top, pages 2-4 fit");
    browser.collectionView.contentOffset = CGPointMake(0, 0);
    XCTAssertEqual(browser.currentPage, 3);

    // A page taller than the screen: nothing fits, so the page is not updated (as on Android).
    [browser contentSizeResolved:CGSizeMake(100, 1000) forPage:5];
    [browser.collectionView layoutIfNeeded];
    CGFloat page5Y = [self frameOfPage:5 inBrowser:browser].origin.y;
    browser.collectionView.contentOffset = CGPointMake(0, page5Y + 100);
    XCTAssertEqual(browser.currentPage, 3);
}

- (void)testImageDataReportsItsSizeInContinuousMode {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(20, 60)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        [UIColor.redColor setFill];
        [context fillRect:CGRectMake(0, 0, 20, 60)];
    }];
    YBIBImageData *data = [YBIBImageData new];
    data.image = ^UIImage * _Nullable{ return image; };
    YBImageBrowser *browser = [self showBrowserWithMode:YBIBScrollModeContinuousVertical datas:@[data, [YBIBImageData new]]];

    NSPredicate *resized = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [self frameOfPage:0 inBrowser:browser].size.height == kHostWidth * 3;
    }];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:resized object:nil]] timeout:5];
}

#pragma mark - decoding

- (void)testDecodesWebPWithoutYYImageWebPSupport {
    // 4x6 lossless WebP. The demo builds YYImage without libwebp, so this goes through the ImageIO fallback.
    const unsigned char bytes[] = {
        0x52, 0x49, 0x46, 0x46, 0x22, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
        0x56, 0x50, 0x38, 0x4c, 0x16, 0x00, 0x00, 0x00, 0x2f, 0x03, 0x40, 0x01,
        0x00, 0x07, 0x50, 0x8f, 0x22, 0x17, 0xa5, 0xff, 0x01, 0x80, 0x20, 0xfc,
        0x6f, 0x9b, 0x88, 0xe8, 0x7f, 0x08
    };
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    YBImage *image = [YBImage imageWithData:data scale:2];
    XCTAssertNotNil(image);
    XCTAssertTrue(CGSizeEqualToSize(image.size, CGSizeMake(2, 3)));
    XCTAssertEqual(CGImageGetWidth(image.CGImage), 4);
}

@end

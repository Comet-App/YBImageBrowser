//
//  YBIBLogicTests.m
//  YBImageBrowserDemoTests
//
//  Unit tests for the pure / deterministic parts of YBImageBrowser.
//

#import <XCTest/XCTest.h>
#import "YBImageBrowser.h"
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

@end

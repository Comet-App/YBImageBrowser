//
//  YBIBCollectionViewLayout.h
//  YBImageBrowserDemo
//
//  Created by 杨少 on 2018/4/17.
//  Copyright © 2018年 波儿菜. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// How the browser scrolls through its pages.
typedef NS_ENUM(NSInteger, YBIBScrollMode) {
    /// One page per screen, swiped horizontally (default).
    YBIBScrollModePaged = 0,
    /// Pages stacked vertically at full width, each as tall as its image, scrolled freely (e.g. webtoons).
    YBIBScrollModeContinuousVertical,
};

/// Index of the last item whose frame lies completely inside 'visibleRect', or 'NSNotFound'.
FOUNDATION_EXTERN NSInteger YBIBLastFullyVisibleItem(NSArray<UICollectionViewLayoutAttributes *> *attributes, CGRect visibleRect);

/// How far the content offset must move when an item changes height, so that what is on screen stays put.
/// Non-zero only when the item lies completely above 'visibleMinY'.
FOUNDATION_EXTERN CGFloat YBIBContentOffsetAdjustment(CGRect oldItemFrame, CGFloat newItemHeight, CGFloat visibleMinY);

/// Height of an item in continuous mode: 'width * heightRatio' rounded to pixels, or 'placeholderHeight' when the ratio is unknown.
FOUNDATION_EXTERN CGFloat YBIBContinuousItemHeight(CGFloat width, CGFloat heightRatio, CGFloat placeholderHeight, CGFloat screenScale);

@interface YBIBCollectionViewLayout : UICollectionViewFlowLayout

@property (nonatomic, assign) CGFloat distanceBetweenPages;

/// Default is 'YBIBScrollModePaged'. In continuous mode item sizes come from the flow layout delegate.
@property (nonatomic, assign) YBIBScrollMode scrollMode;

@end

NS_ASSUME_NONNULL_END

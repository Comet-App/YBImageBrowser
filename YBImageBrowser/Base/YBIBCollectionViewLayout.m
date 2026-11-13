//
//  YBIBCollectionViewLayout.m
//  YBImageBrowserDemo
//
//  Created by 杨少 on 2018/4/17.
//  Copyright © 2018年 波儿菜. All rights reserved.
//

#import "YBIBCollectionViewLayout.h"

/// Tolerance for frames that end on a fractional point.
static const CGFloat kYBIBVisibleTolerance = 0.5;

NSInteger YBIBLastFullyVisibleItem(NSArray<UICollectionViewLayoutAttributes *> *attributes, CGRect visibleRect) {
    CGRect bounds = CGRectInset(visibleRect, -kYBIBVisibleTolerance, -kYBIBVisibleTolerance);
    NSInteger result = NSNotFound;
    for (UICollectionViewLayoutAttributes *attribute in attributes) {
        if (attribute.representedElementCategory != UICollectionElementCategoryCell) continue;
        if (CGRectIsEmpty(attribute.frame) || !CGRectContainsRect(bounds, attribute.frame)) continue;
        NSInteger item = attribute.indexPath.item;
        if (result == NSNotFound || item > result) result = item;
    }
    return result;
}

CGFloat YBIBContentOffsetAdjustment(CGRect oldItemFrame, CGFloat newItemHeight, CGFloat visibleMinY) {
    if (CGRectIsNull(oldItemFrame) || CGRectIsEmpty(oldItemFrame) || newItemHeight <= 0) return 0;
    if (CGRectGetMaxY(oldItemFrame) > visibleMinY + kYBIBVisibleTolerance) return 0;
    return newItemHeight - oldItemFrame.size.height;
}

CGFloat YBIBContinuousItemHeight(CGFloat width, CGFloat heightRatio, CGFloat placeholderHeight, CGFloat screenScale) {
    if (width <= 0 || heightRatio <= 0 || !isfinite(heightRatio)) return MAX(placeholderHeight, 0);
    if (screenScale <= 0) screenScale = 1;
    return MAX(round(width * heightRatio * screenScale) / screenScale, 1);
}

@implementation YBIBCollectionViewLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        self.minimumLineSpacing = 0;
        self.minimumInteritemSpacing = 0;
        self.sectionInset = UIEdgeInsetsZero;
        self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _distanceBetweenPages = 20;
        _scrollMode = YBIBScrollModePaged;
    }
    return self;
}

- (void)setScrollMode:(YBIBScrollMode)scrollMode {
    _scrollMode = scrollMode;
    self.scrollDirection = scrollMode == YBIBScrollModeContinuousVertical ? UICollectionViewScrollDirectionVertical : UICollectionViewScrollDirectionHorizontal;
    [self invalidateLayout];
}

- (void)prepareLayout {
    [super prepareLayout];
    if (self.scrollMode == YBIBScrollModePaged) {
        self.itemSize = self.collectionView.bounds.size;
    }
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect {
    if (self.scrollMode == YBIBScrollModeContinuousVertical) {
        return [super layoutAttributesForElementsInRect:rect];
    }
    NSArray<UICollectionViewLayoutAttributes *> *layoutAttsArray = [[NSArray alloc] initWithArray:[super layoutAttributesForElementsInRect:rect] copyItems:YES];
    CGFloat halfWidth = self.collectionView.bounds.size.width / 2.0;
    CGFloat centerX = self.collectionView.contentOffset.x + halfWidth;
    [layoutAttsArray enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.center = CGPointMake(obj.center.x + (obj.center.x - centerX) / halfWidth * self.distanceBetweenPages / 2, obj.center.y);
    }];
    return layoutAttsArray;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    if (self.scrollMode == YBIBScrollModeContinuousVertical) {
        // Scrolling changes only the origin; recompute only when the size changes.
        return !CGSizeEqualToSize(newBounds.size, self.collectionView.bounds.size);
    }
    return YES;
}

@end

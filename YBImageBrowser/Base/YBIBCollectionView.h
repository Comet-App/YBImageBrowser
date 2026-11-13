//
//  YBIBCollectionView.h
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/6/6.
//  Copyright © 2019 波儿菜. All rights reserved.
//

#import "YBIBCollectionViewLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface YBIBCollectionView : UICollectionView

@property (nonatomic, strong, readonly) YBIBCollectionViewLayout *layout;

- (NSString *)reuseIdentifierForCellClass:(Class)cellClass;

/// Also configures paging, bouncing and deceleration for the mode. Default is 'YBIBScrollModePaged'.
@property (nonatomic, assign) YBIBScrollMode scrollMode;

- (nullable UICollectionViewCell *)centerCell;

- (void)scrollToPage:(NSInteger)page;

/// Scrolls so the page starts at the leading edge (top in continuous mode), clamped to the content.
- (void)scrollToPage:(NSInteger)page animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

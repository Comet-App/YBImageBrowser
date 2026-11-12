//
//  YBIBSentinel.m
//  YBImageBrowserDemo
//
//  Created by 波儿菜 on 2019/6/18.
//  Copyright © 2019 波儿菜. All rights reserved.
//

#import "YBIBSentinel.h"
#import <stdatomic.h>

@implementation YBIBSentinel {
    _Atomic(int32_t) _value;
}

- (int32_t)value {
    return atomic_load_explicit(&_value, memory_order_relaxed);
}

- (int32_t)increase {
    return atomic_fetch_add_explicit(&_value, 1, memory_order_relaxed) + 1;
}

@end

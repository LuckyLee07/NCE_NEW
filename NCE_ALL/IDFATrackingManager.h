//
//  IDFATrackingManager.h
//  NEC_ALL
//
//  Created by Lizi0715 on 2022/11/13.
//  Copyright © 2022 PalmGame. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IDFATrackingManager : NSObject
// 单例模式
+ (instancetype)sharedInstance;

- (void)requestIDFA;

@end

NS_ASSUME_NONNULL_END

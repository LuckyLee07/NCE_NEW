//
//  IDFATrackingManager.m
//  NCE1
//
//  Created by Lizi0715 on 2022/11/13.
//  Copyright © 2022 PalmGame. All rights reserved.
//

#import "IDFATrackingManager.h"
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

@implementation IDFATrackingManager

#pragma mark -- 单例模式相关方法
+ (instancetype)sharedInstance
{
    static IDFATrackingManager *s_Instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_Instance = [[super allocWithZone:NULL] init];
    });
    
    return s_Instance;
}

- (void)requestIDFA
{
    [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
        // 获取到权限后，依然使用老方法获取idfa
        if (status == ATTrackingManagerAuthorizationStatusAuthorized) {
            NSString *idfa = [[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString];
            NSLog(@"idfa======>>>%@",idfa);
        } else {
            NSLog(@"请在设置-隐私-跟踪中允许App请求跟踪");
        }
    }];
}

@end

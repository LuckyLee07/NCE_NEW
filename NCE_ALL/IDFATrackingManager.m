//
//  IDFATrackingManager.m
//  NEC_ALL
//
//  Created by Lizi0715 on 2022/11/13.
//  Copyright © 2022 PalmGame. All rights reserved.
//

#import "IDFATrackingManager.h"
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

static NSString * const kTrackingAuthRequestedKey = @"NCETrackingAuthRequested";

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
    if (@available(iOS 14.0, *)) {
        ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
        if (status != ATTrackingManagerAuthorizationStatusNotDetermined) {
            return;
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:kTrackingAuthRequestedKey]) {
            return;
        }

        [defaults setBool:YES forKey:kTrackingAuthRequestedKey];
        [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus authStatus) {
            // 获取到权限后，依然使用老方法获取idfa
            if (authStatus == ATTrackingManagerAuthorizationStatusAuthorized) {
                NSString *idfa = [[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString];
                NSLog(@"idfa======>>>%@",idfa);
            } else {
                NSLog(@"请在设置-隐私-跟踪中允许App请求跟踪");
            }
        }];
    }
}

@end

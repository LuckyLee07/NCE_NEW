//
//  AdmobManager.h
//  NCE_ALL
//
//  Created by Lizi on 2026/02/08.
//  Copyright © 2016年 FancyGame. All rights reserved.
//

#import <UIKit/UIKit.h>

// 判断是否为iOS8
#define iOS8 [[[UIDevice currentDevice]systemVersion] floatValue] >= 8.0

#define ODScreenWidth     [[UIScreen mainScreen] bounds].size.width
#define ODScreenHeight    [[UIScreen mainScreen] bounds].size.height

@interface AdmobManager : NSObject
// 单例模式
+ (instancetype)sharedInstance;

// 广告位配置读取
+ (NSString *)interstitialAdUnitID;
+ (NSString *)bannerAdUnitID;

// 初始化广告
- (void)preInit;

// 显示广告
- (void)showAdmobScene;
- (void)showNativeScene;
- (BOOL)adIsCanShow;

- (void)showHudAction;
- (void)dismissAction;

- (void)showLaunchImage;
- (void)deleLaunchImage;

- (void)resetHudRate:(float)hudRate;

@end

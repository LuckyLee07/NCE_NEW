//
//  AdmobManager.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "AdmobManager.h"
#import "MBProgressHUD.h"

@import GoogleMobileAds;

static NSInteger const kAdsTime = 7;
static NSString * const kInterstitialAdUnitIDKey = @"AdmobInterstitialAdUnitID";
static NSString * const kBannerAdUnitIDKey = @"AdmobBannerAdUnitID";

@interface AdmobManager () <GADFullScreenContentDelegate>

@property(nonatomic, strong) GADInterstitialAd *interstitialAd;
@property(nonatomic, strong) UIViewController *rootViewCtrl;
@property(nonatomic, assign) NSInteger showIndex;
@property(nonatomic, strong) MBProgressHUD *hud;
@property(nonatomic, strong) UIImageView *launchView;
@property(nonatomic, assign) float hudRate;
@property(nonatomic, assign) NSInteger showTime;
@property(nonatomic, assign) BOOL isLoadingInterstitial;

@end

@implementation AdmobManager

+ (NSDictionary *)appInfoDictionary
{
    static NSDictionary *info = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        info = [[NSBundle mainBundle] infoDictionary];
        if (![info isKindOfClass:[NSDictionary class]]) {
            info = @{};
        }
    });
    return info;
}

+ (NSString *)interstitialAdUnitID
{
    NSString *adUnitID = [self.appInfoDictionary objectForKey:kInterstitialAdUnitIDKey];
    if ([adUnitID isKindOfClass:[NSString class]] && adUnitID.length > 0) {
        return adUnitID;
    }
    NSLog(@"Missing or invalid Info.plist key: %@", kInterstitialAdUnitIDKey);
    return nil;
}

+ (NSString *)bannerAdUnitID
{
    NSString *adUnitID = [self.appInfoDictionary objectForKey:kBannerAdUnitIDKey];
    if ([adUnitID isKindOfClass:[NSString class]] && adUnitID.length > 0) {
        return adUnitID;
    }
    NSLog(@"Missing or invalid Info.plist key: %@", kBannerAdUnitIDKey);
    return nil;
}

#pragma mark -- 单例模式相关方法
+ (instancetype)sharedInstance
{
    static AdmobManager *s_Instance = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_Instance = [[AdmobManager allocWithZone:NULL] init];
    });
    
    return s_Instance;
}

- (void)preInit
{
    self.showTime = 1;
    self.hudRate = 10.0f;

#if DEBUG
    GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = @[ GADSimulatorID ];
#endif
    [GADMobileAds.sharedInstance startWithCompletionHandler:nil];
    [self setInterstitial];
    
}

- (void)resetHudRate:(float)hudRate
{
    self.hudRate = hudRate;
}

#pragma mark -- 创建Interstitial
//初始化插页广告
- (void)setInterstitial
{
    if (self.isLoadingInterstitial) return;

    NSString *adUnitID = [AdmobManager interstitialAdUnitID];
    if (adUnitID.length == 0) {
        return;
    }

    self.isLoadingInterstitial = YES;
    __weak typeof(self) weakSelf = self;
    [GADInterstitialAd loadWithAdUnitID:adUnitID
                                 request:[GADRequest request]
                       completionHandler:^(GADInterstitialAd * _Nullable interstitialAd, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.isLoadingInterstitial = NO;
        
        if (error) {
            strongSelf.interstitialAd = nil;
            NSLog(@"Failed to load interstitial ad: %@", error.localizedDescription);
            return;
        }
        
        strongSelf.interstitialAd = interstitialAd;
        strongSelf.interstitialAd.fullScreenContentDelegate = strongSelf;
    }];
}

#pragma mark -- GADFullScreenContentDelegate

- (void)ad:(id<GADFullScreenPresentingAd>)ad
didFailToPresentFullScreenContentWithError:(NSError *)error
{
    NSLog(@"Interstitial failed to present: %@", error.localizedDescription);
    self.interstitialAd = nil;
    [self setInterstitial];
}

- (void)adDidDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad
{
    self.interstitialAd = nil;
    [self setInterstitial];
}

//static int adIndex = 0;
#pragma mark -- 广告相关操作
// 控制广告展示节奏
- (void)showNativeScene {
    if (self.showTime > 0 && self.showTime % kAdsTime == 0) {
        [[AdmobManager sharedInstance] showAdmobScene];
    }
    self.showTime++;
}

- (BOOL)adIsCanShow
{
    return self.interstitialAd != nil;
}

// 显示广告界面
- (void)showAdmobScene
{
    if (!self.interstitialAd) {
        [self setInterstitial];
        NSLog(@"Interstitial ad is not ready yet.");
        return;
    }
    
    UIViewController *rootVC = [self appRootViewController];
    if (!rootVC) {
        NSLog(@"No root view controller to present interstitial ad.");
        return;
    }
    
    [self.interstitialAd presentFromRootViewController:rootVC];
}

- (UIWindow *)getKeyWindow
{
    if (@available(iOS 13.0, *))
    {
        for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive)
            {
                for (UIWindow *window in windowScene.windows)
                {
                    if (window.isKeyWindow)
                    {
                        return window;
                    }
                }
            }
        }
    }
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    
    return nil;
}

- (UIViewController*)appRootViewController
{
    UIWindow *rootWindow = [self getKeyWindow];
    UIViewController *rootViewCtrl = rootWindow.rootViewController;
    UIViewController *topViewCtrl = rootViewCtrl;
    while (topViewCtrl.presentedViewController) {
        topViewCtrl = topViewCtrl.presentedViewController;
    }
    
    return topViewCtrl;
}

- (void)doSomeWorkWithProgress {
    // This just increases the progress indicator in a loop.
    UIViewController *rootVC = [self appRootViewController];
    float progress = 0.0f;
    while (progress < 1.0f) {
        progress += 0.01f;
        dispatch_async(dispatch_get_main_queue(), ^{
            // Instead we could have also passed a reference to the HUD
            // to the HUD to myProgressTask as a method parameter.
            [MBProgressHUD HUDForView:rootVC.view].progress = progress;
        });
        usleep(self.hudRate*10000);
    }
}

- (void)showHudAction
{
    // show LaunchImage
    [self showLaunchImage];
    
    UIViewController *rootVC = [self appRootViewController];
    self.hud = [MBProgressHUD showHUDAddedTo:rootVC.view animated:YES];
    self.hud.mode = MBProgressHUDModeDeterminateHorizontalBar;
    //self.hud.label.text = NSLocalizedString(@"Loading...", @"HUD loading title");
    self.hud.label.text = NSLocalizedString(@"Loading.....", @"HUD loading title");
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // Do something useful in the background and update the HUD periodically.
        [self doSomeWorkWithProgress];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self deleLaunchImage];
            [self.hud hideAnimated:YES];
        });
    });
}


- (void)dismissAction
{
    int64_t delayTime = (int64_t)(2.75 * NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayTime), dispatch_get_main_queue(), ^{
        [self deleLaunchImage];
        [self.hud hideAnimated:YES];
    });
}

- (void)showLaunchImage
{
    CGSize viewSize = [[UIScreen mainScreen] bounds].size;
    CGFloat width = MIN(viewSize.width, viewSize.height);
    CGFloat heigt = MAX(viewSize.width, viewSize.height);
    
    NSString *launchImage = @"AdmobImage.png";
    //NSString *launchImage = [self getLaunchImageName];
    UIImage *oldImage = [UIImage imageNamed:launchImage];
    UIImage *newImage = [self OriginImage:oldImage scaleToSize:CGSizeMake(width, heigt)];
    
    UIViewController *rootVC = [self appRootViewController];
    self.launchView = [[UIImageView alloc] initWithImage:newImage];
    self.launchView.frame = rootVC.view.bounds;
    self.launchView.contentMode = UIViewContentModeScaleAspectFill;
    [rootVC.view addSubview:self.launchView];
    
    // 横屏旋转
    if (viewSize.height < viewSize.width) { //横屏
        self.launchView.transform = CGAffineTransformMakeRotation(-1.57f);
        [self.launchView sizeToFit];
        
        CGRect rect = self.launchView.frame;
        self.launchView.frame = CGRectMake(0, 0, rect.size.width, rect.size.height);
    } else { // LaunchView size=320x480
        self.launchView.frame = [UIScreen mainScreen].bounds;
        [self.launchView sizeToFit];
    }
}

- (UIImage*)OriginImage:(UIImage *)image scaleToSize:(CGSize)size
{
    // 创建一个bitmap的context
    // 并把它设置成为当前正在使用的context
    UIGraphicsBeginImageContext(size);
    
    // 绘制改变大小的图片
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    
    // 从当前context中创建一个改变大小后的图片
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // 使当前的context出堆栈
    UIGraphicsEndImageContext();
    
    // 返回新的改变大小后的图片
    return scaledImage;
}

- (void)deleLaunchImage
{
    [self.launchView removeFromSuperview];
}

- (NSString *)getLaunchImageName
{
    NSString *launchImage = nil;
    NSString *viewOrientation = nil;
    CGSize viewSize = [[UIScreen mainScreen] bounds].size;
    if (viewSize.height > viewSize.width) {
        viewOrientation = @"Portrait";
    } else {
        viewOrientation = @"Landscape";
    }
    NSArray *imageDics = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"UILaunchImages"];
    for (NSDictionary *dic in imageDics) {
        CGSize imageSize = CGSizeFromString(dic[@"UILaunchImageSize"]);
        if (CGSizeEqualToSize(imageSize, viewSize) &&
            [viewOrientation isEqualToString:dic[@"UILaunchImageOrientation"]]) {
            launchImage = dic[@"UILaunchImageName"];
        }
    }
    
    return launchImage;
}

@end

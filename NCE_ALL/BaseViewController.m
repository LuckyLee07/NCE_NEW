//
//  BaseViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "BaseViewController.h"
#import "Utility.h"
#import "AdmobManager.h"
#import <AVFoundation/AVFoundation.h>
@import GoogleMobileAds;

@interface BaseViewController () <GADBannerViewDelegate>
{
    CGFloat _headerHeight;
    GADBannerView *_bannerView;
    UIView *_bannerContainerView;
    NSLayoutConstraint *_bannerContainerHeightConstraint;
}

- (void)goBack;
- (void)addBanner;

@end

@implementation BaseViewController

- (CGFloat)defaultBottomReserveHeight
{
    // Keep a visual bottom bar for layout symmetry even when ad is unavailable.
    return 64.0f;
}

- (id)init
{
    self = [super init];
    if (self) {
        _bannerHeight = [self defaultBottomReserveHeight];
        _viewType = ViewType_Normal;

        _colorArray = @[[UIColor colorWithRed:226/255.f green:73/255.f blue:65/255.f alpha:1.f],
                        [UIColor colorWithRed:234/255.f green:155/255.f blue:65/255.f alpha:1.f],
                        [UIColor colorWithRed:236/255.f green:197/255.f blue:64/255.f alpha:1.f],
                        [UIColor colorWithRed:107/255.f green:194/255.f blue:68/255.f alpha:1.f],
                        [UIColor colorWithRed:80/255.f green:175/255.f blue:235/255.f alpha:1.f],
                        [UIColor colorWithRed:198/255.f green:124/255.f blue:216/255.f alpha:1.f],
                        [UIColor colorWithRed:130/255.f green:213/255.f blue:216/255.f alpha:1.f],
                        [UIColor colorWithRed:248/255.f green:137/255.f blue:0.f/255.f alpha:1.f],
                        [UIColor colorWithRed:136/255.f green:125/255.f blue:221/255.f alpha:1.f],
                        [UIColor colorWithRed:255/255.f green:86/255.f blue:117/255.f alpha:1.f],
                        [UIColor colorWithRed:255/255.f green:18/255.f blue:68/255.f alpha:1.f]];
    }

    _headerHeight = 0.0f;
    CGFloat safeAreaHeight = [self getSafeAreaHeight];
    if (safeAreaHeight > 20.0f) {
        _headerHeight = 45.0f + safeAreaHeight;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.title = self.titleString;
    self.view.backgroundColor = [UIColor colorWithRed:98/255.f green:215/255.f blue:150/255.f alpha:1.f];

    // add back button
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftItemsSupplementBackButton = NO;
    UIImage *backImage = [[UIImage imageNamed:@"btn_back"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:backImage
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(goBack)];

    [self performSelector:@selector(addBanner) withObject:nil afterDelay:0.1f];
    
    NSError *sessionError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
    [[AVAudioSession sharedInstance] setActive:YES error:&sessionError];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Public Methods

- (CGFloat)getHeaderPosY
{
    if ([Utility isPad]) {
        return 0.0f;
    }else {
        return _headerHeight;
    }
}

- (CGFloat)getConstHeight
{
    return 64.0f;
}

- (CGFloat)getPlayViewHeight
{
    return  75.0f;;
}

- (CGRect)getTableViewFrame
{
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    CGFloat bannerHeight = _bannerHeight;
    CGFloat headerPosy = [self getHeaderPosY];
    
    if (_viewType == ViewType_Searchs) {
        headerPosy = headerPosy + 40; //单词search
    } else if (_viewType == ViewType_Lessons) {
        height = height - [self getPlayViewHeight];
    }
    
    // 统一分上中下三段处理
    height = height - headerPosy - bannerHeight;
    
    if ([Utility isPad]) {
        height = height - _headerHeight;
    }
    
    return CGRectMake(0, headerPosy, width, height);
}

- (CGFloat)getSafeAreaHeight
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
                        return window.safeAreaInsets.top;
                    }
                }
            }
        }
    }
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [UIApplication sharedApplication].keyWindow.safeAreaInsets.top;
#pragma clang diagnostic pop
    }
    
    return 0.0f;
}

#pragma mark -
#pragma mark Private Methods

- (void)goBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)addBanner
{
    if (!_bannerContainerView) {
        _bannerContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        _bannerContainerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:_bannerContainerView];
        _bannerContainerHeightConstraint = [_bannerContainerView.heightAnchor constraintEqualToConstant:self.bannerHeight];
        [NSLayoutConstraint activateConstraints:@[
            [_bannerContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [_bannerContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [_bannerContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            _bannerContainerHeightConstraint
        ]];
    }

    if (_bannerView) return;
    
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (width <= 0) return;

    NSString *bannerAdUnitID = [AdmobManager bannerAdUnitID];
    if (bannerAdUnitID.length == 0) {
        self.bannerHeight = [self defaultBottomReserveHeight];
        [self refreshLayoutForBannerHeight];
        return;
    }
    
    GADAdSize adaptiveSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width);
    _bannerView = [[GADBannerView alloc] initWithAdSize:adaptiveSize];
    self.bannerHeight = MAX([self defaultBottomReserveHeight], adaptiveSize.size.height);
    _bannerContainerHeightConstraint.constant = self.bannerHeight;
    _bannerView.adUnitID = bannerAdUnitID;
    _bannerView.rootViewController = self;
    _bannerView.delegate = self;
    
    [_bannerContainerView addSubview:_bannerView];
    _bannerView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_bannerView.centerXAnchor constraintEqualToAnchor:_bannerContainerView.centerXAnchor],
        [_bannerView.centerYAnchor constraintEqualToAnchor:_bannerContainerView.centerYAnchor]
    ]];
    
    GADRequest *request = [GADRequest request];
    [_bannerView loadRequest:request];
}

- (void)refreshLayoutForBannerHeight
{
    if (_bannerContainerHeightConstraint) {
        _bannerContainerHeightConstraint.constant = self.bannerHeight;
    }
    CGRect tableFrame = [self getTableViewFrame];
    for (UIView *subview in self.view.subviews) {
        if ([subview isKindOfClass:[UITableView class]] || [subview isKindOfClass:[UICollectionView class]]) {
            subview.frame = tableFrame;
        }
    }
}

- (void)bannerViewDidReceiveAd:(GADBannerView *)bannerView
{
    CGFloat bannerHeight = CGRectGetHeight(bannerView.bounds);
    self.bannerHeight = MAX([self defaultBottomReserveHeight], bannerHeight);
    [self refreshLayoutForBannerHeight];
}

- (void)bannerView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(NSError *)error
{
    self.bannerHeight = [self defaultBottomReserveHeight];
    [self refreshLayoutForBannerHeight];
    NSLog(@"Banner failed to load: %@", error.localizedDescription);
}

@end

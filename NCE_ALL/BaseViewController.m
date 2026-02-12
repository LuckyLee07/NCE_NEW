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
#import <TargetConditionals.h>
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

- (GADRequest *)nonPersonalizedRequest
{
    GADRequest *request = [GADRequest request];
    GADExtras *extras = [[GADExtras alloc] init];
    extras.additionalParameters = @{@"npa" : @"1"};
    [request registerAdNetworkExtras:extras];
    return request;
}

- (id)init
{
    self = [super init];
    if (self) {
        _viewType = ViewType_Normal;
        [self initHeightData];

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

- (void)initHeightData
{
    _headerHeight = [self getHeaderHeight];
    _bannerHeight = [self getDefaultBottomHeight];
}

- (CGFloat)getHeaderPosY
{
    if ([Utility isPad]) {
        return 0.0f;
    }
    return [self getHeaderHeight];
}

- (CGFloat)getHeaderHeight
{
    CGFloat headerHeight = 64.0f; // 20px + 44px
    CGFloat safeAreaHeight = [self getSafeAreaHeight];
    if (safeAreaHeight > 20.0f) {
        headerHeight = 54.0f + safeAreaHeight;
    }
    return headerHeight;
}

- (CGFloat)getDefaultBottomHeight
{
    if ([Utility isPad]) {
        return _headerHeight;
    }
    return 68.0f;
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
    
    CGFloat headerHeight = _headerHeight;
    CGFloat bannerHeight = _bannerHeight;
    
    CGFloat headerPosy = [self getHeaderPosY];
    
    if (_viewType == ViewType_Searchs) {
        headerPosy = headerPosy + 40.0f; //单词search
        height = height - 40.0f;
    } else if (_viewType == ViewType_Lessons) {
        height = height - [self getPlayViewHeight];
    }
    
    // 统一分上中下三段处理
    height = height - headerHeight - bannerHeight;
    
    return CGRectMake(0, headerPosy, width, height);
}

- (CGFloat)getSafeAreaHeight
{
    for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes)
    {
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
#if TARGET_OS_SIMULATOR
    //[self refreshLayoutForBannerHeight];
    //return;
#endif

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
        self.bannerHeight = [self getDefaultBottomHeight];
        [self refreshLayoutForBannerHeight];
        return;
    }
    
    // AdMob recommended: use anchored adaptive banners across iPhone/iPad.
    GADAdSize adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width);

    _bannerView = [[GADBannerView alloc] initWithAdSize:adSize];
    self.bannerHeight = MAX([self getDefaultBottomHeight], adSize.size.height);
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
    
    GADRequest *request = [self nonPersonalizedRequest];
    [_bannerView loadRequest:request];
}

- (void)refreshLayoutForBannerHeight
{
    if (_bannerContainerHeightConstraint) {
        _bannerContainerHeightConstraint.constant = self.bannerHeight;
    }
    CGRect tableFrame = [self getTableViewFrame];
    CGFloat tableHeight = tableFrame.size.height;
    if ([Utility isPad]) {
        tableFrame.size.height = tableHeight + _headerHeight;
    }
    for (UIView *subview in self.view.subviews) {
        if ([subview isKindOfClass:[UITableView class]] || [subview isKindOfClass:[UICollectionView class]]) {
            subview.frame = tableFrame;
        }
    }
}

- (void)bannerViewDidReceiveAd:(GADBannerView *)bannerView
{
    CGFloat bannerHeight = CGRectGetHeight(bannerView.bounds);
    self.bannerHeight = MAX([self getDefaultBottomHeight], bannerHeight);
    [self refreshLayoutForBannerHeight];
}

- (void)bannerView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(NSError *)error
{
    self.bannerHeight = [self getDefaultBottomHeight];
    [self refreshLayoutForBannerHeight];
    NSLog(@"Banner failed to load: %@", error.localizedDescription);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self->_bannerView || !self->_bannerView.superview) {
            return;
        }
        [self->_bannerView loadRequest:[self nonPersonalizedRequest]];
    });
}

@end

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
    NCEAcademyBackdrop *_academyBackdrop;
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
    if ((self = [super init])) {
        _viewType = ViewType_Normal;
        [self initHeightData];
        // Detail pages use the course sections; root tabs return when leaving the detail.
        self.hidesBottomBarWhenPushed=YES;
        _colorArray = @[NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue(), NCEBlue()];
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.navigationItem.largeTitleDisplayMode=UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.title = NCEChineseText(self.titleString);
    self.view.backgroundColor = NCEBackground();
    _academyBackdrop = [NCEAcademyBackdrop new];
    [self.view addSubview:_academyBackdrop];
    NCEConfigureNavigation(self.navigationController.navigationBar);
    self.navigationItem.hidesBackButton = YES;
    UIButton *back = NCEButton(nil, @"chevron.left", NO, self, @selector(goBack));
    back.frame = CGRectMake(0, 0, 44, 44);
    back.accessibilityIdentifier = @"back";
    back.accessibilityLabel = NCELocalizedString(@"返回");
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:back];
    if (@available(iOS 26.0, *)) self.navigationItem.leftBarButtonItem.hidesSharedBackground=YES;
    if(self.navigationController.viewControllers.firstObject==self) self.navigationItem.leftBarButtonItem=nil;
    self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    [self performSelector:@selector(addBanner) withObject:nil afterDelay:0.1];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(academyTextSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if(!self.embeddedInLesson){if(@available(iOS 18.0,*))[self.tabBarController setTabBarHidden:self.navigationController.viewControllers.firstObject!=self animated:animated];}
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
    return self.view.safeAreaInsets.top;
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
    return 64;
}


- (CGFloat)getPlayViewHeight
{
    return 124;
}


- (CGRect)getTableViewFrame
{
    CGRect frame = [self academyContentFrame];
    if (_viewType == ViewType_Searchs) { frame.origin.y += 64; frame.size.height -= 64; }
    if (_viewType == ViewType_Lessons) frame.size.height -= [self getPlayViewHeight];
    frame.size.height = MAX(0,frame.size.height);
    return frame;
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
    // The shared lesson owns the banner; embedded sections do not create duplicates.
    if (self.embeddedInLesson) return;
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
    // Refresh the native page layout using the original banner height.
    [self.view setNeedsLayout];
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

- (CGRect)academyContentFrame
{
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat available = MAX(0,self.view.bounds.size.width-safe.left-safe.right);
    CGFloat width = MIN(760,available);
    CGFloat bottom=MAX(safe.bottom,self.embeddedInLesson ? 0 : self.bannerHeight);
    return CGRectMake(safe.left+(available-width)/2, safe.top, width,
                      MAX(0,self.view.bounds.size.height-safe.top-bottom));
}
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _academyBackdrop.frame = CGRectMake(0,0,self.view.bounds.size.width,250);
    for (UIView *view in self.view.subviews) {
        if ([view isKindOfClass:UITableView.class] && view.translatesAutoresizingMaskIntoConstraints) {
            UITableView *table = (UITableView *)view;
            CGRect frame = [self getTableViewFrame];
            if (!CGRectEqualToRect(table.frame,frame)) table.frame = frame;
            if ([table.tableHeaderView isKindOfClass:NCEAcademyHeader.class]) {
                NCEAcademyHeader *header = (NCEAcademyHeader *)table.tableHeaderView;
                CGFloat height = [header heightForWidth:frame.size.width];
                if (fabs(header.bounds.size.height-height)>0.5 || fabs(header.bounds.size.width-frame.size.width)>0.5) {
                    header.frame=CGRectMake(0,0,frame.size.width,height); table.tableHeaderView=header;
                }
            }
        }
    }
    [self layoutAcademyViews];
}
- (void)layoutAcademyViews {}
- (void)academyTextSizeChanged:(NSNotification *)notification
{
    [self.view setNeedsLayout];
    for (UIView *view in self.view.subviews) if ([view isKindOfClass:UITableView.class]) [(UITableView *)view reloadData];
}
- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end

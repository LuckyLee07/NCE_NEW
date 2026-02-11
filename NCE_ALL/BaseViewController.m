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

@interface BaseViewController ()
{
    CGFloat _scale;
    CGFloat _headerHeight;
    //GADBannerView *_bannerView;
}

- (void)goBack;
- (void)addBanner;

@end

@implementation BaseViewController

- (id)init
{
    self = [super init];
    if (self) {
        _bannerHeight = 84.0f;
        _viewType = ViewType_Normal;
        
        _scale = [UIScreen mainScreen].bounds.size.width / 320;
        //_adSize = [Utility isPad] ? kGADAdSizeLeaderboard : kGADAdSizeBanner;
        if ([Utility isPad]) {
            //_adSize = kGADAdSizeLeaderboard;
        } else {
            if ([Utility isPlus]) {
                //_posy = 64.0f;
            }
            //CGSize nsize = CGSizeMake(kGADAdSizeBanner.size.width, kGADAdSizeBanner.size.height);
            //_adSize = GADAdSizeFromCGSize(CGSizeMake(nsize.width*_scale, nsize.height*_scale));
        }
        //_adSize = GADAdSizeFromCGSize(CGSizeMake(0, 0));
        
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
    //_adSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, 64);
    
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
    UIImage *backImage = [UIImage imageNamed:@"btn_back"];
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(0, 0, backImage.size.width*1.25f, backImage.size.height*1.25f);
    
    [backButton setBackgroundImage:backImage forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    
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
    
    if (_headerHeight <= 0.0f) {
        height = height - _bannerHeight;
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
    /*
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    CGSize winSize = [UIScreen mainScreen].bounds.size;
    CGPoint point = CGPointMake((winSize.width-_adSize.size.width)/2, winSize.height-_adSize.size.height+1.f);
    _bannerView = [[GADBannerView alloc] initWithAdSize:_adSize
                                                 origin:point];
    _bannerView.adUnitID = BannerID;
    _bannerView.rootViewController = window.rootViewController;
    [window addSubview:_bannerView];
    
    GADRequest *request = [GADRequest request];
    request.testDevices = @[@"a09014c39671651f46f72102f4585ff7",
                            @"706d576a2ce61a4dcb5f7365ba592ff0", kGADSimulatorID];
    [_bannerView loadRequest:request];
    */
}

@end

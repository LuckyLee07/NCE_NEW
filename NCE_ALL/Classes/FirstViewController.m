//
//  FirstViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "FirstViewController.h"
#import "MainViewController.h"
#import "UINavigationItem+Spacing.h"
#import "Utility.h"
#import "SettingViewController.h"

@interface FirstViewController ()
{
    CGFloat _scale;
}

- (void)addSettingButton;
- (void)goSetting;
- (void)addBooks;
- (void)goMain:(UIButton *)button;

@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _scale = self.view.frame.size.width/320;
    
    UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:self.view.frame];
    backgroundView.image = [UIImage imageNamed:@"background"];
    [self.view addSubview:backgroundView];
    self.navigationItem.hidesBackButton = YES;
    
    UIImage *image = [UIImage imageNamed:@"bg_navigation"];
    image = [image stretchableImageWithLeftCapWidth:floorf(image.size.width/2) topCapHeight:floorf(image.size.height/2)];
    [self.navigationController.navigationBar setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
    
    // set title
    NSDictionary *dic = [NSDictionary dictionaryWithObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    self.navigationController.navigationBar.titleTextAttributes = dic;
    self.navigationItem.title = @"新概念英语";
    
    [self addBooks];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Private Methods

- (void)addSettingButton
{
    UIImage *settingImage = [UIImage imageNamed:@"btn_setting"];
    UIButton *settingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    settingButton.frame = CGRectMake(0, 0, settingImage.size.width, settingImage.size.height);
    [settingButton setBackgroundImage:settingImage forState:UIControlStateNormal];
    [settingButton addTarget:self action:@selector(goSetting) forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:settingButton];
}

- (void)goSetting
{
    SettingViewController *setttingController = [[SettingViewController alloc] init];
    [self.navigationController pushViewController:setttingController animated:YES];
}

- (void)addBooks
{
    NSInteger deltaHeight = [Utility is35InchScreen] ? 20: 0;
    for (int ii = 0; ii < 1; ii++) {
        UIButton *bookButton = [UIButton buttonWithType:UIButtonTypeCustom];
        
        CGRect frame;
        NSString *imageName;
        if ([Utility isPad]) {
            frame = CGRectMake(12, 0, 372*2, 465*2);
            imageName = [NSString stringWithFormat:@"book%d_iPad.png",ii+1];
        } else {
            CGFloat posHeight = 0;
            if ([Utility isPlus]) posHeight = 95.0f;
            frame = CGRectMake(15*_scale, 30*_scale+deltaHeight+posHeight,
                               145*2*_scale, 219*2*_scale);
            imageName = [NSString stringWithFormat:@"book%d.jpg",ii+1];
        }
        bookButton.frame = frame;
        [bookButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
        [bookButton addTarget:self action:@selector(goMain:) forControlEvents:UIControlEventTouchUpInside];
        bookButton.tag = 100+ii;
        [self.view addSubview:bookButton];
    }
}

- (void)goMain:(UIButton *)button
{
    MainViewController *mainController = [[MainViewController alloc] initWithBookId:(int)button.tag-100];
    [self.navigationController pushViewController:mainController animated:YES];
}



@end


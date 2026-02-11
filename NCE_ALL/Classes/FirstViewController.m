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

- (void)addSettingButton;
- (void)goSetting;
- (void)addBooks;
- (void)layoutBooks;
- (void)goMain:(UIButton *)button;

@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

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

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self layoutBooks];
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
    for (int ii = 0; ii < 4; ii++) {
        UIButton *bookButton = [UIButton buttonWithType:UIButtonTypeCustom];
        NSString *imageName;
        if ([Utility isPad]) {
            imageName = [NSString stringWithFormat:@"book%d_iPad.png",ii+1];
        } else {
            imageName = [NSString stringWithFormat:@"book%d.jpg",ii+1];
        }
        [bookButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
        [bookButton addTarget:self action:@selector(goMain:) forControlEvents:UIControlEventTouchUpInside];
        bookButton.tag = 100+ii;
        [self.view addSubview:bookButton];
    }
}

- (void)layoutBooks
{
    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeInsets = self.view.safeAreaInsets;
    }

    for (int ii = 0; ii < 4; ii++) {
        UIButton *bookButton = (UIButton *)[self.view viewWithTag:100 + ii];
        if (![bookButton isKindOfClass:[UIButton class]]) continue;

        CGRect frame;
        if ([Utility isPad]) {
            frame = CGRectMake((40+372*fmod(ii, 2)), 20+465*floor(ii/2), 315, 445);
        } else {
            CGFloat availableWidth = CGRectGetWidth(self.view.bounds) - safeInsets.left - safeInsets.right;
            CGFloat availableHeight = CGRectGetHeight(self.view.bounds) - safeInsets.top - safeInsets.bottom;

            CGFloat horizontalInset = MAX(12.0f, MIN(24.0f, availableWidth * 0.06f));
            CGFloat horizontalSpacing = MAX(10.0f, MIN(20.0f, availableWidth * 0.05f));
            CGFloat verticalSpacing = MAX(12.0f, MIN(24.0f, availableHeight * 0.03f));
            CGFloat contentWidth = availableWidth - horizontalInset * 2.0f;

            // Keep original cover ratio close to 135:189.
            CGFloat aspectRatio = 135.0f / 189.0f;
            CGFloat maxButtonWidth = floor((contentWidth - horizontalSpacing) / 2.0f);
            CGFloat maxButtonHeight = floor((availableHeight - verticalSpacing) / 2.0f);

            CGFloat buttonWidth = maxButtonWidth;
            CGFloat buttonHeight = floor(buttonWidth / aspectRatio);
            if (buttonHeight > maxButtonHeight) {
                buttonHeight = maxButtonHeight;
                buttonWidth = floor(buttonHeight * aspectRatio);
            }

            CGFloat contentTotalWidth = buttonWidth * 2.0f + horizontalSpacing;
            CGFloat contentTotalHeight = buttonHeight * 2.0f + verticalSpacing;
            CGFloat startX = safeInsets.left + floor((availableWidth - contentTotalWidth) / 2.0f);
            CGFloat startY = safeInsets.top + floor((availableHeight - contentTotalHeight) / 2.0f);

            NSInteger row = ii / 2;
            NSInteger col = ii % 2;
            frame = CGRectMake(startX + (buttonWidth + horizontalSpacing) * col,
                               startY + (buttonHeight + verticalSpacing) * row,
                               buttonWidth,
                               buttonHeight);
        }

        bookButton.frame = frame;
    }
}

- (void)goMain:(UIButton *)button
{
    MainViewController *mainController = [[MainViewController alloc] initWithBookId:(int)button.tag-100];
    [self.navigationController pushViewController:mainController animated:YES];
}



@end

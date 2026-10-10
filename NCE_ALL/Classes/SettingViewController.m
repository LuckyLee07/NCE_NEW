//
//  SettingViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "SettingViewController.h"
#import "CKAlertView.h"
#import "NCELocalization.h"

static NSString* const kSettingViewControllerCellReuseId = @"kSettingViewControllerCellReuseId";

@interface SettingViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

- (void)addTableView;

@end

@implementation SettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = NCELocalizedString(@"设置");
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor colorWithRed:98/255.f
                                                green:215/255.f
                                                 blue:150/255.f
                                                alpha:1.f];
    
    // add back button
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftItemsSupplementBackButton = NO;
    UIImage *backImage = [[UIImage imageNamed:@"btn_back"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage:backImage
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(goBack)];
    backButton.accessibilityIdentifier = @"back";
    backButton.accessibilityLabel = NCELocalizedString(@"返回");
    self.navigationItem.leftBarButtonItem = backButton;
    
    [self addTableView];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSettingViewControllerCellReuseId
                                                            forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessibilityIdentifier = @[@"settings-contact", @"settings-credits", @"settings-language"][indexPath.row];
    
    NSArray *array = [cell.contentView subviews];
    for (UIView *view in array) {
        [view removeFromSuperview];
    }
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.f, 0.f, MAX(0, tableView.bounds.size.width-40.f), 44.f)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14.f];
    titleLabel.textColor = [UIColor darkTextColor];
    if (indexPath.row == 0) titleLabel.text = NCELocalizedString(@"联络邮件:071427li@163.com");
    else if (indexPath.row == 1) titleLabel.text = NCELocalizedString(@"配图来源与许可");
    else {
        NSString *preference = NCELocalization.languagePreference;
        NSDictionary *names = @{@"zh-Hans": @"简体中文", @"zh-Hant": @"繁體中文", @"ja": @"日本語", @"ko": @"한국어"};
        NSString *name = names[preference] ?: NCELocalizedString(@"跟随系统");
        titleLabel.text = [NSString stringWithFormat:NCELocalizedString(@"语言：%@"), name];
    }
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.7;
    [cell.contentView addSubview:titleLabel];
    
    // show when the cell is selected
    UIView *maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 44.f)];
    maskView.backgroundColor = [UIColor clearColor];
    maskView.tag = 1000+indexPath.row;
    [cell.contentView addSubview:maskView];
    
    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.15f];
    if (indexPath.row == 2) {
        UIAlertController *picker = [UIAlertController alertControllerWithTitle:NCELocalizedString(@"语言") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray *preferences = @[@"system", @"zh-Hans", @"zh-Hant", @"ja", @"ko"];
        NSArray *names = @[NCELocalizedString(@"跟随系统"), @"简体中文", @"繁體中文", @"日本語", @"한국어"];
        for (NSUInteger index = 0; index < preferences.count; index++) {
            NSString *preference = preferences[index];
            [picker addAction:[UIAlertAction actionWithTitle:names[index] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [NCELocalization setLanguagePreference:preference];
            }]];
        }
        [picker addAction:[UIAlertAction actionWithTitle:NCELocalizedString(@"取消") style:UIAlertActionStyleCancel handler:nil]];
        picker.popoverPresentationController.sourceView = [tableView cellForRowAtIndexPath:indexPath];
        picker.popoverPresentationController.sourceRect = [tableView cellForRowAtIndexPath:indexPath].bounds;
        [self presentViewController:picker animated:YES completion:nil];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    if (indexPath.row == 1) {
        NSString *path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"data/words/licenses/attribution.txt"];
        NSString *credits = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        UIViewController *controller = [[UIViewController alloc] init];
        controller.title = NCELocalizedString(@"配图来源与许可");
        controller.view.backgroundColor = UIColor.systemBackgroundColor;
        UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
        textView.translatesAutoresizingMaskIntoConstraints = NO;
        textView.editable = NO;
        textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        textView.adjustsFontForContentSizeCategory = YES;
        textView.dataDetectorTypes = UIDataDetectorTypeLink;
        textView.textContainerInset = UIEdgeInsetsMake(16, 16, 16, 16);
        textView.text = NCEChineseText(credits) ?: NCELocalizedString(@"配图许可文件暂不可用。");
        [controller.view addSubview:textView];
        UILayoutGuide *guide = controller.view.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [textView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
            [textView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
            [textView.topAnchor constraintEqualToAnchor:guide.topAnchor],
            [textView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor]
        ]];
        [self.navigationController pushViewController:controller animated:YES];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tableView respondsToSelector:@selector(setSeparatorInset:)])
    {
        [tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    
    else if ([tableView respondsToSelector:@selector(setLayoutMargins:)])
    {
        [tableView setLayoutMargins:UIEdgeInsetsZero];
    }
    
    else if ([cell respondsToSelector:@selector(setLayoutMargins:)])
    {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

#pragma mark -
#pragma mark CKAlertViewDelegate

- (void)alertView:(UIView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
}

#pragma mark -
#pragma mark Private Methods

- (void)goBack
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)addTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.tableView.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9f];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.scrollEnabled = NO;
    
    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:kSettingViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor]
    ]];
}

@end

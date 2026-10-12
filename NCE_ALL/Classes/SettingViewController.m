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
#import "NCEAcademyTheme.h"

static NSString* const kSettingViewControllerCellReuseId = @"kSettingViewControllerCellReuseId";

@interface SettingViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic,strong) NCEAcademyBackdrop *backdrop;

- (void)addTableView;

@end

@implementation SettingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];self.edgesForExtendedLayout=UIRectEdgeNone;self.title=NCELocalizedString(@"设置");self.view.backgroundColor=NCEBackground();
    self.backdrop=[NCEAcademyBackdrop new];[self.view addSubview:self.backdrop];
    NCEConfigureNavigation(self.navigationController.navigationBar);
    UIButton *back=NCEButton(nil,@"chevron.left",NO,self,@selector(goBack));back.frame=CGRectMake(0,0,44,44);back.accessibilityIdentifier=@"back";back.accessibilityLabel=NCELocalizedString(@"返回");
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:back];
    if (@available(iOS 26.0, *)) self.navigationItem.leftBarButtonItem.hidesSharedBackground=YES;
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
    NCEAcademyCell *cell=[tableView dequeueReusableCellWithIdentifier:kSettingViewControllerCellReuseId forIndexPath:indexPath];
    cell.accessibilityIdentifier=@[@"settings-contact",@"settings-credits",@"settings-language"][indexPath.row];
    NSString *title,*detail,*symbol;
    if(indexPath.row==0){title=NCELocalizedString(@"联系与反馈");detail=@"071427li@163.com";symbol=@"envelope";}
    else if(indexPath.row==1){title=NCELocalizedString(@"配图来源与许可");detail=NCELocalizedString(@"查看插画与资源说明");symbol=@"photo.on.rectangle";}
    else{title=NCELocalizedString(@"语言");NSDictionary *names=@{@"zh-Hans":@"简体中文",@"zh-Hant":@"繁體中文",@"ja":@"日本語",@"ko":@"한국어"};detail=names[NCELocalization.languagePreference] ?: NCELocalizedString(@"跟随系统");symbol=@"globe";}
    [cell configureTitle:title subtitle:detail badge:nil symbol:symbol];return cell;
}


#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.15f];
    if(indexPath.row==0){
        NSURL *url=[NSURL URLWithString:@"mailto:071427li@163.com"];
        if([UIApplication.sharedApplication canOpenURL:url])[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        else {UIPasteboard.generalPasteboard.string=@"071427li@163.com";UIAlertController *alert=[UIAlertController alertControllerWithTitle:NCELocalizedString(@"邮箱已复制") message:@"071427li@163.com" preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:NCELocalizedString(@"确定") style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];}
        return;
    }
    if (indexPath.row == 2) {
        UIAlertController *picker = [UIAlertController alertControllerWithTitle:NCELocalizedString(@"语言") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray *preferences = @[@"system", @"zh-Hans", @"zh-Hant", @"ja", @"ko"];
        NSArray *names = @[NCELocalizedString(@"跟随系统"), @"简体中文", @"繁體中文", @"日本語", @"한국어"];
        __weak typeof(self) weakSelf=self;
        for (NSUInteger index = 0; index < preferences.count; index++) {
            NSString *preference = preferences[index];
            [picker addAction:[UIAlertAction actionWithTitle:names[index] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [weakSelf dismissViewControllerAnimated:YES completion:^{
                    [NCELocalization setLanguagePreference:preference];
                }];
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
        controller.view.backgroundColor = NCEBackground();
        UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
        textView.translatesAutoresizingMaskIntoConstraints = NO;
        textView.editable = NO;
        textView.font = NCEFont(16,UIFontWeightRegular);
        textView.textColor=NCEInk();textView.backgroundColor=NCESurface();
        textView.adjustsFontForContentSizeCategory = YES;
        textView.dataDetectorTypes = UIDataDetectorTypeLink;
        textView.textContainerInset = UIEdgeInsetsMake(16, 16, 16, 16);
        textView.text = [NSString stringWithFormat:@"%@\n\n%@",NCELocalizedString(@"学院风界面的书本角色与配套插画由 AI 辅助创作。"),NCEChineseText(credits) ?: NCELocalizedString(@"配图许可文件暂不可用。")];
        [controller.view addSubview:textView];
        UILayoutGuide *guide = controller.view.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [textView.centerXAnchor constraintEqualToAnchor:guide.centerXAnchor],
            [textView.widthAnchor constraintLessThanOrEqualToConstant:760],
            [textView.leadingAnchor constraintGreaterThanOrEqualToAnchor:guide.leadingAnchor],
            [textView.trailingAnchor constraintLessThanOrEqualToAnchor:guide.trailingAnchor],
            [textView.topAnchor constraintEqualToAnchor:guide.topAnchor],
            [textView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor]
        ]];
        NSLayoutConstraint *width=[textView.widthAnchor constraintEqualToAnchor:guide.widthAnchor];width.priority=UILayoutPriorityDefaultHigh;width.active=YES;
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
    self.tableView=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];self.tableView.dataSource=self;self.tableView.delegate=self;NCEPrepareTable(self.tableView);
    [self.tableView registerClass:NCEAcademyCell.class forCellReuseIdentifier:kSettingViewControllerCellReuseId];[self.view addSubview:self.tableView];
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    self.tableView.tableHeaderView=[[NCEAcademyHeader alloc] initWithEyebrow:@"NEW CONCEPT ENGLISH" title:NCELocalizedString(@"学习，由你做主。") subtitle:[NSString stringWithFormat:@"%@ %@",NCELocalizedString(@"版本"),version] image:@"academy-hero"];
}


- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];UIEdgeInsets safe=self.view.safeAreaInsets;CGFloat width=MIN(760,self.view.bounds.size.width-safe.left-safe.right);
    self.backdrop.frame=CGRectMake(0,0,self.view.bounds.size.width,260);
    self.tableView.frame=CGRectMake((self.view.bounds.size.width-width)/2,safe.top,width,self.view.bounds.size.height-safe.top-safe.bottom);
    NCEAcademyHeader *header=(NCEAcademyHeader *)self.tableView.tableHeaderView;CGFloat h=[header heightForWidth:width];
    if(fabs(header.frame.size.width-width)>0.5 || fabs(header.frame.size.height-h)>0.5){header.frame=CGRectMake(0,0,width,h);self.tableView.tableHeaderView=header;}
}

@end

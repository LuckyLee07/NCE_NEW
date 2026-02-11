//
//  OnlineDictionaryViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "OnlineDictionaryViewController.h"
#import "MBProgressHUD.h"
#import <WebKit/WebKit.h>

@interface OnlineDictionaryViewController () <WKUIDelegate, WKNavigationDelegate>
{
    NSURL *_url;
    MBProgressHUD *_hud;
    WKWebView* _webView;
}

@end

@implementation OnlineDictionaryViewController

- (id)initWithDictionaryId:(int)dictionaryId withWord:(NSString *)word
{
    self = [super init];
    if (self) {
        self.titleString = @"在线词典";
        
        NSArray *dictionarys = [NSArray arrayWithObjects:@"https://dict.youdao.com/search?q=",  @"https://www.iciba.com/",@"https://dict.baidu.com/s?wd=", @"https://dict.cn/", nil];
        
        _url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [dictionarys objectAtIndex:dictionaryId], word]];
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    /*
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.view.frame.size.width, self.view.frame.size.height-64.f)];
    webView.delegate = self;
    [webView loadRequest:[NSURLRequest requestWithURL:_url]];
    [self.view addSubview:webView];
    */
    [self createWebview]; // UIWebView升级为WKWebView
    
    _hud = [MBProgressHUD showHUDAddedTo:_webView animated:YES];
    
    // Configure for text only and offset down
    //    _hud.mode = MBProgressHUDModeText;
    _hud.label.text = @"loading...";
    _hud.removeFromSuperViewOnHide = YES;
}

- (void)dealloc
{
    [_webView stopLoading];
    [_webView setNavigationDelegate:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)createWebview
{
    // 配置：
    // 创建网页配置对象
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    // 跨域
    [config setValue:@YES forKey:@"_allowUniversalAccessFromFileURLs"];

    // 创建设置对象
    WKPreferences *preference = [[WKPreferences alloc]init];
    config.preferences = preference;
    
    // 是使用h5的视频播放器在线播放, 还是使用原生播放器全屏播放
    config.allowsInlineMediaPlayback = YES;
    
    //设置是否允许画中画技术 在特定设备上有效
    config.allowsPictureInPictureMediaPlayback = YES;
    
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    
    // 初始化
    CGRect viewframe = CGRectMake(0.f, 0.f, self.view.frame.size.width, self.view.frame.size.height);
    _webView = [[WKWebView alloc] initWithFrame:viewframe configuration:config];
    
    _webView.UIDelegate = self; // UI代理
    _webView.navigationDelegate = self;
    // 是否允许手势左滑返回上一级, 类似导航控制的左滑返回
    //_webView.allowsBackForwardNavigationGestures = YES;
    
    
    [_webView loadRequest:[NSURLRequest requestWithURL:_url]];
    [self.view addSubview:_webView];
}

#pragma mark -
#pragma mark WKUIDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [_hud hideAnimated:YES];
    self.title = webView.title;
}

#pragma mark WKNavigationDelegate
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if ([error code] == NSURLErrorCancelled) {
        return;;
    }
}

- (void)webViewDidClose:(WKWebView *)webView {
       NSLog(@"%s", __FUNCTION__);
  }

-  (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
    [_webView reload];
}

@end

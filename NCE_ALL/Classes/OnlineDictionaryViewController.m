//
//  OnlineDictionaryViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "OnlineDictionaryViewController.h"
#import <WebKit/WebKit.h>

@interface OnlineDictionaryViewController () <WKUIDelegate, WKNavigationDelegate>
{
    NSURL *_url;
    UIStackView *_loadingView;
    UIActivityIndicatorView *_loadingSpinner;
    NSUInteger _loadingGeneration;
    WKWebView* _webView;
    UIView *_errorView;
    UIButton *_retryButton;
}

@end

@implementation OnlineDictionaryViewController

- (id)initWithDictionaryId:(int)dictionaryId withWord:(NSString *)word
{
    self = [super init];
    if (self) {
        self.titleString = NCELocalizedString(@"在线词典");
        
        NSArray *dictionarys = [NSArray arrayWithObjects:@"https://dict.youdao.com/search?q=",  @"https://www.iciba.com/",@"https://dict.baidu.com/s?wd=", @"https://dict.cn/", nil];
        
        NSMutableCharacterSet *allowed=NSCharacterSet.URLQueryAllowedCharacterSet.mutableCopy;[allowed removeCharactersInString:@"&?/#"];
        NSString *escaped=[word stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        _url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [dictionarys objectAtIndex:dictionaryId], escaped ?: @""]];
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createWebview];
    _loadingSpinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _loadingSpinner.color=NCEBlue();
    UILabel *label=NCELabel(NCELocalizedString(@"正在打开词典…"),14,UIFontWeightRegular,NCEMuted());
    label.textAlignment=NSTextAlignmentCenter;
    _loadingView=[[UIStackView alloc] initWithArrangedSubviews:@[_loadingSpinner,label]];
    _loadingView.axis=UILayoutConstraintAxisVertical;_loadingView.alignment=UIStackViewAlignmentCenter;_loadingView.spacing=12;
    _loadingView.hidden=YES;_loadingView.userInteractionEnabled=NO;
    _loadingView.accessibilityIdentifier=@"dictionary-loading";[self.view addSubview:_loadingView];
    [self retryDictionary];
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
    
    
    _webView.backgroundColor=NCEBackground();
    [self.view addSubview:_webView];
    _errorView=NCEEmptyState(NCELocalizedString(@"暂时无法连接词典"),NCELocalizedString(@"检查网络连接后，再试一次。"));_errorView.backgroundColor=NCEBackground();_errorView.hidden=YES;[self.view addSubview:_errorView];
    _retryButton=NCEButton(NCELocalizedString(@"重新加载"),@"arrow.clockwise",YES,self,@selector(retryDictionary));_retryButton.hidden=YES;[self.view addSubview:_retryButton];
}

#pragma mark -
#pragma mark WKUIDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self endLoading];
    _errorView.hidden=YES;_retryButton.hidden=YES;
}

#pragma mark WKNavigationDelegate
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if(error.code==NSURLErrorCancelled)return;[self endLoading];_errorView.hidden=NO;_retryButton.hidden=NO;
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    _errorView.hidden=YES;_retryButton.hidden=YES;
    NSUInteger generation=++_loadingGeneration;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        typeof(self) self=weakSelf;
        if(self && self->_loadingGeneration==generation && self->_webView.loading){self->_loadingView.hidden=NO;[self->_loadingSpinner startAnimating];}
    });
}
- (void)endLoading { ++_loadingGeneration;_loadingView.hidden=YES;[_loadingSpinner stopAnimating]; }


- (void)webViewDidClose:(WKWebView *)webView {
       NSLog(@"%s", __FUNCTION__);
  }

-  (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
    [_webView reload];
}

- (void)layoutAcademyViews
{
    CGRect frame=[self academyContentFrame];_webView.frame=frame;_errorView.frame=frame;
    _retryButton.frame=CGRectMake(frame.origin.x+32,CGRectGetMaxY(frame)-88,frame.size.width-64,52);
    CGSize loadingSize=[_loadingView systemLayoutSizeFittingSize:CGSizeMake(MAX(0,frame.size.width-48),UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    _loadingView.frame=CGRectMake(frame.origin.x+24,CGRectGetMidY(frame)-loadingSize.height/2,MAX(0,frame.size.width-48),loadingSize.height);
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self webView:webView didFailNavigation:navigation withError:error];
}
- (void)retryDictionary
{
    _errorView.hidden=YES;_retryButton.hidden=YES;
    if(_url)[_webView loadRequest:[NSURLRequest requestWithURL:_url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20]];
}

@end

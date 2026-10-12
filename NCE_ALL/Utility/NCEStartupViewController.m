#import "NCEStartupViewController.h"
#import "NCEAcademyTheme.h"
#import "NCELocalization.h"
#import "AdmobManager.h"
#import <QuartzCore/QuartzCore.h>

@implementation NCEStartupViewController {
    NSError *(^_preparation)(void);
    void (^_completion)(BOOL);
    UIImageView *_mascot;
    UIView *_halo;
    UIStackView *_details;
    UILabel *_status;
    UIActivityIndicatorView *_spinner;
    UIButton *_retry;
    UIImageView *_wave;
    BOOL _started, _working, _displayedLoading;
    NSUInteger _attempt;
}
- (instancetype)initWithPreparation:(NSError *(^)(void))preparation completion:(void (^)(BOOL))completion {
    if ((self=[super init])) { _preparation=[preparation copy]; _completion=[completion copy]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=NCEBackground(); self.view.accessibilityIdentifier=@"startup-screen";
    _halo=[UIView new]; _halo.backgroundColor=NCESky(); _halo.alpha=0; _halo.layer.cornerRadius=104;
    _mascot=[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"loading-companion"]];
    _mascot.contentMode=UIViewContentModeScaleAspectFit; _mascot.isAccessibilityElement=NO;
    _wave=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"waveform"]];
    _wave.tintColor=NCEBlue(); _wave.contentMode=UIViewContentModeScaleAspectFit; _wave.alpha=0;
    UILabel *title=NCELabel(NCELocalizedString(@"新概念全四册"),24,UIFontWeightSemibold,NCEInk());
    title.font=[[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle2] scaledFontForFont:[UIFont systemFontOfSize:24 weight:UIFontWeightSemibold] maximumPointSize:32];
    title.textAlignment=NSTextAlignmentCenter; title.accessibilityTraits=UIAccessibilityTraitHeader;
    _status=NCELabel(NCELocalizedString(@"正在准备学习内容…"),14,UIFontWeightRegular,NCEMuted());
    _status.font=[[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:14] maximumPointSize:20];
    _status.textAlignment=NSTextAlignmentCenter; _status.accessibilityIdentifier=@"startup-status";
    _spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _spinner.color=NCEBlue(); _spinner.hidesWhenStopped=YES; _spinner.isAccessibilityElement=NO;
    _retry=NCEButton(NCELocalizedString(@"重试"),@"arrow.clockwise",YES,self,@selector(beginPreparation));
    _retry.accessibilityIdentifier=@"startup-retry"; _retry.hidden=YES;
    _details=[[UIStackView alloc] initWithArrangedSubviews:@[title,_status,_spinner,_retry]];
    _details.axis=UILayoutConstraintAxisVertical; _details.alignment=UIStackViewAlignmentCenter;
    _details.spacing=16; _details.alpha=0; _details.accessibilityElementsHidden=YES;
    for(UIView *view in @[_halo,_mascot,_wave,_details]) {view.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:view];}
    // Matches LaunchScreen.storyboard exactly, avoiding a jump at handoff.
    [NSLayoutConstraint activateConstraints:@[
        [_mascot.widthAnchor constraintEqualToConstant:184],[_mascot.heightAnchor constraintEqualToConstant:184],
        [_mascot.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_mascot.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-64],
        [_halo.widthAnchor constraintEqualToConstant:208],[_halo.heightAnchor constraintEqualToConstant:208],
        [_halo.centerXAnchor constraintEqualToAnchor:_mascot.centerXAnchor],[_halo.centerYAnchor constraintEqualToAnchor:_mascot.centerYAnchor],
        [_wave.widthAnchor constraintEqualToConstant:26],[_wave.heightAnchor constraintEqualToConstant:22],
        [_wave.leadingAnchor constraintEqualToAnchor:_mascot.trailingAnchor constant:4],
        [_wave.centerYAnchor constraintEqualToAnchor:_mascot.centerYAnchor constant:-25],
        [_details.topAnchor constraintEqualToAnchor:_mascot.bottomAnchor constant:22],
        [_details.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_details.widthAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-48],
        [title.widthAnchor constraintLessThanOrEqualToAnchor:_details.widthAnchor],
        [_status.widthAnchor constraintLessThanOrEqualToAnchor:_details.widthAnchor],
        [_retry.heightAnchor constraintGreaterThanOrEqualToConstant:48],[_retry.widthAnchor constraintGreaterThanOrEqualToConstant:140]
    ]];
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(updateMotion) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(stopMotion) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(updateMotion) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; if(!_started){_started=YES;[self beginPreparation];} }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated];[self stopMotion]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (BOOL)reduceMotion {
#if DEBUG
    if([AdmobManager isOfflineResourceQA] && [NSProcessInfo.processInfo.arguments containsObject:@"-NCEStartupReduceMotion"])return YES;
#endif
    return UIAccessibilityIsReduceMotionEnabled();
}
- (void)stopMotion { [_mascot.layer removeAllAnimations];[_wave.layer removeAllAnimations]; }
- (void)updateMotion {
    [self stopMotion];
    if(!_working || !_displayedLoading || !self.view.window || UIApplication.sharedApplication.applicationState==UIApplicationStateBackground)return;
    _wave.alpha=0.65;
    if([self reduceMotion])return;
    CABasicAnimation *floatAnimation=[CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    floatAnimation.fromValue=@0;floatAnimation.toValue=@(-5);floatAnimation.duration=0.4;
    floatAnimation.autoreverses=YES;floatAnimation.repeatCount=HUGE_VALF;
    floatAnimation.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_mascot.layer addAnimation:floatAnimation forKey:@"listening-float"];
    CABasicAnimation *pulse=[CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue=@0.3;pulse.toValue=@0.8;pulse.duration=0.4;pulse.autoreverses=YES;pulse.repeatCount=HUGE_VALF;
    pulse.timingFunction=floatAnimation.timingFunction;[_wave.layer addAnimation:pulse forKey:@"listening-pulse"];
}
- (void)showDetails {
    _displayedLoading=YES; _details.accessibilityElementsHidden=NO;
    [UIView animateWithDuration:[self reduceMotion] ? 0 : 0.15 animations:^{self->_details.alpha=1;self->_halo.alpha=0.45;}];
    [self updateMotion];
}
- (void)beginPreparation {
    if(_working)return;
    _working=YES;NSUInteger attempt=++_attempt;
    CFTimeInterval startedAt=CACurrentMediaTime();
    _retry.hidden=YES;_status.text=NCELocalizedString(@"正在准备学习内容…");[_spinner startAnimating];
    [self showDetails];
    __weak typeof(self) weakSelf=self;
    BOOL preview=NO,failOnce=NO;
#if DEBUG
    if([AdmobManager isOfflineResourceQA]) {
        preview=[NSProcessInfo.processInfo.arguments containsObject:@"-NCEStartupPreview"];
        failOnce=attempt==1 && [NSProcessInfo.processInfo.arguments containsObject:@"-NCEStartupFailOnce"];
    }
#endif
    // Preparation starts immediately in production; only Debug QA simulates slow work.
    NSTimeInterval delay=preview ? 12 : (failOnce ? 0.8 : 0);
    NSError *(^preparation)(void)=_preparation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSError *error=failOnce ? [NSError errorWithDomain:@"NCEStartupQA" code:1 userInfo:nil] : preparation();
        dispatch_async(dispatch_get_main_queue(),^{
            typeof(self) self=weakSelf;if(!self || self->_attempt!=attempt)return;
            [self->_spinner stopAnimating];
            if(error) {
                self->_working=NO;[self stopMotion];self->_wave.alpha=0;
                NSLog(@"Startup preparation failed: %@",error);
                self->_status.text=NCELocalizedString(@"暂时无法准备学习内容，请重试。");
                self->_retry.hidden=NO;[self showDetails];
                UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification,self->_status);
            } else {
                // One short brand introduction per cold launch, concurrent with real work.
                // Retries and foreground restoration do not add another minimum wait.
                self->_status.text=NCELocalizedString(@"一起开始学习吧");
                NSTimeInterval remaining=attempt==1 ? MAX(0,0.8-(CACurrentMediaTime()-startedAt)) : 0;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(remaining*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    typeof(self) self=weakSelf;if(!self || self->_attempt!=attempt)return;
                    self->_working=NO;[self stopMotion];self->_wave.alpha=0;
                    self->_completion(self->_displayedLoading);
                });
            }
        });
    });
}
@end

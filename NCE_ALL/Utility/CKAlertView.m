#import "CKAlertView.h"
#import "NCEAcademyTheme.h"

@interface CKAlertView ()
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIStackView *stack;
@property(nonatomic,strong) UIButton *cancelAction;
@property(nonatomic,assign) BOOL dismissible;
@end

@implementation CKAlertView
- (UIWindow *)getKeyWindow
{
    for(UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes){
        if(![scene isKindOfClass:UIWindowScene.class])continue;
        for(UIWindow *window in scene.windows)if(window.isKeyWindow)return window;
    }
    return nil;
}
- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitle, ...
{
    if((self=[super initWithFrame:[self getKeyWindow].bounds])){
        self.delegate=delegate;self.backgroundColor=[UIColor colorWithRed:0.05 green:0.12 blue:0.22 alpha:0.4];self.accessibilityViewIsModal=YES;
        self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _dismissible=cancelButtonTitle==nil;
        if(_dismissible){UIControl *background=[[UIControl alloc] initWithFrame:self.bounds];background.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[background addTarget:self action:@selector(removeSelf) forControlEvents:UIControlEventTouchUpInside];[self addSubview:background];}
        _panel=[UIView new];NCECard(_panel,28);_panel.translatesAutoresizingMaskIntoConstraints=NO;[self addSubview:_panel];
        UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[_panel addSubview:scroll];
        _stack=[UIStackView new];_stack.axis=UILayoutConstraintAxisVertical;_stack.spacing=12;_stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:_stack];
        if(message.length){UIImageView *image=[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"academy-books"]];image.contentMode=UIViewContentModeScaleAspectFit;[_stack addArrangedSubview:image];[image.heightAnchor constraintEqualToConstant:94].active=YES;}
        UILabel *heading=NCELabel(title,22,UIFontWeightBold,NCEInk());heading.textAlignment=NSTextAlignmentCenter;[_stack addArrangedSubview:heading];
        if(message.length){UILabel *detail=NCELabel(message,17,UIFontWeightMedium,NCEMuted());detail.textAlignment=NSTextAlignmentCenter;[_stack addArrangedSubview:detail];[_stack setCustomSpacing:22 afterView:detail];}
        va_list ap;va_start(ap,otherButtonTitle);NSInteger index=0;
        while(otherButtonTitle){UIButton *button=NCEButton(otherButtonTitle,nil,NO,self,@selector(buttonClick:));button.tag=100+index;button.accessibilityIdentifier=[NSString stringWithFormat:@"alert-choice-%ld",(long)index];[_stack addArrangedSubview:button];[button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active=YES;otherButtonTitle=va_arg(ap,NSString *);index++;}
        va_end(ap);
        if(cancelButtonTitle){_cancelAction=NCEButton(cancelButtonTitle,nil,YES,self,@selector(buttonClick:));_cancelAction.tag=100+index;_cancelAction.accessibilityIdentifier=@"alert-cancel";[_stack addArrangedSubview:_cancelAction];[_cancelAction.heightAnchor constraintGreaterThanOrEqualToConstant:50].active=YES;}
        NSLayoutConstraint *width=[_panel.widthAnchor constraintEqualToConstant:356];width.priority=UILayoutPriorityDefaultHigh;
        NSLayoutConstraint *height=[_panel.heightAnchor constraintEqualToAnchor:_stack.heightAnchor constant:48];height.priority=UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[
            [_panel.topAnchor constraintGreaterThanOrEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:16],
            [_panel.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-16],height,
            [scroll.topAnchor constraintEqualToAnchor:_panel.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:_panel.bottomAnchor],
            [scroll.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor],
            [_panel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],[_panel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],width,
            [_panel.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-36],
            [_stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],[_stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],[_stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:22],[_stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-22],[_stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-44]
        ]];
    }return self;
}
- (void)show
{
    [[self getKeyWindow] addSubview:self];UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,_stack.arrangedSubviews.firstObject);
}
- (void)buttonClick:(UIButton *)button
{
    id<CKAlertViewDelegate> delegate=self.delegate;[self removeSelf];
    if([delegate respondsToSelector:@selector(alertView:customClickedButtonAtIndex:)])[delegate alertView:self customClickedButtonAtIndex:button.tag-100];
}
- (BOOL)accessibilityPerformEscape
{
    if(_cancelAction){[self buttonClick:_cancelAction];return YES;}if(_dismissible){[self removeSelf];return YES;}return NO;
}
- (void)removeSelf { [self removeFromSuperview]; }
@end

//
//  CKAlertView.m
//  NCE2
//
//  Created by Lizi on 15/12/21.
//  Copyright (c) 2015年 PalmGame. All rights reserved.
//

#import "CKAlertView.h"
#import "Utility.h"

@interface CKAlertView ()

- (void)buttonClick:(UIButton *)button;
- (void)removeSelf;

@end

@implementation CKAlertView

- (UIWindow *)getKeyWindow
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
                        return window;
                    }
                }
            }
        }
    }
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
    }
    
    return nil;
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitle, ...
{
    CGRect frame = [self getKeyWindow].bounds;
    self = [super initWithFrame:frame];
    if (self) {
        self.delegate = delegate;
        self.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.3];
        
        int width = [Utility isPad] ? 320 : 270;
        int titleHeight = 54.f;
        if (message) titleHeight += 26;
        
        int height = titleHeight;
        
        UIView *background = [[UIView alloc] initWithFrame:CGRectMake(self.frame.size.width/2-width/2, frame.size.height/2-height/2, width, height)];
        background.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9];
        background.layer.cornerRadius = 8;
        background.layer.masksToBounds = YES;
        [self addSubview:background];
        
        if (!cancelButtonTitle) {
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(removeSelf)];
            tapGesture.numberOfTapsRequired    = 1;
            tapGesture.numberOfTouchesRequired = 1;
            [self addGestureRecognizer:tapGesture];
        }
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, background.frame.size.width, 44.f)];
        titleLabel.text     = title;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor     = [UIColor grayColor];
        titleLabel.font          = [UIFont systemFontOfSize:14.f];
        [background addSubview:titleLabel];
        
        if (message) {
            UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 36.f, background.frame.size.width, 44.f)];
            messageLabel.text     = message;
            messageLabel.backgroundColor = [UIColor clearColor];
            messageLabel.textAlignment = NSTextAlignmentCenter;
            messageLabel.textColor = [UIColor darkGrayColor];
            messageLabel.font          = [UIFont boldSystemFontOfSize:18.f];
            [background addSubview:messageLabel];
        }
        
        va_list ap;
        va_start(ap, otherButtonTitle);
        int ii = 0;
        while (otherButtonTitle) {
            height += 44.f;
            
            UIButton *otherButton = [UIButton buttonWithType:UIButtonTypeCustom];
            otherButton.frame = CGRectMake(0.f, titleHeight+ii*44.f, background.frame.size.width, 44.f);
            otherButton.backgroundColor = [UIColor clearColor];
            otherButton.tag = 100+ii;
            [otherButton setTitle:otherButtonTitle forState:UIControlStateNormal];
            [otherButton setTitleColor:[UIColor colorWithRed:0.f green:122/255.f blue:1.f alpha:1.f] forState:UIControlStateNormal];
            otherButton.titleLabel.font = [UIFont systemFontOfSize:18.f];
            [otherButton addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
            [background addSubview:otherButton];
            
            CGRect lineFrame = otherButton.frame;
            lineFrame.size.height = 1.f;
            UIView *line = [[UIView alloc] initWithFrame:lineFrame];
            //            line.backgroundColor = [UIColor colorWithRed:200/255.f
            //                                                   green:199/255.f
            //                                                    blue:204/255.f
            //                                                   alpha:1.f];
            line.backgroundColor = [UIColor colorWithRed:61/255.f
                                                   green:205/255.f
                                                    blue:122/255.f
                                                   alpha:1.f];
            [background addSubview:line];
            
            otherButtonTitle = va_arg(ap, NSString*);
            ii++;
        }
        va_end(ap);
        
        if (cancelButtonTitle) {
            height += 44.f;
            
            UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
            cancelButton.frame = CGRectMake(0.f, titleHeight+ii*44.f, background.frame.size.width, 44);
            cancelButton.backgroundColor = [UIColor clearColor];
            cancelButton.tag = 100+ii;
            [cancelButton setTitle:cancelButtonTitle forState:UIControlStateNormal];
            [cancelButton setTitleColor:[UIColor colorWithRed:0.f green:122/255.f blue:1.f alpha:1.f] forState:UIControlStateNormal];
            cancelButton.titleLabel.font = [UIFont systemFontOfSize:18.f];
            [cancelButton addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
            [background addSubview:cancelButton];
            
            CGRect lineFrame = cancelButton.frame;
            lineFrame.size.height = 1.f;
            UIView *line = [[UIView alloc] initWithFrame:lineFrame];
            //            line.backgroundColor = [UIColor colorWithRed:200/255.f
            //                                                   green:199/255.f
            //                                                    blue:204/255.f
            //                                                   alpha:1.f];
            line.backgroundColor = [UIColor colorWithRed:61/255.f
                                                   green:205/255.f
                                                    blue:122/255.f
                                                   alpha:1.f];
            [background addSubview:line];
        }
        
        background.frame = CGRectMake(self.frame.size.width/2-width/2, frame.size.height/2-height/2, width, height);
    }
    return self;
}

- (void)show
{
    UIWindow *window = [self getKeyWindow];
    [window addSubview:self];
}

- (void)buttonClick:(UIButton *)button
{
    if ([self.delegate respondsToSelector:@selector(alertView:customClickedButtonAtIndex:)]) {
        [self.delegate alertView:self customClickedButtonAtIndex:button.tag-100];
    }
    
    [self removeSelf];
}

- (void)removeSelf
{
    [self removeFromSuperview];
}

@end

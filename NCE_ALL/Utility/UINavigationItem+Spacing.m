//
//  UINavigationItem+Spacing.m
//  Cultures
//
//  Created by Lizi on 14-9-2.
//  Copyright (c) 2015年 PalmGame. All rights reserved.
//

#import "UINavigationItem+Spacing.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation UINavigationItem (Spacing)

+ (void)load
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7) return;
    
    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(setLeftBarButtonItem:)),
        class_getInstanceMethod(self, @selector(mySetLeftBarButtonItem:))
    );
    
    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(setRightBarButtonItem:)),
        class_getInstanceMethod(self, @selector(mySetRightBarButtonItem:))
    );
}

- (UIBarButtonItem *)spacer
{
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    space.width = -10.0f;
    return space;
}

- (void)mySetLeftBarButtonItem:(UIBarButtonItem *)barButton
{
    NSArray *barButtons = nil;
    barButtons = [NSArray arrayWithObjects:[self spacer], barButton, nil];
    [self setLeftBarButtonItems:barButtons];
}

- (void)mySetRightBarButtonItem:(UIBarButtonItem *)barButton
{
    NSArray *barButtons = nil;
    barButtons = [NSArray arrayWithObjects:[self spacer], barButton, nil];
    [self setRightBarButtonItems:barButtons];
}

@end

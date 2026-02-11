//
//  Utility.m
//  NCE2
//
//  Created by Lizi on 15/11/28.
//  Copyright (c) 2015年 PalmGame. All rights reserved.
//

#import "Utility.h"

@implementation Utility

+ (BOOL)isPad
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) return NO;
    return YES;
}

+ (BOOL)isPlus
{
    CGSize screensize = [[UIScreen mainScreen] bounds].size;
    if (screensize.height >= 736) return YES;
    return NO;
}

+ (BOOL)is35InchScreen
{
    CGSize screensize = [[UIScreen mainScreen] bounds].size;
    if (screensize.height >= 568) return NO;
    return YES;
}

@end

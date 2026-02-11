//
//  BaseViewController.h
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, ViewType) {
    ViewType_Normal = 0,
    ViewType_Searchs = 1,
    ViewType_Lessons = 2,
};

@interface BaseViewController : UIViewController

@property (nonatomic, assign) ViewType viewType;
@property (nonatomic, strong) NSArray *colorArray;
@property (nonatomic, strong) NSString *titleString;

@property (nonatomic, assign) CGFloat bannerHeight;

- (CGFloat)getHeaderPosY;

- (CGFloat)getConstHeight;
- (CGFloat)getPlayViewHeight;
- (CGFloat)getSafeAreaHeight;

- (CGRect)getTableViewFrame;

@end

//
//  BaseViewController.h
//  NCE1
//
//  Created by lizi on 17/8/1.
//  Copyright © 2017年 PalmGame. All rights reserved.
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

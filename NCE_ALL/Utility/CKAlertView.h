//
//  CKAlertView.h
//  NCE2
//
//  Created by Lizi on 15/12/21.
//  Copyright (c) 2015年 PalmGame. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CKAlertViewDelegate <NSObject>
@optional

- (void)alertView:(UIView *)alertView customClickedButtonAtIndex:(NSInteger)buttonIndex;

@end

@interface CKAlertView : UIView

@property (nonatomic, assign) id<CKAlertViewDelegate> delegate;

- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitle,...;

- (void)show;

@end

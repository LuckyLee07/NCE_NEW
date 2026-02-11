//
//  WordBookDetailViewController.h
//  NCE1
//
//  Created by lizi on 17/8/1.
//  Copyright © 2017年 PalmGame. All rights reserved.
//

#import "BaseViewController.h"

@interface WordBookDetailViewController : BaseViewController

- (id)initWithBookId:(int)bookId withTitle:(NSString *)title withCondition:(NSDictionary *)where;

@end

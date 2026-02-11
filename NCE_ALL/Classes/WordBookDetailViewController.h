//
//  WordBookDetailViewController.h
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "BaseViewController.h"

@interface WordBookDetailViewController : BaseViewController

- (id)initWithBookId:(int)bookId withTitle:(NSString *)title withCondition:(NSDictionary *)where;

@end

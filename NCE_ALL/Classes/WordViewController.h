//
//  WordViewController.h
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "BaseViewController.h"

@interface WordViewController : BaseViewController

- (id)initWithBookId:(int)bookId withLesson:(NSDictionary *)lesson withFunction:(int)function;

- (id)initWithData:(NSArray *)data withIndex:(int)index;

@end

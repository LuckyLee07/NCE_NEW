#import "BaseViewController.h"
// Modes: meaning recall, English recall, dictation, English → meaning, meaning → English.
@interface NCEPracticeViewController : BaseViewController
- (instancetype)initWithWords:(NSArray<NSDictionary *> *)words key:(NSString *)key mode:(NSInteger)mode;
@end

#import "BaseViewController.h"
@interface NCECourseViewController : BaseViewController
@property(nonatomic) BOOL keyboardVisible;
- (instancetype)initWithBook:(NSInteger)book lesson:(NSDictionary *)lesson section:(NSInteger)section;
- (void)showSection:(NSInteger)section;
@end

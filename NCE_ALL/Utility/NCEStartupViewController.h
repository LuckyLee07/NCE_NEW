#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// Runs preparation off the main thread, and delivers readiness on the main thread.
@interface NCEStartupViewController : UIViewController
- (instancetype)initWithPreparation:(NSError * _Nullable (^)(void))preparation
                         completion:(void (^)(BOOL displayedLoading))completion;
@end
NS_ASSUME_NONNULL_END

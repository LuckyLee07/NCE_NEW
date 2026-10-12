#import "NCEAcademyTheme.h"

UIImage *NCEVolumeImage(NSInteger book);
NSString *NCEVolumeTitle(NSInteger book);
NSString *NCEVolumeSubtitle(NSInteger book);
void NCEShowBookPicker(UIViewController *host, NSInteger selected, void (^selection)(NSInteger));
void NCESetButtonTitle(UIButton *button, NSString *title);

@interface NCEVolumeControl : UIControl
@property(nonatomic) NSInteger book;
@end

@interface NCEStudyRow : UITableViewCell
- (void)configureTitle:(NSString *)title subtitle:(NSString *)subtitle number:(NSString *)number current:(BOOL)current;
@end

@interface NCEStudyEmptyView : UIView
- (instancetype)initWithSymbol:(NSString *)symbol title:(NSString *)title message:(NSString *)message action:(NSString *)action target:(id)target selector:(SEL)selector;
@end

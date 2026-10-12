#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Shared native design vocabulary for the Academy interface.
UIColor *NCEBackground(void);
UIColor *NCESurface(void);
UIColor *NCEInk(void);
UIColor *NCEMuted(void);
UIColor *NCEBlue(void);
UIColor *NCESky(void);
UIColor *NCELine(void);
UIColor *NCESuccess(void);
UIColor *NCEError(void);
UIFont *NCEFont(CGFloat size, UIFontWeight weight);
UILabel *NCELabel(NSString * _Nullable text, CGFloat size, UIFontWeight weight, UIColor *color);
UIButton *NCEButton(NSString * _Nullable title, NSString * _Nullable symbol, BOOL primary, id _Nullable target, SEL _Nullable action);
void NCEStyleButton(UIButton *button, BOOL primary);
void NCECard(UIView *view, CGFloat radius);
void NCEConfigureNavigation(UINavigationBar *bar);
void NCEPrepareTable(UITableView *table);
CGFloat NCETextHeight(NSString *text, UIFont *font, CGFloat width);
UIView *NCEEmptyState(NSString *title, NSString *message);

@interface NCEAcademyBackdrop : UIView
@end

@interface NCEAcademyHeader : UIView
@property (nonatomic, strong, readonly) UILabel *eyebrowLabel;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
- (instancetype)initWithEyebrow:(NSString *)eyebrow title:(NSString *)title subtitle:(NSString *)subtitle image:(nullable NSString *)image;
- (CGFloat)heightForWidth:(CGFloat)width;
@end

@interface NCEAcademyCell : UITableViewCell
@property (nonatomic, strong, readonly) UIView *cardView;
@property (nonatomic, strong, readonly) UILabel *headingLabel;
@property (nonatomic, strong, readonly) UILabel *detailLabel;
@property (nonatomic, strong, readonly) UILabel *badgeLabel;
@property (nonatomic, strong, readonly) UIImageView *symbolView;
@property (nonatomic, strong, readonly) UIImageView *chevronView;
- (void)configureTitle:(NSString *)title subtitle:(nullable NSString *)subtitle badge:(nullable NSString *)badge symbol:(nullable NSString *)symbol;
- (void)setEmphasized:(BOOL)emphasized;
@end

NS_ASSUME_NONNULL_END

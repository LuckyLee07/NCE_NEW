#import "NCEAcademyTheme.h"
#import <QuartzCore/QuartzCore.h>
#import "NCELocalization.h"

static UIColor *NCEHex(NSUInteger h) { return [UIColor colorWithRed:((h>>16)&255)/255.0 green:((h>>8)&255)/255.0 blue:(h&255)/255.0 alpha:1]; }
static UIColor *NCEPair(NSUInteger light, NSUInteger dark) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) { return NCEHex(traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light); }];
}
UIColor *NCEBackground(void) { return NCEPair(0xFFFFFF, 0x14191F); }
UIColor *NCESurface(void) { return NCEPair(0xF8FAFC, 0x20272E); }
UIColor *NCEInk(void) { return NCEPair(0x15191E, 0xECF4FF); }
UIColor *NCEMuted(void) { return NCEPair(0x64768C, 0xA8BBD1); }
UIColor *NCEBlue(void) { return NCEPair(0x087EA4, 0x70D5FF); }
UIColor *NCESky(void) { return NCEPair(0xE7F7FF, 0x243E55); }
UIColor *NCELine(void) { return NCEPair(0xE3EDF8, 0x354A62); }
UIColor *NCESuccess(void) { return NCEPair(0x147653, 0x74DBAE); }
UIColor *NCEError(void) { return NCEPair(0xB43A48, 0xFFA1AB); }
UIFont *NCEFont(CGFloat size, UIFontWeight weight) {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:base];
}
UILabel *NCELabel(NSString *text, CGFloat size, UIFontWeight weight, UIColor *color) {
    UILabel *label = [UILabel new]; label.text = text; label.font = NCEFont(size, weight);
    label.textColor = color; label.numberOfLines = 0; label.adjustsFontForContentSizeCategory = YES;
    return label;
}
void NCECard(UIView *view, CGFloat radius) {
    view.backgroundColor = NCESurface(); view.layer.cornerRadius = MIN(radius, 8);
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.shadowOpacity = 0;
}
void NCEStyleButton(UIButton *button, BOOL primary) {
    UIButtonConfiguration *config = button.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
    config.baseForegroundColor = primary ? UIColor.whiteColor : NCEBlue();
    BOOL iconOnly = config.title.length == 0;
    config.background.backgroundColor = primary ? NCEHex(0x087EA4) : UIColor.clearColor;
    config.background.cornerRadius = primary && iconOnly ? 28 : 8;
    config.cornerStyle = UIButtonConfigurationCornerStyleFixed;
    config.contentInsets = iconOnly ? NSDirectionalEdgeInsetsMake(6, 6, 6, 6) : NSDirectionalEdgeInsetsMake(10, 12, 10, 12);
    config.imagePadding = 8;
    config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold];
    config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = attributes.mutableCopy; result[NSFontAttributeName] = NCEFont(15, UIFontWeightSemibold); return result;
    };
    button.configuration = config;
    button.titleLabel.numberOfLines = 0;
    button.configurationUpdateHandler = ^(UIButton *control) {
        UIButtonConfiguration *state = control.configuration;
        BOOL enabled = control.enabled;
        UIColor *foreground = enabled ? state.baseForegroundColor : NCEMuted();
        state.background.backgroundColorTransformer = ^UIColor *(UIColor *color) { return enabled ? color : NCELine(); };
        state.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
            NSMutableDictionary *result = attributes.mutableCopy;
            result[NSFontAttributeName] = NCEFont(15, UIFontWeightSemibold);
            result[NSForegroundColorAttributeName] = foreground;
            return result;
        };
        state.imageColorTransformer = ^UIColor *(UIColor *color) { return foreground; };
        control.configuration = state;
        control.alpha = control.highlighted ? 0.70 : 1.0;
    };
}
UIButton *NCEButton(NSString *title, NSString *symbol, BOOL primary, id target, SEL action) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.title = title; if (symbol) config.image = [UIImage systemImageNamed:symbol];
    button.configuration = config; NCEStyleButton(button, primary);
    if (target && action) [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
void NCEConfigureNavigation(UINavigationBar *bar) {
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground]; appearance.backgroundColor = NCEBackground();
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName:NCEInk(), NSFontAttributeName:NCEFont(17, UIFontWeightBold)};
    bar.standardAppearance = appearance; bar.scrollEdgeAppearance = appearance;
    bar.compactAppearance = appearance; bar.compactScrollEdgeAppearance = appearance; bar.tintColor = NCEInk();
}
void NCEPrepareTable(UITableView *table) {
    table.backgroundColor = UIColor.clearColor; table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.contentInset = UIEdgeInsetsMake(8, 0, 16, 0); table.rowHeight = UITableViewAutomaticDimension;
    table.estimatedRowHeight = 92; table.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}
CGFloat NCETextHeight(NSString *text, UIFont *font, CGFloat width) {
    return ceil([text boundingRectWithSize:CGSizeMake(MAX(1,width), CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:font} context:nil].size.height);
}
UIView *NCEEmptyState(NSString *title, NSString *message) {
    UIView *view = [UIView new];
    UIImageView *art = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"academy-books"]];
    art.contentMode = UIViewContentModeScaleAspectFit;
    UILabel *heading = NCELabel(title, 23, UIFontWeightBold, NCEInk()); heading.textAlignment = NSTextAlignmentCenter;
    UILabel *detail = NCELabel(message, 15, UIFontWeightRegular, NCEMuted()); detail.textAlignment = NSTextAlignmentCenter;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[art, heading, detail]];
    stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:stack]; [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:32], [stack.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-32],
        [stack.centerYAnchor constraintEqualToAnchor:view.centerYAnchor], [art.heightAnchor constraintEqualToConstant:116]
    ]]; return view;
}

@implementation NCEAcademyBackdrop
- (instancetype)initWithFrame:(CGRect)frame { if ((self = [super initWithFrame:frame])) { self.userInteractionEnabled = NO; [self refresh]; } return self; }
- (void)refresh {
    self.backgroundColor = NCEBackground();
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection { [super traitCollectionDidChange:previousTraitCollection]; [self refresh]; }
@end

@implementation NCEAcademyHeader { UIImageView *_art; }
- (instancetype)initWithEyebrow:(NSString *)eyebrow title:(NSString *)title subtitle:(NSString *)subtitle image:(NSString *)image {
    if ((self = [super initWithFrame:CGRectZero])) {
        _eyebrowLabel = NCELabel(eyebrow, 11, UIFontWeightBold, NCEMuted());
        _titleLabel = NCELabel(title, 24, UIFontWeightBold, NCEInk());
        _subtitleLabel = NCELabel(subtitle, 13, UIFontWeightRegular, NCEMuted());
        for (UIView *v in @[_eyebrowLabel,_titleLabel,_subtitleLabel]) [self addSubview:v];
        if (image) { _art = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"books.vertical"]]; _art.tintColor=NCEBlue(); _art.contentMode = UIViewContentModeScaleAspectFit; [self addSubview:_art]; }
    } return self;
}
- (CGFloat)heightForWidth:(CGFloat)width {
    CGFloat textWidth = MAX(100,width-40-(_art ? 76 : 0));
    CGFloat height=24;
    for (UILabel *label in @[_eyebrowLabel,_titleLabel,_subtitleLabel]) {
        if (label.text.length) height+=NCETextHeight(label.text,label.font,textWidth)+6;
    }
    return MAX(_art ? 92 : 64, height);
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat w = self.bounds.size.width; CGFloat tw = MAX(100,w-40-(_art ? 76 : 0)); CGFloat y=12;
    for (UILabel *label in @[_eyebrowLabel,_titleLabel,_subtitleLabel]) {
        label.hidden=label.text.length==0;
        CGFloat h=NCETextHeight(label.text,label.font,tw);
        label.frame=CGRectMake(20,y,tw,h+1); if(!label.hidden)y+=h+6;
    }
    _art.frame=CGRectMake(w-80,MAX(12,(self.bounds.size.height-52)/2),52,52);
}
@end

@implementation NCEAcademyCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor=UIColor.clearColor; self.selectionStyle=UITableViewCellSelectionStyleNone;
        _cardView=[UIView new]; NCECard(_cardView,18); _cardView.translatesAutoresizingMaskIntoConstraints=NO; [self.contentView addSubview:_cardView];
        _badgeLabel=NCELabel(nil,14,UIFontWeightBold,NCEBlue()); _badgeLabel.backgroundColor=NCESky(); _badgeLabel.textAlignment=NSTextAlignmentCenter;
        _badgeLabel.layer.cornerRadius=23; _badgeLabel.clipsToBounds=YES; _badgeLabel.adjustsFontSizeToFitWidth=YES; _badgeLabel.minimumScaleFactor=0.65;
        _symbolView=[UIImageView new]; _symbolView.contentMode=UIViewContentModeScaleAspectFit; _symbolView.tintColor=NCEBlue();
        _headingLabel=NCELabel(nil,17,UIFontWeightBold,NCEInk()); _detailLabel=NCELabel(nil,13,UIFontWeightRegular,NCEMuted());
        _chevronView=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]]; _chevronView.tintColor=NCEMuted(); _chevronView.contentMode=UIViewContentModeScaleAspectFit;
        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_headingLabel,_detailLabel]]; text.axis=UILayoutConstraintAxisVertical; text.spacing=5;
        for (UIView *view in @[_badgeLabel,_symbolView,text,_chevronView]) {view.translatesAutoresizingMaskIntoConstraints=NO; [_cardView addSubview:view];}
        [NSLayoutConstraint activateConstraints:@[
            [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],[_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],[_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_cardView.heightAnchor constraintGreaterThanOrEqualToConstant:76],
            [_badgeLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:14],[_badgeLabel.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],[_badgeLabel.widthAnchor constraintEqualToConstant:46],[_badgeLabel.heightAnchor constraintEqualToConstant:46],
            [_symbolView.centerXAnchor constraintEqualToAnchor:_badgeLabel.centerXAnchor],[_symbolView.centerYAnchor constraintEqualToAnchor:_badgeLabel.centerYAnchor],[_symbolView.widthAnchor constraintEqualToConstant:23],[_symbolView.heightAnchor constraintEqualToConstant:23],
            [text.leadingAnchor constraintEqualToAnchor:_badgeLabel.trailingAnchor constant:14],[text.trailingAnchor constraintEqualToAnchor:_chevronView.leadingAnchor constant:-12],
            [text.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16],[text.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-16],
            [_chevronView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16],[_chevronView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],[_chevronView.widthAnchor constraintEqualToConstant:10],[_chevronView.heightAnchor constraintEqualToConstant:16]
        ]];
    } return self;
}
- (void)configureTitle:(NSString *)title subtitle:(NSString *)subtitle badge:(NSString *)badge symbol:(NSString *)symbol {
    _headingLabel.text=title; _detailLabel.text=subtitle; _detailLabel.hidden=subtitle.length==0;
    _badgeLabel.text=badge; _symbolView.image=symbol ? [UIImage systemImageNamed:symbol] : nil;
    _chevronView.hidden=NO; [self setEmphasized:NO];
}
- (void)setEmphasized:(BOOL)emphasized {
    _cardView.layer.borderWidth=emphasized ? 1.5 : 0.5;
    _cardView.layer.borderColor=[(emphasized ? NCEBlue() : NCELine()) resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    _headingLabel.textColor=emphasized ? NCEBlue() : NCEInk();
}
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated { [super setHighlighted:highlighted animated:animated]; _cardView.alpha=highlighted ? 0.65 : 1; }
@end

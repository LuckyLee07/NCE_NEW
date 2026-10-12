#import "NCEStudyViews.h"
#import "NCELocalization.h"

UIImage *NCEVolumeImage(NSInteger book) {
    // Render an approved illustration from the original, unmodified design atlas.
    static NSArray *images;static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIImage *atlas=[UIImage imageNamed:@"study-volumes"];NSMutableArray *result=[NSMutableArray new];
        NSArray *rects=@[[NSValue valueWithCGRect:CGRectMake(65,155,330,300)],[NSValue valueWithCGRect:CGRectMake(435,155,320,300)],[NSValue valueWithCGRect:CGRectMake(800,155,320,300)],[NSValue valueWithCGRect:CGRectMake(1155,155,325,300)]];
        for(NSValue *value in rects){CGImageRef crop=CGImageCreateWithImageInRect(atlas.CGImage,value.CGRectValue);UIImage *image=crop ? [UIImage imageWithCGImage:crop] : [UIImage systemImageNamed:@"book"];if(crop)CGImageRelease(crop);[result addObject:image];}images=result;
    });return images[MIN(3,MAX(0,book))];
}
NSString *NCEVolumeTitle(NSInteger book) { return [NSString stringWithFormat:NCELocalizedString(@"第%d册"),(int)book+1]; }
NSString *NCEVolumeSubtitle(NSInteger book) { return NCELocalizedString(@[@"英语初阶",@"实践与进步",@"培养技能",@"流利英语"][MIN(3,MAX(0,book))]); }
void NCESetButtonTitle(UIButton *button,NSString *title){UIButtonConfiguration *config=button.configuration;config.title=title;if(title.length)config.background.cornerRadius=8;button.configuration=config;}

@implementation NCEVolumeControl { UIImageView *_image;UILabel *_title;UILabel *_subtitle;UILabel *_change;UIView *_line; }
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        _image=[UIImageView new];_image.contentMode=UIViewContentModeScaleAspectFit;_image.layer.cornerRadius=6;_image.clipsToBounds=YES;
        _title=NCELabel(nil,17,UIFontWeightSemibold,NCEInk());_subtitle=NCELabel(nil,13,UIFontWeightRegular,NCEMuted());
        _change=NCELabel([NCELocalizedString(@"切换") stringByAppendingString:@" ﹀"],14,UIFontWeightMedium,NCEMuted());_change.textAlignment=NSTextAlignmentRight;
        _line=[UIView new];_line.backgroundColor=NCELine();
        for(UIView *v in @[_image,_title,_subtitle,_change,_line]){v.userInteractionEnabled=NO;[self addSubview:v];}
        self.isAccessibilityElement=YES;self.accessibilityTraits=UIAccessibilityTraitButton;self.accessibilityIdentifier=@"book-picker";
    }return self;
}
- (CGSize)sizeThatFits:(CGSize)size {CGFloat width=MAX(40,size.width-(UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) ? 144 : 180));return CGSizeMake(size.width,MAX(92,NCETextHeight(_title.text,_title.font,width)+NCETextHeight(_subtitle.text,_subtitle.font,width)+28));}
- (void)setBook:(NSInteger)book{_book=book;_image.image=NCEVolumeImage(book);_title.text=NCEVolumeTitle(book);_subtitle.text=NCEVolumeSubtitle(book);self.accessibilityLabel=[NSString stringWithFormat:@"%@, %@, %@",_title.text,_subtitle.text,NCELocalizedString(@"切换")];[self setNeedsLayout];}
- (void)layoutSubviews {
    [super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.bounds.size.height,art=64;
    _image.frame=CGRectMake(0,(h-art)/2,72,art);
    BOOL large=UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);CGFloat changeWidth=large ? 44 : 90,textWidth=w-(large ? 144 : 180);
    _change.text=large ? @"⌄" : [NCELocalizedString(@"切换") stringByAppendingString:@" ﹀"];_change.frame=CGRectMake(w-changeWidth,0,changeWidth,h);
    CGFloat title=NCETextHeight(_title.text,_title.font,textWidth),detail=NCETextHeight(_subtitle.text,_subtitle.font,textWidth),y=(h-title-detail-4)/2;
    _title.frame=CGRectMake(88,y,textWidth,title);_subtitle.frame=CGRectMake(88,y+title+4,textWidth,detail);_line.frame=CGRectMake(0,h-1,w,0.5);
}
@end

@interface NCEBookPickerController : UITableViewController
@property(nonatomic) NSInteger selected;
@property(nonatomic,copy) void (^selection)(NSInteger);
@end
@implementation NCEBookPickerController
- (void)viewDidLoad{[super viewDidLoad];self.title=NCELocalizedString(@"选择册数");self.tableView.rowHeight=86;self.tableView.backgroundColor=NCEBackground();self.tableView.tableFooterView=[UIView new];self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];}
- (void)close{[self dismissViewControllerAnimated:YES completion:nil];}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return 4;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text=NCEVolumeTitle(indexPath.row);cell.textLabel.font=NCEFont(17,UIFontWeightSemibold);cell.detailTextLabel.text=NCEVolumeSubtitle(indexPath.row);cell.detailTextLabel.textColor=NCEMuted();cell.imageView.image=NCEVolumeImage(indexPath.row);
    cell.backgroundColor=indexPath.row==self.selected ? NCESky() : NCEBackground();cell.accessoryType=indexPath.row==self.selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;cell.tintColor=NCEBlue();cell.accessibilityIdentifier=[NSString stringWithFormat:@"book-%ld",(long)indexPath.row+1];return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{void (^selection)(NSInteger)=self.selection;[self dismissViewControllerAnimated:YES completion:^{if(selection)selection(indexPath.row);}];}
@end
void NCEShowBookPicker(UIViewController *host,NSInteger selected,void (^selection)(NSInteger)){
    NCEBookPickerController *picker=[NCEBookPickerController new];picker.selected=selected;picker.selection=selection;
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:picker];NCEConfigureNavigation(navigation.navigationBar);
    navigation.modalPresentationStyle=UIModalPresentationPageSheet;navigation.sheetPresentationController.detents=@[UISheetPresentationControllerDetent.mediumDetent,UISheetPresentationControllerDetent.largeDetent];navigation.sheetPresentationController.prefersGrabberVisible=YES;
    [host presentViewController:navigation animated:YES completion:nil];
}

@implementation NCEStudyRow
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier{return [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];}
- (void)configureTitle:(NSString *)title subtitle:(NSString *)subtitle number:(NSString *)number current:(BOOL)current{
    UIListContentConfiguration *content=[UIListContentConfiguration subtitleCellConfiguration];content.text=title;content.secondaryText=subtitle;content.textProperties.font=NCEFont(17,UIFontWeightMedium);content.secondaryTextProperties.font=NCEFont(13,UIFontWeightRegular);content.textProperties.color=current ? NCEBlue() : NCEInk();content.secondaryTextProperties.color=NCEMuted();content.textProperties.numberOfLines=0;content.secondaryTextProperties.numberOfLines=0;
    if(number.length){UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40,26)];content.image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx){[number drawAtPoint:CGPointMake(0,3) withAttributes:@{NSFontAttributeName:[UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular],NSForegroundColorAttributeName:current ? NCEBlue() : NCEMuted()}];}];}
    content.directionalLayoutMargins=NSDirectionalEdgeInsetsMake(14,20,14,20);self.contentConfiguration=content;
    self.backgroundColor=current ? NCESky() : NCEBackground();self.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
}
@end

@implementation NCEStudyEmptyView
- (instancetype)initWithSymbol:(NSString *)symbol title:(NSString *)title message:(NSString *)message action:(NSString *)action target:(id)target selector:(SEL)selector {
    if((self=[super initWithFrame:CGRectZero])){
        UIImageView *icon=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];icon.tintColor=NCEMuted();icon.contentMode=UIViewContentModeScaleAspectFit;
        UILabel *heading=NCELabel(title,20,UIFontWeightSemibold,NCEInk());heading.textAlignment=NSTextAlignmentCenter;
        UILabel *detail=NCELabel(message,14,UIFontWeightRegular,NCEMuted());detail.textAlignment=NSTextAlignmentCenter;
        NSMutableArray *views=[@[icon,heading,detail] mutableCopy];if(action.length){UIButton *button=NCEButton(action,nil,NO,target,selector);button.accessibilityIdentifier=@"empty-action";[views addObject:button];}
        UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:views];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;[self addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],[stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],[stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],[icon.heightAnchor constraintEqualToConstant:36]]];
        self.accessibilityIdentifier=@"study-empty-state";
    }return self;
}
@end

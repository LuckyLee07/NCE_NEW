#import "NCECourseViewController.h"
#import "NCEStudyStore.h"
#import "NCEStudyViews.h"
#import "TextViewController.h"
#import "WordViewController.h"
#import "NCEPracticeViewController.h"

@implementation NCECourseViewController {
    NSInteger _book,_section;
    NSDictionary *_lesson;
    UILabel *_heading,*_translation;
    UISegmentedControl *_segments;
    NSMutableDictionary<NSNumber *,BaseViewController *> *_pages;
    BaseViewController *_active;
}
- (instancetype)initWithBook:(NSInteger)book lesson:(NSDictionary *)lesson section:(NSInteger)section {
    if((self=[super init])){_book=book;_lesson=lesson;_section=section;_pages=[NSMutableDictionary new];self.hidesBottomBarWhenPushed=YES;
        self.titleString=[NSString stringWithFormat:@"%@ · %@",NCEVolumeTitle(book),[NSString stringWithFormat:NCELocalizedString(@"第%@课"),lesson[@"id"]]];
    }return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _heading=NCELabel([NCEStudyStore lessonTitle:_lesson],26,UIFontWeightBold,NCEInk());_heading.accessibilityIdentifier=@"course-title";
    _translation=NCELabel([NCEStudyStore lessonTranslation:_lesson],14,UIFontWeightRegular,NCEMuted());
    _segments=[[UISegmentedControl alloc] initWithItems:@[NCELocalizedString(@"听读"),NCELocalizedString(@"单词"),NCELocalizedString(@"练习")]];
    [_segments setTitleTextAttributes:@{NSForegroundColorAttributeName:NCEMuted(),NSFontAttributeName:NCEFont(14,UIFontWeightMedium)} forState:UIControlStateNormal];
    [_segments setTitleTextAttributes:@{NSForegroundColorAttributeName:NCEBlue(),NSFontAttributeName:NCEFont(14,UIFontWeightSemibold)} forState:UIControlStateSelected];
    _segments.accessibilityIdentifier=@"course-sections";_segments.selectedSegmentIndex=_section;
    [_segments addTarget:self action:@selector(changeSection) forControlEvents:UIControlEventValueChanged];
    for(UIView *view in @[_heading,_translation,_segments])[self.view addSubview:view];
    NSDictionary *resume=[NCEStudyStore resumeForBook:_book];NSInteger sentence=[resume[@"lesson"][@"id"] isEqual:_lesson[@"id"]] ? [resume[@"sentence"] integerValue] : 0;
    [NCEStudyStore recordLesson:_lesson book:_book sentence:sentence];[self changeSection];
}
- (void)setKeyboardVisible:(BOOL)keyboardVisible {_keyboardVisible=keyboardVisible;[self.view setNeedsLayout];}
- (void)showSection:(NSInteger)section {_segments.selectedSegmentIndex=section;[self changeSection];}
- (void)changeSection {
    [self.view endEditing:YES];self.keyboardVisible=NO;
    if(_active){[_active willMoveToParentViewController:nil];[_active beginAppearanceTransition:NO animated:NO];[_active.view removeFromSuperview];[_active endAppearanceTransition];[_active removeFromParentViewController];}
    NSInteger index=_segments.selectedSegmentIndex;
    BaseViewController *page=_pages[@(index)];
    if(!page){
        if(index==0)page=[[TextViewController alloc] initWithBookId:(int)_book withLesson:_lesson];
        else if(index==1)page=[[WordViewController alloc] initWithBookId:(int)_book withLesson:_lesson withFunction:1];
        else page=[[NCEPracticeViewController alloc] initWithWords:[NCEStudyStore wordsForBook:_book lesson:[_lesson[@"id"] integerValue]] key:[NSString stringWithFormat:@"lesson-%ld-%@",(long)_book,_lesson[@"id"]] mode:2];
        page.embeddedInLesson=YES;_pages[@(index)]=page;
    }
    _active=page;[self addChildViewController:page];[page beginAppearanceTransition:YES animated:NO];[self.view addSubview:page.view];[page didMoveToParentViewController:self];[page endAppearanceTransition];[self.view setNeedsLayout];
}
- (void)layoutAcademyViews {
    CGRect frame=[self academyContentFrame];CGFloat x=frame.origin.x+24,w=frame.size.width-48,y=frame.origin.y+12;
    BOOL largeType=UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    _heading.hidden=self.keyboardVisible;_translation.hidden=self.keyboardVisible || largeType;
    _heading.numberOfLines=largeType ? 2 : 0;
    if(!self.keyboardVisible){
        CGFloat h=NCETextHeight(_heading.text,_heading.font,w);if(largeType)h=MIN(h,ceil(_heading.font.lineHeight*2));
        _heading.frame=CGRectMake(x,y,w,h);y+=h+6;
        if(!largeType){h=NCETextHeight(_translation.text,_translation.font,w);_translation.frame=CGRectMake(x,y,w,h);y+=h;}
        y+=20;
    }
    _segments.frame=CGRectMake(x,y,w,44);y+=54;
    _active.view.frame=CGRectMake(frame.origin.x,y,frame.size.width,MAX(0,CGRectGetMaxY(frame)-y));
}
@end

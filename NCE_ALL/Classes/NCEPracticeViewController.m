#import "NCEPracticeViewController.h"
#import "NCEPracticeSession.h"
#import "NCEStudyStore.h"
#import "NCEStudyViews.h"
#import "NCEWordResourceStore.h"
#import "NCECourseViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AdmobManager.h"

@interface NCEPracticeModePicker : UITableViewController
@property(nonatomic) NSInteger selected;
@property(nonatomic,copy) void (^selection)(NSInteger);
@end
@implementation NCEPracticeModePicker
- (void)viewDidLoad {[super viewDidLoad];self.title=NCELocalizedString(@"练习方式");self.tableView.rowHeight=62;self.tableView.backgroundColor=NCEBackground();self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];}
- (void)close {[self dismissViewControllerAnimated:YES completion:nil];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {return 2;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {return section==0 ? 2 : 3;}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {return NCELocalizedString(section==0 ? @"回想" : @"测试");}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {NSInteger mode=indexPath.section==0 ? indexPath.row : indexPath.row+2;UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];cell.textLabel.text=NCELocalizedString(@[@"词义回想",@"单词回想",@"听写",@"英选义",@"义选英"][mode]);cell.textLabel.font=NCEFont(17,UIFontWeightMedium);cell.accessoryType=mode==self.selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;cell.tintColor=NCEBlue();cell.backgroundColor=mode==self.selected ? NCESky() : NCEBackground();cell.accessibilityIdentifier=[NSString stringWithFormat:@"practice-mode-%ld",(long)mode];return cell;}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {NSInteger mode=indexPath.section==0 ? indexPath.row : indexPath.row+2;void (^selection)(NSInteger)=self.selection;[self dismissViewControllerAnimated:YES completion:^{selection(mode);}];}
@end
@interface NCEPracticeViewController () <UITextFieldDelegate>
@end
@implementation NCEPracticeViewController {
    NSArray<NSDictionary *> *_source;
    NSString *_key;
    NSInteger _mode;
    NCEPracticeSession *_session;
    UIScrollView *_modeScroll,*_scroll;
    UIButton *_modeButton;
    NSMutableArray<UIView *> *_flow;
    UITextField *_answer;
    UIButton *_primary,*_skip;
    UILabel *_feedbackLabel;
    AVAudioPlayer *_audio;
    CGRect _keyboardFrame;
    BOOL _revealed;
    NSMutableIndexSet *_handledCompletionModes;
}
- (instancetype)initWithWords:(NSArray<NSDictionary *> *)words key:(NSString *)key mode:(NSInteger)mode {
    if((self=[super init])){_source=words.copy;_key=key;NSNumber *last=[NSUserDefaults.standardUserDefaults objectForKey:[@"NCEPracticeLastMode." stringByAppendingString:key]];_mode=last && last.integerValue>=0 && last.integerValue<5 ? last.integerValue : mode;self.titleString=NCELocalizedString(@"练习");}return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _modeScroll=[UIScrollView new];_modeScroll.showsHorizontalScrollIndicator=NO;[self.view addSubview:_modeScroll];
    _modeButton=NCEButton(nil,@"chevron.down",NO,self,@selector(showModes));_modeButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeading;_modeButton.accessibilityIdentifier=@"practice-mode-picker";UIButtonConfiguration *modeConfiguration=_modeButton.configuration;modeConfiguration.imagePlacement=NSDirectionalRectEdgeTrailing;_modeButton.configuration=modeConfiguration;[_modeScroll addSubview:_modeButton];
    _scroll=[UIScrollView new];_scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;_scroll.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;_scroll.accessibilityIdentifier=@"practice-content";[self.view addSubview:_scroll];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [self loadSession];
}
- (NSArray *)roundItems {return [_source subarrayWithRange:NSMakeRange(0,MIN(20,_source.count))];}
- (void)loadSession {
    NSString *key=[NSString stringWithFormat:@"%@-%ld",_key,(long)_mode];
    _session=[[NCEPracticeSession alloc] initWithItems:[self roundItems] key:key defaults:NSUserDefaults.standardUserDefaults];_revealed=_session.answered;
    [self render];
}
- (void)showModes {
    [self.view endEditing:YES];NCEPracticeModePicker *picker=[[NCEPracticeModePicker alloc] initWithStyle:UITableViewStyleInsetGrouped];picker.selected=_mode;
    __weak typeof(self) weakSelf=self;picker.selection=^(NSInteger mode){__strong typeof(weakSelf) self=weakSelf;if(!self || self->_mode==mode)return;[self->_session save];[self->_audio stop];self->_mode=mode;[NSUserDefaults.standardUserDefaults setInteger:mode forKey:[@"NCEPracticeLastMode." stringByAppendingString:self->_key]];[self loadSession];};
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:picker];NCEConfigureNavigation(nav.navigationBar);nav.sheetPresentationController.detents=@[UISheetPresentationControllerDetent.mediumDetent,UISheetPresentationControllerDetent.largeDetent];nav.sheetPresentationController.prefersGrabberVisible=YES;[self presentViewController:nav animated:YES completion:nil];
}
- (void)add:(UIView *)view {[_flow addObject:view];[_scroll addSubview:view];}
- (UILabel *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color {
    UILabel *label=NCELabel(text,size,size>=24 ? UIFontWeightSemibold : UIFontWeightRegular,color);[self add:label];return label;
}
- (UIButton *)button:(NSString *)text symbol:(NSString *)symbol primary:(BOOL)primary action:(SEL)action identifier:(NSString *)identifier {
    UIButton *button=NCEButton(text,symbol,primary,self,action);button.accessibilityIdentifier=identifier;[self add:button];return button;
}
- (NSString *)optionText:(NSDictionary *)word {return _mode==3 ? [NCEStudyStore meaningForWord:word] : [NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]];}
- (void)prepareOptions {
    if(_session.options.count)return;
    NSDictionary *word=_session.items[_session.index];NSMutableArray *choices=[NSMutableArray arrayWithObject:word];NSMutableSet *seen=[NSMutableSet setWithObject:[self optionText:word]];
    NSArray *pool=[NCEStudyStore wordsForBook:[word[@"book_id"] integerValue]-1 lesson:0];
    NSUInteger offset=pool.count ? arc4random_uniform((uint32_t)pool.count) : 0;
    for(NSUInteger i=0;i<pool.count && choices.count<4;i++){NSDictionary *candidate=pool[(offset+i)%pool.count];NSString *label=[self optionText:candidate];if(!label.length || [seen containsObject:label] || [candidate[@"english"] isEqual:word[@"english"]])continue;[choices addObject:candidate];[seen addObject:label];}
    for(NSUInteger i=choices.count;i>1;i--)[choices exchangeObjectAtIndex:i-1 withObjectAtIndex:arc4random_uniform((uint32_t)i)];
    _session.options=choices;[_session save];
}
- (void)render {
    [_primary removeFromSuperview];[_skip removeFromSuperview];
    for(UIView *view in _scroll.subviews)[view removeFromSuperview];_flow=[NSMutableArray new];_answer=nil;_primary=nil;_skip=nil;_feedbackLabel=nil;
    NCESetButtonTitle(_modeButton,NCELocalizedString(@[@"词义回想",@"单词回想",@"听写",@"英选义",@"义选英"][_mode]));
    if(!_source.count){[self add:[[NCEStudyEmptyView alloc] initWithSymbol:@"text.book.closed" title:NCELocalizedString(@"暂无可练习单词") message:NCELocalizedString(@"换一课或到单词本选择单词。") action:nil target:nil selector:NULL]];[self.view setNeedsLayout];return;}
    if(_session.complete){[self renderResult];[self.view setNeedsLayout];[self.view layoutIfNeeded];[_scroll setContentOffset:CGPointZero animated:NO];return;}
    NSDictionary *word=_session.items[_session.index];
    UILabel *progress=[self label:[NSString stringWithFormat:NCELocalizedString(@"第 %lu / %lu 题"),(unsigned long)_session.index+1,(unsigned long)_session.items.count] size:13 color:NCEMuted()];progress.accessibilityIdentifier=@"practice-progress";
    NSString *prompt=_mode==2 ? NCELocalizedString(@"听音拼写单词") : (_mode==1 || _mode==4 ? [NCEStudyStore meaningForWord:word] : [NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]]);
    UILabel *title=[self label:prompt size:30 color:NCEInk()];title.accessibilityIdentifier=@"practice-question";
    if(_mode==2 || _mode==0)[self button:NCELocalizedString(@"播放发音") symbol:@"speaker.wave.2" primary:NO action:@selector(playAudio) identifier:@"practice-audio"];
    if(_mode==2){
        _answer=[UITextField new];_answer.borderStyle=UITextBorderStyleRoundedRect;_answer.backgroundColor=NCESurface();_answer.font=NCEFont(22,UIFontWeightMedium);_answer.placeholder=NCELocalizedString(@"输入听到的单词");_answer.autocorrectionType=UITextAutocorrectionTypeNo;_answer.spellCheckingType=UITextSpellCheckingTypeNo;_answer.autocapitalizationType=UITextAutocapitalizationTypeNone;_answer.keyboardType=UIKeyboardTypeASCIICapable;_answer.returnKeyType=UIReturnKeyDone;_answer.delegate=self;_answer.text=_session.input;_answer.enabled=!_session.answered;_answer.accessibilityIdentifier=@"dictation-answer";[_answer addTarget:self action:@selector(inputChanged:) forControlEvents:UIControlEventEditingChanged];[self add:_answer];
    }else if(_mode>=3){
        [self label:NCELocalizedString(_mode==3 ? @"选择正确的词义" : @"选择正确的英文") size:14 color:NCEMuted()];[self prepareOptions];
        for(NSInteger i=0;i<_session.options.count;i++){
            UIButton *option=[self button:[NSString stringWithFormat:@"%@   %@",@[@"A",@"B",@"C",@"D"][i],[self optionText:_session.options[i]]] symbol:nil primary:NO action:@selector(selectOption:) identifier:[NSString stringWithFormat:@"practice-option-%ld",(long)i]];option.tag=i;option.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeading;
            UIButtonConfiguration *c=option.configuration;c.titleAlignment=UIButtonConfigurationTitleAlignmentLeading;c.background.cornerRadius=6;c.background.strokeWidth=1;c.background.strokeColor=NCELine();c.baseForegroundColor=NCEInk();
            BOOL correct=[_session.options[i][@"english"] isEqual:word[@"english"]];
            if(_session.answered && correct){c.background.backgroundColor=[NCESuccess() colorWithAlphaComponent:0.1];c.background.strokeColor=NCESuccess();c.image=[UIImage systemImageNamed:@"checkmark.circle"];c.title=[c.title stringByAppendingFormat:@" · %@",NCELocalizedString(@"正确答案")];}
            else if(_session.selectedOption==i){c.background.backgroundColor=NCESky();c.background.strokeColor=_session.answered ? NCEError() : NCEBlue();if(_session.answered){c.image=[UIImage systemImageNamed:@"xmark.circle"];c.title=[c.title stringByAppendingFormat:@" · %@",NCELocalizedString(@"你的选择")];}}
            option.configuration=c;option.userInteractionEnabled=!_session.answered;
        }
    }else if(!_revealed){[self button:NCELocalizedString(@"想好后，查看答案") symbol:@"eye" primary:YES action:@selector(reveal) identifier:@"practice-reveal"];}
    if(_mode<2 && _revealed && !_session.answered){[self label:_mode==0 ? [NCEStudyStore meaningForWord:word] : [NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]] size:24 color:NCEBlue()];[self button:NCELocalizedString(@"记住了") symbol:@"checkmark" primary:YES action:@selector(recallCorrect) identifier:@"practice-remembered"];[self button:NCELocalizedString(@"还没记住") symbol:nil primary:NO action:@selector(recallWrong) identifier:@"practice-forgot"];}
    if(_session.answered){
        NSDictionary *record=_session.answers[_session.index];BOOL correct=[record[@"correct"] boolValue],skipped=[record[@"skipped"] boolValue];
        UILabel *feedback=[self label:NCELocalizedString(skipped ? @"已跳过" : correct ? @"回答正确" : @"再记一次") size:20 color:correct ? NCESuccess() : NCEMuted()];feedback.accessibilityIdentifier=@"practice-feedback";_feedbackLabel=feedback;
        if(_mode==2 || _mode<2)[self label:[NSString stringWithFormat:@"%@  ·  %@",[NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]],[NCEStudyStore meaningForWord:word]] size:19 color:NCEInk()];
        NSDictionary *example=[NCEStudyStore exampleForWord:word];if(example)[self label:[NSString stringWithFormat:@"%@\n%@",example[@"english"],example[@"translation"]] size:15 color:NCEMuted()];
        _primary=[self button:NCELocalizedString(_session.index+1==_session.items.count ? @"查看结果" : @"下一题") symbol:@"arrow.right" primary:YES action:@selector(next) identifier:@"practice-next"];
    }else{
        if(_mode>=2){_primary=[self button:NCELocalizedString(@"确认答案") symbol:nil primary:YES action:@selector(submit) identifier:@"practice-submit"];_primary.enabled=_mode==2 ? _session.input.length>0 : _session.selectedOption>=0;}
        _skip=[self button:NCELocalizedString(@"跳过") symbol:nil primary:NO action:@selector(skip) identifier:@"practice-skip"];
    }
    [self.view setNeedsLayout];[self.view layoutIfNeeded];[_scroll setContentOffset:CGPointZero animated:NO];
    if(_feedbackLabel)[_scroll scrollRectToVisible:CGRectMake(0,_feedbackLabel.frame.origin.y,_scroll.bounds.size.width,MAX(_feedbackLabel.frame.size.height,_scroll.contentSize.height-_feedbackLabel.frame.origin.y)) animated:NO];
}
- (void)renderResult {
    UILabel *title=[self label:NCELocalizedString(@"本次练习完成") size:28 color:NCEInk()];title.accessibilityIdentifier=@"practice-result";
    [self label:[NSString stringWithFormat:@"%lu / %lu",(unsigned long)_session.correctCount,(unsigned long)_session.items.count] size:44 color:NCEBlue()].accessibilityIdentifier=@"practice-score";
    [self label:[NSString stringWithFormat:NCELocalizedString(@"答对 %lu · 答错 %lu · 跳过 %lu"),(unsigned long)_session.correctCount,(unsigned long)(_session.answers.count-_session.correctCount-_session.skippedCount),(unsigned long)_session.skippedCount] size:16 color:NCEMuted()];
    if(_session.wrongWords.count){[self label:NCELocalizedString(@"本次错词") size:20 color:NCEInk()];for(NSDictionary *word in _session.wrongWords){UIButton *button=[self button:[NSString stringWithFormat:@"%@  ·  %@",[NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]],[NCEStudyStore meaningForWord:word]] symbol:@"speaker.wave.2" primary:NO action:@selector(playResultWord:) identifier:[@"result-word-" stringByAppendingString:word[@"english"]]];button.tag=[_session.wrongWords indexOfObject:word];}
        [self button:NCELocalizedString(@"只练错词") symbol:nil primary:YES action:@selector(retryWrong) identifier:@"practice-retry-wrong"];
    }else{[self label:NCELocalizedString(_session.skippedCount ? @"本次没有答错的单词，可再练一遍巩固。" : @"全部答对，做得不错！") size:20 color:NCESuccess()];}
    [self button:NCELocalizedString(self.embeddedInLesson ? @"返回课文" : @"返回单词本") symbol:nil primary:_session.wrongWords.count==0 action:@selector(returnToLesson) identifier:@"practice-return"];
    [self button:NCELocalizedString(@"查看本次答题") symbol:@"list.bullet" primary:NO action:@selector(showAnswers) identifier:@"practice-answers"];
    [self button:NCELocalizedString(@"再练一次") symbol:@"arrow.clockwise" primary:NO action:@selector(retryAll) identifier:@"practice-retry-all"];
}
- (void)returnToLesson {[self performAfterCompletedWordBreak:^{if([self.parentViewController isKindOfClass:NCECourseViewController.class])[(NCECourseViewController *)self.parentViewController showSection:0];else [self.navigationController popViewControllerAnimated:YES];}];}
- (void)showAnswers {
    UIViewController *page=[UIViewController new];page.title=NCELocalizedString(@"查看本次答题");page.view.backgroundColor=NCEBackground();UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[page.view addSubview:scroll];[NSLayoutConstraint activateConstraints:@[[scroll.topAnchor constraintEqualToAnchor:page.view.safeAreaLayoutGuide.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:page.view.safeAreaLayoutGuide.bottomAnchor],[scroll.leadingAnchor constraintEqualToAnchor:page.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:page.view.trailingAnchor]]];
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=24;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];[NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48]]];
    for(NSDictionary *r in _session.answers){NSString *status=NCELocalizedString([r[@"skipped"] boolValue] ? @"已跳过" : [r[@"correct"] boolValue] ? @"回答正确" : @"再记一次");NSDictionary *word=r[@"word"];NSString *text=[NSString stringWithFormat:@"%lu. %@ · %@\n%@\n%@",(unsigned long)[_session.answers indexOfObject:r]+1,word[@"english"],[NCEStudyStore meaningForWord:word],status,r[@"answer"]];[stack addArrangedSubview:NCELabel(text,17,UIFontWeightRegular,NCEInk())];}
    [self.navigationController pushViewController:page animated:YES];
}
- (void)playResultWord:(UIButton *)sender {NSString *path=[NCEWordResourceStore.sharedStore audioPathForWord:_session.wrongWords[sender.tag][@"english"]];[_audio stop];if(path){_audio=[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];[_audio play];}}
- (void)retryWrong {NSArray *wrong=_session.wrongWords;if(!wrong.count)return;[self performAfterCompletedWordBreak:^{[self->_session restartWithItems:wrong];[self->_handledCompletionModes removeIndex:self->_mode];self->_revealed=NO;[self render];}];}
- (void)retryAll {[self performAfterCompletedWordBreak:^{[self->_session restartWithItems:[self roundItems]];[self->_handledCompletionModes removeIndex:self->_mode];self->_revealed=NO;[self render];}];}
- (void)performAfterCompletedWordBreak:(dispatch_block_t)completion {
    if(!_session.complete || [_handledCompletionModes containsIndex:_mode]){completion();return;}
    if(!_handledCompletionModes)_handledCompletionModes=[NSMutableIndexSet new];
    [_handledCompletionModes addIndex:_mode];
    [[AdmobManager sharedInstance] handleCompletedWordBreakWithCompletion:completion];
}
- (void)inputChanged:(UITextField *)field {_session.input=field.text;[_session save];_primary.enabled=[field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length>0;}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {[self submit];return YES;}
- (void)selectOption:(UIButton *)sender {_session.selectedOption=sender.tag;[_session save];[self render];}
- (void)reveal {_revealed=YES;[self render];}
- (void)recallCorrect {[self grade:@"" correct:YES skipped:NO];}
- (void)recallWrong {[self grade:@"" correct:NO skipped:NO];}
- (void)submit {
    if(_session.complete || _session.answered)return;NSDictionary *word=_session.items[_session.index];
    if(_mode==2){if(![_session.input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length)return;[self grade:_session.input correct:[NCEWordResourceStore.sharedStore answer:_session.input matchesWord:word[@"english"]] skipped:NO];}
    else if(_mode>=3 && _session.selectedOption>=0){NSDictionary *choice=_session.options[_session.selectedOption];[self grade:choice[@"english"] correct:[choice[@"english"] isEqual:word[@"english"]] skipped:NO];}
}
- (void)skip {[self grade:@"" correct:NO skipped:YES];}
- (void)grade:(NSString *)answer correct:(BOOL)correct skipped:(BOOL)skipped {
    [self.view endEditing:YES];if([_session submit:answer correct:correct skipped:skipped] && !correct && !skipped)[NCEStudyStore markWordWrong:_session.items[_session.index]];[self render];
}
- (void)next {[_audio stop];[_session advance];_revealed=NO;[self render];}
- (void)playAudio {if(_session.complete)return;NSString *path=[NCEWordResourceStore.sharedStore audioPathForWord:_session.items[_session.index][@"english"]];[_audio stop];if(path){_audio=[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];[_audio play];}}
- (void)keyboard:(NSNotification *)notification {
    if(!self.view.window)return;_keyboardFrame=[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];CGRect converted=[self.view convertRect:_keyboardFrame fromView:nil];if([self.parentViewController isKindOfClass:NCECourseViewController.class])[(NCECourseViewController *)self.parentViewController setKeyboardVisible:CGRectIntersectsRect(self.view.bounds,converted)];[self.parentViewController.view layoutIfNeeded];[self.view setNeedsLayout];[self.view layoutIfNeeded];
    if(_answer.isFirstResponder)[_scroll scrollRectToVisible:CGRectInset(_answer.frame,0,-20) animated:YES];
}
- (void)layoutAcademyViews {
    CGRect frame=[self academyContentFrame];CGFloat x=frame.origin.x+24,w=frame.size.width-48;
    _modeScroll.frame=CGRectMake(x,frame.origin.y,w,44);_modeButton.frame=CGRectMake(0,0,w,44);_modeScroll.contentSize=CGSizeMake(w,44);
    CGRect keyboard=[self.view convertRect:_keyboardFrame fromView:nil];CGFloat bottom=CGRectGetMaxY(frame);if(CGRectIntersectsRect(self.view.bounds,keyboard))bottom=MIN(bottom,keyboard.origin.y);
    CGFloat actionBottom=bottom;
    if(_skip){CGFloat h=MAX(44,NCETextHeight(_skip.configuration.title,NCEFont(15,UIFontWeightSemibold),w-48)+20);if(_skip.superview!=self.view)[self.view addSubview:_skip];_skip.frame=CGRectMake(x,actionBottom-h,w,h);actionBottom-=h+8;}
    if(_primary){CGFloat h=MAX(48,NCETextHeight(_primary.configuration.title,NCEFont(15,UIFontWeightSemibold),w-48)+20);if(_primary.superview!=self.view)[self.view addSubview:_primary];_primary.frame=CGRectMake(x,actionBottom-h,w,h);actionBottom-=h+16;}
    _scroll.frame=CGRectMake(x,frame.origin.y+50,w,MAX(0,actionBottom-frame.origin.y-50));
    CGFloat y=8;
    for(UIView *view in _flow){
        if(view==_primary || view==_skip)continue;
        CGFloat h=52;
        if([view isKindOfClass:UILabel.class]){UILabel *l=(UILabel *)view;h=NCETextHeight(l.text,l.font,w);}
        else if([view isKindOfClass:UIButton.class]){UIButton *button=(UIButton *)view;h=MAX(48,NCETextHeight(button.configuration.title,NCEFont(15,UIFontWeightSemibold),w-60)+22);}
        else if([view isKindOfClass:NCEStudyEmptyView.class])h=MAX(220,_scroll.bounds.size.height-20);
        view.frame=CGRectMake(0,y,w,h);y+=h+12;
    }
    _scroll.contentSize=CGSizeMake(w,y+12);
}
- (void)viewWillDisappear:(BOOL)animated {[super viewWillDisappear:animated];[self.view endEditing:YES];if([self.parentViewController isKindOfClass:NCECourseViewController.class])[(NCECourseViewController *)self.parentViewController setKeyboardVisible:NO];[_session save];[_audio stop];}
- (void)dealloc {[NSNotificationCenter.defaultCenter removeObserver:self];}
@end

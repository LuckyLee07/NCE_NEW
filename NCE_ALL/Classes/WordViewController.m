//
//  WordViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "WordViewController.h"
#import "sqlite3.h"
#import <AVFoundation/AVFoundation.h>
#import "MBProgressHUD.h"
#import "CKAlertView.h"
#import "OnlineDictionaryViewController.h"
#import "AdmobManager.h"
#import "NCEWordResourceStore.h"
#import "NCELocalization.h"
#import "NCELessonResourceStore.h"
#import "NCEStudyStore.h"
#import "NCEStudyViews.h"
#import "NCECourseViewController.h"

@interface WordViewController () <AVAudioPlayerDelegate, CKAlertViewDelegate, UIAlertViewDelegate>
{
    int _bookId;
    NSMutableArray *_items;
    NSDictionary *_lesson;
    int _function; // 1：单词学习 2：词义回想 3：单词回想
    
	    AVAudioPlayer *_audioPlayer;
	    int _currentIndex;
        BOOL _didHandleCompletionBreak;
    
    UIButton *_continueButton;
    UIButton *_pauseButton;
    
    UILabel *_englishLabel;
    UILabel *_countLabel;
    
    UIView *_chineseView;
    UILabel *_chineseLabel;
    UIImageView *_wordImageView;
    UILabel *_wordVisualHint;
    UILabel *_wordVisualCaption;
    NSString *_wordVisualPresentation;
    UIScrollView *_wordScroll;
    UIView *_wordCard;
    UIView *_controlsView;
    UILabel *_contextLabel;
    UIProgressView *_progress;
    UILabel *_masteryPrompt;
    UILabel *_exampleLabel;
    UILabel *_exampleTitle;
    UILabel *_exampleTranslation;
    UIView *_exampleDivider;
    UIView *_controlsSeparator;
    UIView *_exampleView;
    UIButton *_revealButton;
    UIButton *_wordPrevious;
    UIButton *_wordNext;
    UIButton *_repeatButton;
    NSArray<UIButton *> *_masteryButtons;
    NSInteger _masteryStatus;
    NSDictionary *_example;
    UIButton *_bookmark,*_practiceButton,*_wordList;

}

- (void)initData;
- (void)willShowWordInformation;
- (void)showWordInformation;
- (void)handleWordSessionCompletionIfNeeded;
- (void)addBottomView:(CGFloat)startPosy;

- (void)prev;
- (void)pause;
- (void)next;

- (void)signWord:(id)sender;
- (void)showEnglish;
- (void)showChinese;
- (void)repeat;

- (void)showOnlineDictionarys;

@end

@implementation WordViewController

- (id)initWithBookId:(int)bookId withLesson:(NSDictionary *)lesson withFunction:(int)function
{
    self = [super init];
    if (self) {
        _bookId = bookId;
        _lesson = lesson;
	        _function = function;
	        [self initData];
	        
	        _currentIndex = 0;
            _didHandleCompletionBreak = NO;
	    }
	    return self;
}

- (id)initWithData:(NSArray *)data withIndex:(int)index
{
    self = [super init];
	    if (self) {
	        _items = [[NSMutableArray alloc] initWithArray:data];
            _bookId=MAX(0,[data.firstObject[@"book_id"] intValue]-1);
	        _currentIndex = index;
            _didHandleCompletionBreak = NO;
	    }
	    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _contextLabel=NCELabel(nil,13,UIFontWeightMedium,NCEMuted());[self.view addSubview:_contextLabel];
    _countLabel=NCELabel(nil,13,UIFontWeightSemibold,NCEBlue());_countLabel.textAlignment=NSTextAlignmentRight;[self.view addSubview:_countLabel];
    _progress=[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];_progress.trackTintColor=NCESurface();_progress.progressTintColor=NCEBlue();[self.view addSubview:_progress];
    _wordScroll=[UIScrollView new];_wordScroll.accessibilityIdentifier=@"word-content";_wordScroll.contentInsetAdjustmentBehavior=UIScrollViewContentInsetAdjustmentNever;[self.view addSubview:_wordScroll];
    _wordCard=[UIView new];[_wordScroll addSubview:_wordCard];
    _wordImageView=[UIImageView new];_wordImageView.contentMode=UIViewContentModeScaleAspectFit;_wordImageView.isAccessibilityElement=YES;_wordImageView.accessibilityIdentifier=@"word-image";[_wordCard addSubview:_wordImageView];
    _wordVisualHint=NCELabel(nil,19,UIFontWeightMedium,NCEBlue());_wordVisualHint.numberOfLines=0;_wordVisualHint.textAlignment=NSTextAlignmentCenter;_wordVisualHint.accessibilityIdentifier=@"word-visual-hint";[_wordImageView addSubview:_wordVisualHint];
    _wordVisualCaption=NCELabel(nil,16,UIFontWeightMedium,NCEBlue());_wordVisualCaption.numberOfLines=0;_wordVisualCaption.textAlignment=NSTextAlignmentCenter;_wordVisualCaption.accessibilityIdentifier=@"word-visual-caption";[_wordCard addSubview:_wordVisualCaption];
    _englishLabel=NCELabel(nil,28,UIFontWeightBold,NCEInk());_englishLabel.textAlignment=NSTextAlignmentCenter;_englishLabel.accessibilityIdentifier=@"word-english";[_wordCard addSubview:_englishLabel];
    _chineseView=[UIView new];[_wordCard addSubview:_chineseView];
    _chineseLabel=NCELabel(nil,16,UIFontWeightRegular,NCEMuted());_chineseLabel.textAlignment=NSTextAlignmentCenter;_chineseLabel.accessibilityIdentifier=@"word-translation";[_chineseView addSubview:_chineseLabel];
    _repeatButton=NCEButton(nil,@"speaker.wave.2",NO,self,@selector(repeat));_repeatButton.accessibilityIdentifier=@"word-repeat";_repeatButton.accessibilityLabel=NCELocalizedString(@"重读单词");[_wordCard addSubview:_repeatButton];
    _exampleView=[UIView new];[_wordCard addSubview:_exampleView];
    _exampleDivider=[UIView new];_exampleDivider.backgroundColor=NCELine();[_exampleView addSubview:_exampleDivider];
    _exampleTitle=NCELabel(NCELocalizedString(@"课文例句"),12,UIFontWeightSemibold,NCEBlue());[_exampleView addSubview:_exampleTitle];
    _exampleLabel=NCELabel(nil,16,UIFontWeightMedium,NCEInk());[_exampleView addSubview:_exampleLabel];
    _exampleTranslation=NCELabel(nil,13,UIFontWeightRegular,NCEMuted());[_exampleView addSubview:_exampleTranslation];
    if(_function==2 || _function==3){
        _revealButton=NCEButton(NCELocalizedString(@"想好后，查看答案"),@"eye",NO,self,_function==2 ? @selector(showChinese) : @selector(showEnglish));
        _revealButton.accessibilityIdentifier=_function==2 ? @"word-show-translation" : @"word-show-english";
        [_wordCard addSubview:_revealButton];
    }
    UIButton *dictionary=NCEButton(nil,@"character.book.closed",NO,self,@selector(showOnlineDictionarys));dictionary.frame=CGRectMake(0,0,44,44);dictionary.accessibilityIdentifier=@"word-online-dictionary";dictionary.accessibilityLabel=NCELocalizedString(@"在线词典");
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:dictionary];
    if (@available(iOS 26.0, *)) self.navigationItem.rightBarButtonItem.hidesSharedBackground=YES;
    _bookmark=NCEButton(nil,@"bookmark",NO,self,@selector(toggleBookmark));_bookmark.accessibilityIdentifier=@"word-bookmark";_bookmark.accessibilityLabel=NCELocalizedString(@"收藏单词");[self.view addSubview:_bookmark];
    [self addBottomView:0];
    if(self.embeddedInLesson){
        _practiceButton=NCEButton(NCELocalizedString(@"本课练习"),@"arrow.right",YES,self,@selector(openPractice));_practiceButton.accessibilityIdentifier=@"word-practice";[_controlsView addSubview:_practiceButton];
        _wordList=NCEButton(nil,@"list.bullet",NO,self,@selector(showWordList));_wordList.accessibilityIdentifier=@"word-list";_wordList.accessibilityLabel=NCELocalizedString(@"本课单词");[_controlsView addSubview:_wordList];
        [self.view addSubview:_countLabel];[_wordCard addSubview:_bookmark];
    }
    [self showWordInformation];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self pause];
}

#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    _continueButton.hidden=self.embeddedInLesson;_pauseButton.hidden=YES;
    if(self.readingLookup)return;
    if(self.embeddedInLesson){[self handleWordSessionCompletionIfNeeded];return;}
    if (_currentIndex < _items.count-1) {
        [self performSelector:@selector(next) withObject:nil afterDelay:5];
    } else {
        [self handleWordSessionCompletionIfNeeded];
    }
}

#pragma mark -
#pragma mark CKAlertViewDelegate

- (void)alertView:(UIView *)alertView customClickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *word = [[_items objectAtIndex:_currentIndex] objectForKey:@"english"];
    OnlineDictionaryViewController *dictionaryController = [[OnlineDictionaryViewController alloc] initWithDictionaryId:(int)buttonIndex withWord:word];
    [self.navigationController pushViewController:dictionaryController animated:YES];
}

#pragma mark -
#pragma mark Private Methods

- (void)initData
{
    _items = [[NSMutableArray alloc] init];
    
    sqlite3 *database;
    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //        NSLog(@"ok");
    }
    
    int lessonId = [[_lesson objectForKey:@"id"] intValue];
    NSString *selectSql = [NSString stringWithFormat:@"select `word_name`,`word_translation`,`lesson_id` from words where lesson_id=%d and book_id=%d order by order_id",lessonId,_bookId+1];
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
    }
    
    while (sqlite3_step(statement)==SQLITE_ROW) {
        NSMutableDictionary *item = [[NSMutableDictionary alloc] initWithCapacity:3];
        
        NSString *englishString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
        [item setObject:englishString forKey:@"english"];
        
        NSString *chineseString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 1) encoding:NSUTF8StringEncoding];
        [item setObject:chineseString forKey:@"chinese"];
        
        NSString *lessonId = [NSString stringWithFormat:@"%d",sqlite3_column_int(statement, 2)];
        [item setObject:lessonId forKey:@"lesson_id"];
        item[@"book_id"]=@(_bookId+1);
        
        [_items addObject:item];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
}

- (void)localizeLegacyIconButton:(UIButton *)button systemName:(NSString *)name
{
    if (![@[@"ja", @"ko"] containsObject:NCELocalization.sharedLocalization.languageCode]) return;
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:name withConfiguration:configuration];
    if (!image) return;
    [button setImage:image forState:UIControlStateNormal];
    [button setImage:image forState:UIControlStateHighlighted];
    button.tintColor = [UIColor colorWithRed:0.46 green:0.49 blue:0.56 alpha:1];
    if (@available(iOS 15.0, *)) {
        [button addInteraction:[[UIToolTipInteraction alloc] initWithDefaultToolTip:button.accessibilityLabel]];
    }
}

- (void)showWordInformation
{
    if(_currentIndex<0 || _currentIndex>=_items.count)return;
    NSDictionary *item=_items[_currentIndex];NSString *word=item[@"english"];
    UIButtonConfiguration *bookmarkConfig=_bookmark.configuration;bookmarkConfig.image=[UIImage systemImageNamed:[NCEStudyStore isBookmarked:item] ? @"bookmark.fill" : @"bookmark"];_bookmark.configuration=bookmarkConfig;_bookmark.accessibilityValue=NCELocalizedString([NCEStudyStore isBookmarked:item] ? @"已收藏" : @"未收藏");
    _englishLabel.text=_function==3 ? nil : [NCEWordResourceStore.sharedStore displayNameForWord:word];
    _chineseLabel.text=[NCEWordResourceStore.sharedStore translationForWord:word fallback:item[@"chinese"]];
    NSInteger resourceBookId=item[@"book_id"] ? [item[@"book_id"] integerValue] : _bookId+1;
    NSString *path=[NCEWordResourceStore.sharedStore imagePathForWord:word bookId:resourceBookId];
    NSString *hint=[NCEWordResourceStore.sharedStore visualHintForWord:word bookId:resourceBookId];
    _wordImageView.image=path ? [UIImage imageWithContentsOfFile:path] : nil;
    _wordVisualHint.text=hint;_wordVisualHint.hidden=!hint.length;
    _wordVisualCaption.text=[NCEWordResourceStore.sharedStore visualCaptionForWord:word bookId:resourceBookId];
    _wordVisualPresentation=[NCEWordResourceStore.sharedStore visualPresentationForWord:word bookId:resourceBookId];
    _wordImageView.backgroundColor=hint.length ? NCESky() : UIColor.clearColor;
    _wordImageView.layer.cornerRadius=hint.length ? 14 : 0;
    _wordImageView.accessibilityLabel=hint.length ? [NSString stringWithFormat:@"%@. %@",_chineseLabel.text,hint] : _chineseLabel.text;
    _wordImageView.hidden=_function==2;_chineseLabel.hidden=_function==2;
    _contextLabel.text=[NSString stringWithFormat:@"%@ · %@",[NSString stringWithFormat:NCELocalizedString(@"第%d册"),_bookId+1],[NSString stringWithFormat:NCELocalizedString(@"第%@课"),item[@"lesson_id"] ?: @""]];
    if(self.readingLookup)_contextLabel.text=[NSString stringWithFormat:NCELocalizedString(@"原文：%@"),self.readingSurfaceWord ?: word];
    _countLabel.text=[NSString stringWithFormat:@"%d / %lu",_currentIndex+1,(unsigned long)_items.count];
    _progress.progress=(float)(_currentIndex+1)/MAX(1,_items.count);
    _example=self.readingExample ?: [self exampleForWord:word lesson:item[@"lesson_id"]];
    _exampleLabel.text=_example[@"english"];
    _exampleTranslation.text=_example[@"translation"];
    _exampleView.hidden=!_example || _function==2 || _function==3;
    _masteryStatus=[self savedStatusForWord:word];[self updateMasteryButtons];
    _wordPrevious.enabled=_currentIndex>0;
    [_wordScroll setContentOffset:CGPointZero animated:NO];
    [self.view setNeedsLayout];
    [_audioPlayer stop];_audioPlayer=nil;
    NSString *soundPath=[NCEWordResourceStore.sharedStore audioPathForWord:word];
    if(soundPath){_audioPlayer=[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath] error:nil];_audioPlayer.delegate=self;if(!self.readingLookup)[_audioPlayer play];}
    _continueButton.hidden=self.embeddedInLesson || _audioPlayer.isPlaying;_pauseButton.hidden=self.embeddedInLesson || !_audioPlayer.isPlaying;
    if(!soundPath && _currentIndex>=_items.count-1)[self handleWordSessionCompletionIfNeeded];
}


- (void)addBottomView:(CGFloat)startPosy
{
    _controlsView=[UIView new];_controlsView.backgroundColor=NCEBackground();[self.view addSubview:_controlsView];
    _controlsSeparator=[UIView new];_controlsSeparator.backgroundColor=NCELine();[_controlsView addSubview:_controlsSeparator];
    [_controlsView addSubview:_countLabel];_countLabel.textAlignment=NSTextAlignmentCenter;
    _masteryPrompt=NCELabel(NCELocalizedString(@"这个单词，你掌握得怎么样？"),12,UIFontWeightRegular,NCEMuted());_masteryPrompt.textAlignment=NSTextAlignmentCenter;[_controlsView addSubview:_masteryPrompt];
    NSMutableArray *buttons=[NSMutableArray new];
    NSArray *labels=@[@"陌生",@"待复习",@"熟悉"],*identifiers=@[@"word-strange",@"word-vague",@"word-familiar"],*tags=@[@101,@103,@102];
    for(NSInteger i=0;i<3;i++){
        UIButton *button=NCEButton(NCELocalizedString(labels[i]),nil,NO,self,@selector(signWord:));button.tag=[tags[i] integerValue];button.accessibilityIdentifier=identifiers[i];button.accessibilityLabel=NCELocalizedString(@[@"标记陌生",@"标记待复习",@"标记熟悉"][i]);
        [_controlsView addSubview:button];[buttons addObject:button];
    }_masteryButtons=buttons.copy;
    _wordPrevious=NCEButton(nil,@"backward.end",NO,self,@selector(prev));_wordPrevious.accessibilityIdentifier=@"word-prev";_wordPrevious.accessibilityLabel=NCELocalizedString(@"上一个单词");
    _pauseButton=NCEButton(nil,@"pause.fill",YES,self,@selector(pause));_pauseButton.accessibilityIdentifier=@"word-pause";_pauseButton.accessibilityLabel=NCELocalizedString(@"暂停");
    _continueButton=NCEButton(nil,@"play.fill",YES,self,@selector(continue));_continueButton.accessibilityIdentifier=@"word-play";_continueButton.accessibilityLabel=NCELocalizedString(@"播放");
    _wordNext=NCEButton(nil,@"forward.end",NO,self,@selector(next));_wordNext.accessibilityIdentifier=@"word-next";_wordNext.accessibilityLabel=NCELocalizedString(@"下一个单词");
    for(UIView *view in @[_wordPrevious,_pauseButton,_continueButton,_wordNext])[_controlsView addSubview:view];
}


- (void)prev
{
    [self willShowWordInformation];
    
    if (_currentIndex > 0) {
        _currentIndex --;
        [self showWordInformation];
    } else {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        
        // Configure for text only and offset down
        hud.mode = MBProgressHUDModeText;
        hud.label.text = NCELocalizedString(@"已是第一个");
        hud.removeFromSuperViewOnHide = YES;
        
        [hud hideAnimated:YES afterDelay:0.75f];
    }
}

- (void)pause
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
    
    _pauseButton.hidden = YES;
    _continueButton.hidden = self.embeddedInLesson;
    
    [_audioPlayer pause];
}

- (void)continue
{
    if(self.readingLookup){[self repeat];return;}
    [self willShowWordInformation];
    
    [_audioPlayer play];
}

- (void)next
{
    [self willShowWordInformation];
    
    if (_currentIndex < _items.count - 1) {
        _currentIndex++;
        [self showWordInformation];
    } else {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        
        // Configure for text only and offset down
        hud.mode = MBProgressHUDModeText;
        hud.label.text = NCELocalizedString(@"已是最后一个");
        hud.removeFromSuperViewOnHide = YES;
        
        [hud hideAnimated:YES afterDelay:0.75f];
    }
}

- (void)willShowWordInformation
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
    _continueButton.hidden = YES;
    _pauseButton.hidden = self.embeddedInLesson;
}

- (void)handleWordSessionCompletionIfNeeded
{
    if(self.readingLookup)return;
    if (_didHandleCompletionBreak || _currentIndex < _items.count-1) {
        return;
    }
    _didHandleCompletionBreak = YES;
    [[AdmobManager sharedInstance] handleCompletedWordBreakWithCompletion:nil];
}

- (void)signWord:(id)sender
{
    if (_currentIndex < 0 || _currentIndex >= _items.count) return;
    UIButton *button = (UIButton *)sender;
    int status = (int)button.tag-100;
    
    sqlite3 *database;
    //    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    NSString *dbPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"NCE.db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //        NSLog(@"ok");
    }
    
    sqlite3_stmt *statement = NULL;
    if (sqlite3_prepare_v2(database, "UPDATE words SET word_status=? WHERE word_name=? AND book_id=?", -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_int(statement, 1, status);
        sqlite3_bind_text(statement, 2, [_items[_currentIndex][@"english"] UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(statement,3,_bookId+1);
        if(sqlite3_step(statement)==SQLITE_DONE){_masteryStatus=status;[self updateMasteryButtons];}
    }
    sqlite3_finalize(statement);sqlite3_close(database);
}

- (void)showEnglish
{
    _englishLabel.text=_englishLabel.text.length ? nil : [NCEWordResourceStore.sharedStore displayNameForWord:_items[_currentIndex][@"english"]];
    _exampleView.hidden=!_example || !_englishLabel.text.length;
    [self.view setNeedsLayout];
}


- (void)showChinese
{
    _chineseLabel.hidden=!_chineseLabel.hidden;_wordImageView.hidden=_chineseLabel.hidden;
    _exampleView.hidden=!_example || _chineseLabel.hidden;
    [self.view setNeedsLayout];
}


- (void)repeat
{
    if (_currentIndex < 0 || _currentIndex >= _items.count) return;
    [self willShowWordInformation];
    
    NSString *soundPath = [[NCEWordResourceStore sharedStore] audioPathForWord:_items[_currentIndex][@"english"]];
    
    if (soundPath) {
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath] error:nil];
        _audioPlayer.delegate = self;
        [_audioPlayer play];
    }
}

- (void)showOnlineDictionarys
{
    [self pause];
    
    CKAlertView *alertView = [[CKAlertView alloc] initWithTitle:NCELocalizedString(@"在线词典")
                                                        message:nil
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:NCELocalizedString(@"有道在线词典"), NCELocalizedString(@"爱词霸在线词典"), NCELocalizedString(@"百度在线词典"), NCELocalizedString(@"海词在线词典"), nil];
    [alertView show];
}

- (void)layoutAcademyViews
{
    CGRect frame=[self academyContentFrame];
    CGFloat width=frame.size.width;
    if(width>600 && !UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory)) {
        CGFloat height=MIN(820,frame.size.height); frame.origin.y+=(frame.size.height-height)/2; frame.size.height=height;
    }
    _bookmark.frame=CGRectMake(CGRectGetMaxX(frame)-64,frame.origin.y,44,44);
    if(self.embeddedInLesson){_contextLabel.text=NCELocalizedString(@"本课单词");_contextLabel.textAlignment=NSTextAlignmentLeft;}
    _contextLabel.textAlignment=NSTextAlignmentCenter;
    CGFloat contextHeight=self.embeddedInLesson ? 32 : MAX(24,NCETextHeight(_contextLabel.text,_contextLabel.font,width-40));
    _contextLabel.frame=CGRectMake(frame.origin.x+20,frame.origin.y+4,width-40,contextHeight);
    _progress.hidden=YES; _masteryPrompt.hidden=YES;
    BOOL flowing=UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) || frame.size.height<400;
    UIView *controlParent=flowing ? _wordScroll : self.view;
    if(_controlsView.superview!=controlParent)[controlParent addSubview:_controlsView];
    CGFloat cw=width-40, bw=(cw-16)/3, masteryHeight=44;
    for(UIButton *button in _masteryButtons) masteryHeight=MAX(masteryHeight,NCETextHeight(button.configuration.title,NCEFont(15,UIFontWeightSemibold),bw-28)+20);
    CGFloat countHeight=MAX(20,NCETextHeight(_countLabel.text,_countLabel.font,cw));
    CGFloat controlHeight=self.embeddedInLesson ? masteryHeight+120 : masteryHeight+76+countHeight;
    _controlsView.frame=CGRectMake(frame.origin.x+20,CGRectGetMaxY(frame)-controlHeight,cw,controlHeight);
    for(NSInteger i=0;i<3;i++)_masteryButtons[i].frame=CGRectMake(i*(bw+8),0,bw,masteryHeight);
    CGFloat y=masteryHeight+20;
    _controlsSeparator.frame=CGRectMake(0,masteryHeight+10,cw,0.5);
    _wordPrevious.frame=CGRectMake(cw/2-116,y+4,44,44);
    _continueButton.frame=_pauseButton.frame=CGRectMake(cw/2-26,y,52,52);
    _wordNext.frame=CGRectMake(cw/2+72,y+4,44,44);
    _countLabel.frame=CGRectMake(0,y+56,cw,countHeight);
    _wordPrevious.hidden=self.readingLookup;_wordNext.hidden=self.readingLookup;_countLabel.hidden=self.readingLookup;
    if(self.embeddedInLesson){
        _contextLabel.textAlignment=NSTextAlignmentLeft;_contextLabel.frame=CGRectMake(frame.origin.x+24,frame.origin.y+4,width-124,26);
        _countLabel.textAlignment=NSTextAlignmentRight;_countLabel.frame=CGRectMake(CGRectGetMaxX(frame)-104,frame.origin.y+4,80,26);
        _wordList.frame=_continueButton.frame;_continueButton.hidden=YES;_pauseButton.hidden=YES;
        _practiceButton.frame=CGRectMake(0,y+56,cw,48);
    }
    CGFloat scrollTop=frame.origin.y+contextHeight+10;
    _wordScroll.frame=CGRectMake(frame.origin.x,scrollTop,width,MAX(0,CGRectGetMinY(_controlsView.frame)-scrollTop-8));
    CGFloat inner=width-48, art=self.embeddedInLesson ? 96 : (frame.size.height<600 ? 112 : 180);
    if(width>600)art=210;
    CGFloat contentY=8;
    if(_wordVisualPresentation.length)art=MIN(inner,self.embeddedInLesson ? 160 : 200);
    CGFloat visualWidth=art,visualHeight=art;
    if(_wordVisualHint.text.length){
        visualWidth=MIN(inner,340);
        visualHeight=MAX(96,NCETextHeight(_wordVisualHint.text,_wordVisualHint.font,visualWidth-32)+32);
    }
    _wordImageView.frame=CGRectMake((width-visualWidth)/2,contentY,visualWidth,visualHeight);
    _wordVisualHint.frame=CGRectInset(_wordImageView.bounds,16,16);
    if(!_wordImageView.hidden)contentY+=visualHeight+14;
    _wordVisualCaption.hidden=_wordImageView.hidden || !_wordVisualCaption.text.length;
    if(!_wordVisualCaption.hidden){
        CGFloat captionHeight=NCETextHeight(_wordVisualCaption.text,_wordVisualCaption.font,inner);
        _wordVisualCaption.frame=CGRectMake(24,contentY,inner,captionHeight);contentY+=captionHeight+14;
    }
    NSString *word=_englishLabel.text ?: @"";
    BOOL singleLine=!UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) && [word rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location==NSNotFound;
    _englishLabel.numberOfLines=singleLine ? 1 : 0;
    _englishLabel.adjustsFontSizeToFitWidth=singleLine; _englishLabel.minimumScaleFactor=0.62;
    CGFloat wordWidth=inner-50;
    CGFloat textWidth=MIN(wordWidth,ceil([word sizeWithAttributes:@{NSFontAttributeName:_englishLabel.font}].width));
    if(!singleLine)textWidth=wordWidth;
    CGFloat wordHeight=MAX(44,singleLine ? _englishLabel.font.lineHeight : NCETextHeight(word,_englishLabel.font,wordWidth));
    CGFloat titleX=self.embeddedInLesson ? 24 : (width-textWidth-48)/2;
    _englishLabel.frame=CGRectMake(titleX,contentY,textWidth,wordHeight);
    _repeatButton.frame=CGRectMake(MIN(width-112,CGRectGetMaxX(_englishLabel.frame)+4),contentY+(wordHeight-44)/2,44,44);
    if(self.embeddedInLesson){_englishLabel.textAlignment=NSTextAlignmentLeft;_englishLabel.frame=CGRectMake(24,contentY,MIN(textWidth,width-148),wordHeight);_bookmark.frame=CGRectMake(width-64,contentY+(wordHeight-44)/2,44,44);_chineseLabel.textAlignment=NSTextAlignmentLeft;}
    contentY+=wordHeight+6;
    CGFloat translationHeight=_chineseLabel.hidden ? 0 : NCETextHeight(_chineseLabel.text,_chineseLabel.font,inner);
    _chineseView.frame=CGRectMake(24,contentY,inner,translationHeight); _chineseLabel.frame=_chineseView.bounds;
    contentY+=translationHeight;
    if(_revealButton) {
        CGFloat height=MAX(44,NCETextHeight(_revealButton.configuration.title,NCEFont(15,UIFontWeightSemibold),inner-48)+20);
        _revealButton.frame=CGRectMake(24,contentY+12,inner,height); contentY=CGRectGetMaxY(_revealButton.frame);
    }
    if(!_exampleView.hidden) {
        CGFloat top=contentY+24, localY=14;
        _exampleDivider.frame=CGRectMake(0,0,inner,0.5);
        for(UILabel *label in @[_exampleTitle,_exampleLabel,_exampleTranslation]) {
            CGFloat height=NCETextHeight(label.text,label.font,inner);
            label.frame=CGRectMake(0,localY,inner,height); localY+=height+6;
        }
        _exampleView.frame=CGRectMake(24,top,inner,localY); contentY=CGRectGetMaxY(_exampleView.frame);
    }
    _wordCard.frame=CGRectMake(0,0,width,contentY+12);
    _wordScroll.contentSize=CGSizeMake(width,contentY+20);
    if(flowing) {
        _wordScroll.frame=CGRectMake(frame.origin.x,scrollTop,width,MAX(0,CGRectGetMaxY(frame)-scrollTop));
        _controlsView.frame=CGRectMake(20,contentY+24,cw,controlHeight);
        _wordScroll.contentSize=CGSizeMake(width,CGRectGetMaxY(_controlsView.frame)+12);
    }
}
- (void)openPractice {if([self.parentViewController isKindOfClass:NCECourseViewController.class])[(NCECourseViewController *)self.parentViewController showSection:2];}
- (void)showWordList {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:NCELocalizedString(@"本课单词") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSUInteger i=0;i<_items.count;i++){NSDictionary *word=_items[i];[sheet addAction:[UIAlertAction actionWithTitle:[NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){self->_currentIndex=(int)i;[self showWordInformation];}]];}
    [sheet addAction:[UIAlertAction actionWithTitle:NCELocalizedString(@"取消") style:UIAlertActionStyleCancel handler:nil]];sheet.popoverPresentationController.sourceView=_wordList;sheet.popoverPresentationController.sourceRect=_wordList.bounds;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)toggleBookmark {if(_currentIndex>=_items.count)return;[NCEStudyStore toggleBookmark:_items[_currentIndex]];UIButtonConfiguration *config=_bookmark.configuration;BOOL marked=[NCEStudyStore isBookmarked:_items[_currentIndex]];config.image=[UIImage systemImageNamed:marked ? @"bookmark.fill" : @"bookmark"];_bookmark.configuration=config;_bookmark.accessibilityValue=NCELocalizedString(marked ? @"已收藏" : @"未收藏");}
- (NSInteger)savedStatusForWord:(NSString *)word
{
    sqlite3 *db=NULL;sqlite3_stmt *stmt=NULL;NSInteger status=0;
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/NCE.db"];
    if(sqlite3_open_v2(path.UTF8String,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK && sqlite3_prepare_v2(db,"SELECT word_status FROM words WHERE word_name=? AND book_id=? LIMIT 1",-1,&stmt,NULL)==SQLITE_OK){
        sqlite3_bind_text(stmt,1,word.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int(stmt,2,_bookId+1);if(sqlite3_step(stmt)==SQLITE_ROW)status=sqlite3_column_int(stmt,0);
    }sqlite3_finalize(stmt);if(db)sqlite3_close(db);return status;
}
- (void)updateMasteryButtons
{
    for(UIButton *button in _masteryButtons){
        BOOL selected=button.tag-100==_masteryStatus;button.selected=selected;
        UIButtonConfiguration *config=button.configuration;config.background.backgroundColor=selected ? NCESky() : NCESurface();
        config.background.strokeColor=selected ? NCEBlue() : NCELine();config.background.strokeWidth=selected ? 1.5 : 0.5;
        config.image=selected ? [UIImage systemImageNamed:@"checkmark"] : nil;config.contentInsets=NSDirectionalEdgeInsetsMake(8,6,8,6);button.configuration=config;
        button.accessibilityValue=selected ? NCELocalizedString(@"已选择") : @"";
    }
}
- (NSDictionary *)exampleForWord:(NSString *)word lesson:(NSString *)lesson
{
    if(!lesson.length)return nil;
    sqlite3 *db=NULL;sqlite3_stmt *stmt=NULL;NSDictionary *example=nil;
    NSString *path=[NSBundle.mainBundle pathForResource:@"data/NCE" ofType:@"db"];
    if(sqlite3_open_v2(path.UTF8String,&db,SQLITE_OPEN_READONLY,NULL)==SQLITE_OK && sqlite3_prepare_v2(db,"SELECT name FROM play_list_sentences WHERE book_id=? AND lesson_id=? ORDER BY order_id",-1,&stmt,NULL)==SQLITE_OK){
        sqlite3_bind_int(stmt,1,_bookId+1);sqlite3_bind_int(stmt,2,lesson.intValue);
        NSString *pattern=[NSString stringWithFormat:@"(?i)\\b%@\\b",[NSRegularExpression escapedPatternForString:word]];
        NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        while(sqlite3_step(stmt)==SQLITE_ROW){
            NSString *name=@((const char *)sqlite3_column_text(stmt,0));
            NSString *text=[NCELessonResourceStore.sharedStore textForSentence:name bookID:_bookId+1 error:nil];NSArray *parts=[text componentsSeparatedByString:@"－"];
            if(parts.count<2 || [parts[0] length]>240)continue;
            if([regex firstMatchInString:parts[0] options:0 range:NSMakeRange(0,[parts[0] length])]) {
                NSMutableCharacterSet *trim=[NSCharacterSet.whitespaceAndNewlineCharacterSet mutableCopy];
                [trim addCharactersInString:@"\uFEFF"];
                NSString *translation=[NCELocalization.sharedLocalization localizedLessonText:name fallback:parts[1]];
                example=@{@"english":[parts[0] stringByTrimmingCharactersInSet:trim],@"translation":[translation stringByTrimmingCharactersInSet:trim]};
                break;
            }
        }
    }sqlite3_finalize(stmt);if(db)sqlite3_close(db);return example;
}

@end

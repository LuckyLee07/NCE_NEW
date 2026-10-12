//
//  TextViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "TextViewController.h"
#import "sqlite3.h"
#import "AdmobManager.h"
#import "NCEStudyStore.h"
#import "NCEStudyViews.h"
#import "NCECourseViewController.h"
#import "NCELessonResourceStore.h"
#import <AVFoundation/AVFoundation.h>

static NSString* const kTextViewControllerCellReuseId = @"kTextViewControllerCellReuseId";

@interface TextViewController () <UITableViewDataSource, UITableViewDelegate, AVAudioPlayerDelegate, UIAlertViewDelegate>
{
    int _bookId;
    NSMutableArray *_items;
    NSDictionary *_lesson;
    
    BOOL _showChinese;
    
	    NSMutableDictionary *_contentDictionary;
	    
	    AVAudioPlayer *_audioPlayer;
    NSUInteger _audioGeneration;
    BOOL _preparingAudio;
	    int _currentIndex;
    
    UIButton *_continueButton;
    UIButton *_pauseButton;
    
    UISlider *_contentSlider;
    UIButton *_circleButton;
    UIView *_playerView;
    UIView *_playerSeparator;
    UILabel *_positionLabel;
    UIButton *_rateButton;
    UIButton *_previousButton;
    UIButton *_nextButton;
    CGFloat _readingWidth;
    float _playbackRate;
    UIButton *_translationButton;
}

@property (nonatomic, strong) UITableView *tableView;

//@property (nonatomic, strong) GADInterstitial *interstitial;
//@property (nonatomic, assign) NSInteger showTimes;

- (void)initData;
- (void)addTableView;
- (void)addRightButton;
- (void)showChinese:(UIButton *)button;
- (NSDictionary *)getContentItem:(NSUInteger)item;
- (NSDictionary *)nextLessonDictionary;
- (void)continueToNextLesson:(NSDictionary *)lesson;

@end

@implementation TextViewController

- (id)initWithBookId:(int)bookId withLesson:(NSDictionary *)lesson
{
    self = [super init];
    if (self) {
        _bookId = bookId;
        _lesson = lesson;
        
        NSArray *lessonArray = [[lesson objectForKey:@"name"] componentsSeparatedByString:@"－"];
        self.titleString = [NSString stringWithFormat:@"%@－%@",NCEChineseText(lessonArray[0]), lessonArray[1]];
        
        [self initData];
        
        _showChinese = YES;
        
        _contentDictionary = [[NSMutableDictionary alloc] initWithCapacity:5];
        
	        _currentIndex = 0;
        NSDictionary *resume=[NCEStudyStore resumeForBook:bookId];
        if ([resume[@"book"] intValue]==_bookId && [resume[@"lesson"][@"id"] isEqual:_lesson[@"id"]]) _currentIndex=MIN(MAX(0,[resume[@"sentence"] intValue]),MAX(0,(int)_items.count-1));
        _playbackRate=[NSUserDefaults.standardUserDefaults floatForKey:@"NCEAcademyRate"];
        if (_playbackRate<0.5 || _playbackRate>2) _playbackRate=1;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self addTableView]; [self addRightButton]; [self addBottomView];
    if (_items.count) [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:_currentIndex inSection:0]];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:kTextViewControllerCellReuseId forIndexPath:indexPath];
    for(UIView *view in cell.contentView.subviews) [view removeFromSuperview];
    cell.backgroundColor=UIColor.clearColor;cell.selectionStyle=UITableViewCellSelectionStyleNone;
    NSDictionary *item=[self getContentItem:indexPath.row];
    CGFloat width=tableView.bounds.size.width;
    CGFloat height=[self tableView:tableView heightForRowAtIndexPath:indexPath];
    BOOL current=indexPath.row==_currentIndex;
    if(current) {
        UIView *highlight=[[UIView alloc] initWithFrame:CGRectMake(12,2,width-24,height-4)];
        highlight.backgroundColor=NCESky(); highlight.layer.cornerRadius=4; [cell.contentView addSubview:highlight];
        UIView *marker=[[UIView alloc] initWithFrame:CGRectMake(12,5,3,height-10)]; marker.backgroundColor=NCEBlue(); [cell.contentView addSubview:marker];
        UIImageView *speaker=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"speaker.wave.2"]];
        speaker.tintColor=NCEBlue(); speaker.contentMode=UIViewContentModeScaleAspectFit;
        speaker.frame=CGRectMake(width-42,10,22,24); [cell.contentView addSubview:speaker];
    }
    UILabel *english=NCELabel(item[@"english"],19,UIFontWeightMedium,NCEInk());
    english.frame=CGRectMake(24,10,width-76,[item[@"englishHeight"] floatValue]);
    english.accessibilityIdentifier=[NSString stringWithFormat:@"lesson-english-%ld",(long)indexPath.row];
    [cell.contentView addSubview:english];
    if(_showChinese){
        UILabel *translation=NCELabel(item[@"chinese"],13,UIFontWeightRegular,NCEMuted());
        translation.frame=CGRectMake(24,CGRectGetMaxY(english.frame)+5,width-76,[item[@"chineseHeight"] floatValue]);
        translation.accessibilityIdentifier=[NSString stringWithFormat:@"lesson-translation-%ld",(long)indexPath.row];
        [cell.contentView addSubview:translation];
    }
    return cell;
}


#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item=[self getContentItem:indexPath.row];
    return MAX(44,20+[item[@"englishHeight"] floatValue]+(_showChinese ? 5+[item[@"chineseHeight"] floatValue] : 0));
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(indexPath.row>=_items.count)return;
    _currentIndex=(int)indexPath.row;
    [NCEStudyStore recordLesson:_lesson book:_bookId sentence:_currentIndex];
    [NSUserDefaults.standardUserDefaults setInteger:_bookId forKey:@"NCEAcademyBook"];
    [self play];
    [tableView reloadData];
    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:!UIAccessibilityIsReduceMotionEnabled()];
    _contentSlider.value=_currentIndex;
    _positionLabel.text=[NSString stringWithFormat:@"%d / %d",_currentIndex+1,(int)_items.count];
    _previousButton.enabled=_currentIndex>0;_nextButton.enabled=_currentIndex<_items.count-1;
    _continueButton.hidden=_audioPlayer.isPlaying;_pauseButton.hidden=!_audioPlayer.isPlaying;
}


#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (_circleButton.selected) { [self play]; return; }
    
    if (_currentIndex < _items.count-1) {
        _currentIndex++;
        NSIndexPath *next = [NSIndexPath indexPathForRow:_currentIndex inSection:0];
        [self tableView:self.tableView didSelectRowAtIndexPath:next];
        return;
    }

    [self pause];
    if(self.embeddedInLesson){[[AdmobManager sharedInstance] handleCompletedCourseBreakWithCompletion:nil];return;}
    NSDictionary *nextLesson = [self nextLessonDictionary];
    __weak typeof(self) weakSelf = self;
    [[AdmobManager sharedInstance] handleCompletedCourseBreakWithCompletion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !nextLesson) {
            return;
        }
        [strongSelf continueToNextLesson:nextLesson];
    }];
}

#pragma mark -
#pragma mark Private Methods

- (void)initData
{
    _items = [[NSMutableArray alloc] init];
    
    sqlite3 *database;
    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //                NSLog(@"ok");
    }
    
    int lessonId = [[_lesson objectForKey:@"id"] intValue];
    NSString *selectSql = [NSString stringWithFormat:@"select `name` from play_list_sentences where lesson_id=%d and book_id=%d order by order_id",lessonId,_bookId+1];
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //                NSLog(@"select ok.");
    }
    
    while (sqlite3_step(statement)==SQLITE_ROW) {
        NSString *nameString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
        
        [_items addObject:nameString];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
}

- (void)addTableView
{
    self.viewType=ViewType_Lessons;
    self.tableView=[[UITableView alloc] initWithFrame:[self getTableViewFrame] style:UITableViewStylePlain];
    self.tableView.dataSource=self;self.tableView.delegate=self;NCEPrepareTable(self.tableView);
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kTextViewControllerCellReuseId];
    [self.view addSubview:self.tableView];[self updateReadingHeader];
}


- (void)addRightButton
{
    UIButton *translation=NCEButton(self.embeddedInLesson ? NCELocalizedString(@"显示译文") : nil,@"text.bubble",NO,self,@selector(showChinese:));
    _translationButton=translation;
    translation.frame=CGRectMake(0,0,44,44);translation.accessibilityIdentifier=@"lesson-show-translation";
    translation.accessibilityLabel=NCELocalizedString(@"显示或隐藏译文");translation.accessibilityValue=NCELocalizedString(@"中英对照");
    if(self.embeddedInLesson){[self.view addSubview:translation];return;}
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:translation];
    if (@available(iOS 26.0, *)) self.navigationItem.rightBarButtonItem.hidesSharedBackground=YES;
}


- (void)showChinese:(UIButton *)button;
{
    button.selected = !button.selected;
    _showChinese = !_showChinese;
    button.accessibilityValue=NCELocalizedString(_showChinese ? @"中英对照" : @"仅英文");
    if(self.embeddedInLesson)NCESetButtonTitle(button,NCELocalizedString(_showChinese ? @"隐藏译文" : @"显示译文"));
    [self.tableView reloadData];
}

- (NSDictionary *)getContentItem:(NSUInteger)item
{
    NSString *name=_items[item];
    NSDictionary *cached=_contentDictionary[name];
    if(!cached){
        NSString *text=[[NCELessonResourceStore.sharedStore textForSentence:name bookID:_bookId+1 error:nil] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSArray *parts=[text componentsSeparatedByString:@"－"];
        NSString *english=parts.count>0 ? parts[0] : @"";
        NSString *translation=parts.count>1 ? [NCELocalization.sharedLocalization localizedLessonText:name fallback:parts[1]] : NCELocalizedString(@"课文资源无法读取");
        // Some bundled LRC files end with a blank line containing a BOM.
        NSMutableCharacterSet *whitespace=[NSCharacterSet.whitespaceAndNewlineCharacterSet mutableCopy];
        [whitespace addCharactersInString:@"\uFEFF"];
        cached=@{@"english":[english stringByTrimmingCharactersInSet:whitespace],@"chinese":[translation stringByTrimmingCharactersInSet:whitespace]};
        _contentDictionary[name]=cached;
    }
    CGFloat width=self.tableView.bounds.size.width-76;
    NSMutableDictionary *result=cached.mutableCopy;
    result[@"englishHeight"]=@(NCETextHeight(cached[@"english"],NCEFont(19,UIFontWeightMedium),width));
    result[@"chineseHeight"]=@(NCETextHeight(cached[@"chinese"],NCEFont(13,UIFontWeightRegular),width));
    return result;
}


- (NSDictionary *)nextLessonDictionary
{
    NSString *currentLessonID = [_lesson objectForKey:@"id"];
    if (currentLessonID.length == 0) {
        return nil;
    }

    sqlite3 *database;
    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    if (sqlite3_open([dbPath UTF8String], &database) != SQLITE_OK) {
        return nil;
    }

    NSString *selectSql = [NSString stringWithFormat:@"select `name`,`lesson_id` from play_list_lessons where book_id=%d order by order_id", _bookId + 1];
    sqlite3_stmt *statement = nil;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil) != SQLITE_OK) {
        sqlite3_close(database);
        return nil;
    }

    NSDictionary *nextLesson = nil;
    BOOL foundCurrent = NO;
    while (sqlite3_step(statement) == SQLITE_ROW) {
        const char *nameC = (const char *)sqlite3_column_text(statement, 0);
        const char *lessonIDC = (const char *)sqlite3_column_text(statement, 1);
        if (!lessonIDC) {
            continue;
        }

        NSString *lessonID = [[NSString alloc] initWithCString:lessonIDC encoding:NSUTF8StringEncoding];
        if (foundCurrent) {
            NSString *name = nameC ? [[NSString alloc] initWithCString:nameC encoding:NSUTF8StringEncoding] : @"";
            nextLesson = @{@"name": name ?: @"", @"id": lessonID ?: @""};
            break;
        }

        if ([lessonID isEqualToString:currentLessonID]) {
            foundCurrent = YES;
        }
    }

    sqlite3_finalize(statement);
    sqlite3_close(database);
    return nextLesson;
}

- (void)continueToNextLesson:(NSDictionary *)lesson
{
    _lesson = lesson;
    NSArray *lessonArray = [[lesson objectForKey:@"name"] componentsSeparatedByString:@"－"];
    if (lessonArray.count > 1) {
        self.titleString = [NSString stringWithFormat:@"%@－%@", NCEChineseText(lessonArray[0]), lessonArray[1]];
    } else {
        self.titleString = [lesson objectForKey:@"name"];
    }
    self.navigationItem.title = NCEChineseText(self.titleString);
    [self updateReadingHeader];

    [self initData];
    [_contentDictionary removeAllObjects];

    _currentIndex = 0;
    _contentSlider.maximumValue = MAX(0, (int)_items.count - 1);
    _contentSlider.value = 0.0f;

    [self.tableView reloadData];
    if (_items.count > 0) {
        NSIndexPath *first = [NSIndexPath indexPathForRow:0 inSection:0];
        [self tableView:self.tableView didSelectRowAtIndexPath:first];
    }
}

- (void)setAudioLoadingVisible:(BOOL)visible
{
    UIButtonConfiguration *configuration=_continueButton.configuration;
    configuration.showsActivityIndicator=visible;_continueButton.configuration=configuration;
    _continueButton.enabled=!visible;
    _continueButton.accessibilityLabel=NCELocalizedString(visible ? @"正在准备音频…" : @"播放课文");
}

- (void)play
{
    if (_currentIndex < 0 || _currentIndex >= _items.count) return;
    [_audioPlayer stop];_audioPlayer=nil;
    NSUInteger generation=++_audioGeneration;_preparingAudio=YES;
    [self setAudioLoadingVisible:NO];_continueButton.hidden=NO;_pauseButton.hidden=YES;
    NSString *sentence=[_items[_currentIndex] copy];NSInteger book=_bookId+1;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        typeof(self) self=weakSelf;
        if(self && self->_audioGeneration==generation && self->_preparingAudio)[self setAudioLoadingVisible:YES];
    });
    NSTimeInterval preparationDelay=0;
#if DEBUG
    if([AdmobManager isOfflineResourceQA] && [NSProcessInfo.processInfo.arguments containsObject:@"-NCEAudioPreparationPreview"])preparationDelay=4;
#endif
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(preparationDelay*NSEC_PER_SEC)),dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSError *error=nil;
        NSData *data=[NCELessonResourceStore.sharedStore audioDataForSentence:sentence bookID:book error:&error];
        AVAudioPlayer *player=data ? [[AVAudioPlayer alloc] initWithData:data error:&error] : nil;
        BOOL ready=player && [player prepareToPlay];
        dispatch_async(dispatch_get_main_queue(),^{
            typeof(self) self=weakSelf;
            // A newer sentence, pause, or leaving the reader invalidates this completion.
            if(!self || self->_audioGeneration!=generation)return;
            self->_preparingAudio=NO;[self setAudioLoadingVisible:NO];
            if(!ready) {
                NSLog(@"Unable to prepare lesson audio: %@",error);
                if(self.view.window && !self.presentedViewController) {
                    UIAlertController *alert=[UIAlertController alertControllerWithTitle:NCELocalizedString(@"音频无法播放") message:NCELocalizedString(@"内置音频资源无法读取，请尝试重新打开课程。") preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:NCELocalizedString(@"确定") style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                return;
            }
            self->_audioPlayer=player;player.delegate=self;player.enableRate=YES;player.rate=self->_playbackRate;
            BOOL playing=[player play];self->_continueButton.hidden=playing;self->_pauseButton.hidden=!playing;
        });
    });
}

- (void)addBottomView
{
    _playerView=[UIView new];_playerView.backgroundColor=NCEBackground();[self.view addSubview:_playerView];
    _playerSeparator=[UIView new];_playerSeparator.backgroundColor=NCELine();[_playerView addSubview:_playerSeparator];
    _contentSlider=[UISlider new];_contentSlider.minimumValue=0;_contentSlider.maximumValue=MAX(0,(int)_items.count-1);_contentSlider.minimumTrackTintColor=NCEBlue();_contentSlider.maximumTrackTintColor=NCESky();
    _contentSlider.accessibilityIdentifier=@"lesson-progress";_contentSlider.accessibilityLabel=NCELocalizedString(@"课文进度");
    [_contentSlider addTarget:self action:@selector(gotoContentItem:) forControlEvents:UIControlEventValueChanged];[_playerView addSubview:_contentSlider];
    _positionLabel=NCELabel(nil,11,UIFontWeightMedium,NCEMuted());[_playerView addSubview:_positionLabel];
    _circleButton=NCEButton(nil,@"repeat",NO,self,@selector(circleOrSingle:));_circleButton.accessibilityLabel=NCELocalizedString(@"顺序播放");_circleButton.accessibilityIdentifier=@"lesson-repeat-mode";
    _previousButton=NCEButton(nil,@"backward.end",NO,self,@selector(prev));_previousButton.accessibilityIdentifier=@"lesson-prev";_previousButton.accessibilityLabel=NCELocalizedString(@"上一句");
    _continueButton=NCEButton(nil,@"play.fill",YES,self,@selector(continue));_continueButton.accessibilityIdentifier=@"lesson-play";_continueButton.accessibilityLabel=NCELocalizedString(@"播放课文");
    _pauseButton=NCEButton(nil,@"pause.fill",YES,self,@selector(pause));_pauseButton.accessibilityIdentifier=@"lesson-pause";_pauseButton.accessibilityLabel=NCELocalizedString(@"暂停课文");
    _nextButton=NCEButton(nil,@"forward.end",NO,self,@selector(next));_nextButton.accessibilityIdentifier=@"lesson-next";_nextButton.accessibilityLabel=NCELocalizedString(@"下一句");
    _rateButton=NCEButton([NSString stringWithFormat:@"%g×",_playbackRate],nil,NO,self,@selector(changeRate));_rateButton.accessibilityLabel=NCELocalizedString(@"播放速度");_rateButton.accessibilityIdentifier=@"lesson-rate";
    _rateButton.titleLabel.numberOfLines=1;_rateButton.titleLabel.adjustsFontSizeToFitWidth=YES;_rateButton.titleLabel.minimumScaleFactor=0.5;
    UIButtonConfiguration *rateConfig=_rateButton.configuration;rateConfig.background.backgroundColor=UIColor.clearColor;_rateButton.configuration=rateConfig;
    for(UIButton *button in @[_circleButton,_previousButton,_continueButton,_pauseButton,_nextButton,_rateButton]){
        UIButtonConfiguration *c=button.configuration;c.contentInsets=NSDirectionalEdgeInsetsMake(6,6,6,6);button.configuration=c;[_playerView addSubview:button];
    }
}


-(UIImage *)OriginImage:(UIImage *)image scaleToSize:(CGSize)size
{
    UIGraphicsBeginImageContext(size);
    
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

- (void)prev
{
    if (_currentIndex > 0) {
        NSIndexPath *last = [NSIndexPath indexPathForRow:_currentIndex-1 inSection:0];
        [self tableView:self.tableView didSelectRowAtIndexPath:last];
    }
}

- (void)pause
{
    ++_audioGeneration;_preparingAudio=NO;[self setAudioLoadingVisible:NO];
    _pauseButton.hidden = YES;
    _continueButton.hidden = NO;
    
    [_audioPlayer pause];
}

- (void)continue
{
    if(_preparingAudio)return;
    if(!_audioPlayer){[self play];return;}
    BOOL playing = [_audioPlayer play];
    _continueButton.hidden = playing;
    _pauseButton.hidden = !playing;
}

- (void)next
{
    if (_currentIndex < _items.count - 1) {
        NSIndexPath *last = [NSIndexPath indexPathForRow:_currentIndex+1 inSection:0];
        [self tableView:self.tableView didSelectRowAtIndexPath:last];
    }
}

- (void)gotoContentItem:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    NSIndexPath *index = [NSIndexPath indexPathForRow:slider.value inSection:0];
    [self tableView:self.tableView didSelectRowAtIndexPath:index];
}

- (void)circleOrSingle:(UIButton *)button
{
    button.selected=!button.selected;
    UIButtonConfiguration *c=button.configuration;c.image=[UIImage systemImageNamed:button.selected ? @"repeat.1" : @"repeat"];button.configuration=c;
    button.accessibilityLabel=NCELocalizedString(button.selected ? @"单句循环" : @"顺序播放");
}


- (void)layoutAcademyViews
{
    CGRect frame=[self academyContentFrame];CGFloat width=frame.size.width-32;
    if(self.embeddedInLesson){_translationButton.frame=CGRectMake(frame.origin.x+16,frame.origin.y,width,36);_translationButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentTrailing;self.tableView.frame=CGRectMake(frame.origin.x,frame.origin.y+40,frame.size.width,MAX(0,frame.size.height-138));}
    _playerView.frame=CGRectMake(frame.origin.x+16,CGRectGetMaxY(frame)-94,width,90);
    _playerSeparator.frame=CGRectMake(0,0,width,0.5);
    _positionLabel.frame=CGRectMake(0,7,48,22);_positionLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _contentSlider.frame=CGRectMake(54,4,width-54,28);
    NSArray *buttons=@[_circleButton,_previousButton,_continueButton,_nextButton,_rateButton];
    NSArray *widths=@[@44,@44,@52,@44,@60];
    CGFloat gap=MAX(0,(width-244)/4), x=0;
    for(NSInteger index=0;index<buttons.count;index++) {
        CGFloat w=[widths[index] doubleValue];
        [buttons[index] setFrame:CGRectMake(x,index==2 ? 34 : 38,w,index==2 ? 52 : 44)]; x+=w+gap;
    }
    _pauseButton.frame=_continueButton.frame;
    if(fabs(_readingWidth-self.tableView.bounds.size.width)>0.5){_readingWidth=self.tableView.bounds.size.width;[self.tableView reloadData];}
}
- (CGFloat)getPlayViewHeight { return 98; }
- (void)updateReadingHeader
{
    NSArray *parts=[_lesson[@"name"] componentsSeparatedByString:@"－"];
    self.navigationItem.title=[NSString stringWithFormat:@"%@ · %@",[NSString stringWithFormat:NCELocalizedString(@"第%d册"),_bookId+1],parts.count ? NCEChineseText(parts[0]) : @""];
    if(self.embeddedInLesson){self.tableView.tableHeaderView=nil;return;}
    self.tableView.tableHeaderView=[[NCEAcademyHeader alloc] initWithEyebrow:@"" title:parts.count>1 ? parts[1] : @"" subtitle:parts.count>2 ? NCEChineseText(parts[2]) : @"" image:nil];
    [self.view setNeedsLayout];
}
- (void)changeRate
{
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:NCELocalizedString(@"播放速度") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSNumber *rate in @[@0.75,@1,@1.25,@1.5]){
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@×",rate] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            self->_playbackRate=rate.floatValue;self->_audioPlayer.rate=rate.floatValue;
            [NSUserDefaults.standardUserDefaults setFloat:rate.floatValue forKey:@"NCEAcademyRate"];
            UIButtonConfiguration *c=self->_rateButton.configuration;c.title=[NSString stringWithFormat:@"%@×",rate];self->_rateButton.configuration=c;
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:NCELocalizedString(@"取消") style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=_rateButton;sheet.popoverPresentationController.sourceRect=_rateButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];[self pause];
}

@end

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

@interface WordViewController () <AVAudioPlayerDelegate, CKAlertViewDelegate, UIAlertViewDelegate>
{
    int _bookId;
    NSMutableArray *_items;
    NSDictionary *_lesson;
    int _function; // 1：单词学习 2：词义回想 3：单词回想
    
    AVAudioPlayer *_audioPlayer;
    int _currentIndex;
    
    UIButton *_continueButton;
    UIButton *_pauseButton;
    
    UILabel *_englishLabel;
    UILabel *_countLabel;
    
    UIView *_chineseView;
    UILabel *_chineseLabel;
    UIImageView *_wordImageView;
}

- (void)initData;
- (void)willShowWordInformation;
- (void)showWordInformation;
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
    }
    return self;
}

- (id)initWithData:(NSArray *)data withIndex:(int)index
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] initWithArray:data];
        _currentIndex = index;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    CGFloat headerPosy = [self getHeaderPosY];
    CGFloat headerHeight = [self getConstHeight];
    
    _englishLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, headerPosy, self.view.frame.size.width, headerHeight*1.2)];
    _englishLabel.backgroundColor = [self.colorArray objectAtIndex:4];
    _englishLabel.font = [UIFont systemFontOfSize:headerHeight*24/50];
    _englishLabel.textColor = [UIColor whiteColor];
    _englishLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_englishLabel];
    
    
    _chineseView = [[UIView alloc] initWithFrame:CGRectMake(0, headerPosy+headerHeight*1.2, self.view.frame.size.width, headerHeight*2)];
    _chineseView.backgroundColor = [self.colorArray objectAtIndex:5];
    [self.view addSubview:_chineseView];
    
    _chineseLabel = [[UILabel alloc] initWithFrame:CGRectMake(headerHeight*2/5, 0, self.view.frame.size.width-headerHeight*2/5, headerHeight*2)];
    _chineseLabel.backgroundColor = [UIColor clearColor];
    _chineseLabel.font = [UIFont systemFontOfSize:headerHeight*16/50];
    _chineseLabel.textColor = [UIColor darkGrayColor];
    _chineseLabel.textAlignment = NSTextAlignmentLeft;
    _chineseLabel.numberOfLines = 0;
    _chineseLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [_chineseView addSubview:_chineseLabel];
    
    _wordImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    [_chineseView addSubview:_wordImageView];
    
    CGFloat labelHeight = _englishLabel.frame.size.height;
    CGFloat cviewHeight = _chineseView.frame.size.height;
    CGFloat startPosy = headerPosy + labelHeight + cviewHeight;
    [self addBottomView:startPosy];
    
    [self showWordInformation];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (_currentIndex < _items.count-1) {
        [self performSelector:@selector(next) withObject:nil afterDelay:5];
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
        
        [_items addObject:item];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
}

- (void)showWordInformation
{
    NSDictionary *item = [_items objectAtIndex:_currentIndex];
    
    if (_function != 3) _englishLabel.text = [item objectForKey:@"english"];
    else _englishLabel.text = nil;
    
    
    _chineseLabel.text = [item objectForKey:@"chinese"];
    
    NSString *imageName = [NSString stringWithFormat:@"data/words/jpg/%@.jpg",[item objectForKey:@"english"]];
    NSString *imagePath =  [[NSBundle mainBundle] pathForResource:imageName ofType:nil];
    if (imagePath) {
        CGFloat headerHeight = [self getConstHeight];
        UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
        int width = image.size.width*headerHeight*2/image.size.height;
        _wordImageView.frame = CGRectMake(self.view.frame.size.width-width, 0, width, headerHeight*2);
        _wordImageView.image = image;
    } else {
        _wordImageView.image = nil;
    }
    
    if (_function == 2) {
        _chineseLabel.hidden = YES;
        _wordImageView.hidden = YES;
    }
    
    _countLabel.text = [NSString stringWithFormat:@"%d/%d", _currentIndex+1, (int)_items.count];
    
    NSString *soundName = [NSString stringWithFormat:@"data/words/wav/%@.wav",[item objectForKey:@"english"]];
    NSString *soundPath =  [[NSBundle mainBundle] pathForResource:soundName ofType:nil];
    
    if (soundPath) {
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath] error:nil];
        _audioPlayer.delegate = self;
        [_audioPlayer play];
    }
    
    if (_function) {
        UILabel *lessonLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 40)];
        lessonLabel.font = [UIFont systemFontOfSize:14.f];
        lessonLabel.text = [NSString stringWithFormat:@"第%@课",[item objectForKey:@"lesson_id"]];
        lessonLabel.textColor = [UIColor whiteColor];
        lessonLabel.textAlignment = NSTextAlignmentRight;
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:lessonLabel];
    }
    
    if (_currentIndex >= _items.count-1) {
        [[AdmobManager sharedInstance] showNativeScene];
    }
}

- (void)addBottomView:(CGFloat)startPosy
{
    CGFloat bgviewHeight = self.view.frame.size.height-startPosy-self.bannerHeight;

    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.f, startPosy, self.view.frame.size.width, bgviewHeight)];
    backgroundView.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9f];
    [self.view addSubview:backgroundView];
    
    CGFloat buttonY = bgviewHeight - 90.0f - 40.0f;
    
    int detalWidth = 40;
    if (_function == 2 || _function == 3) detalWidth = 0;
    
    UIButton *strangeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    strangeButton.frame = CGRectMake(10.f, buttonY, 50.f, 40.f);
    [strangeButton setImage:[UIImage imageNamed:@"strange_normal"] forState:UIControlStateNormal];
    [strangeButton setImage:[UIImage imageNamed:@"strange_click"] forState:UIControlStateHighlighted];
    [strangeButton addTarget:self action:@selector(signWord:) forControlEvents:UIControlEventTouchUpInside];
    strangeButton.tag = 101;
    [backgroundView addSubview:strangeButton];
    
    UIButton *vagueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    vagueButton.frame = CGRectMake(60.f, buttonY, 50.f, 40.f);
    [vagueButton setImage:[UIImage imageNamed:@"vague_normal"] forState:UIControlStateNormal];
    [vagueButton setImage:[UIImage imageNamed:@"vague_click"] forState:UIControlStateHighlighted];
    [vagueButton addTarget:self action:@selector(signWord:) forControlEvents:UIControlEventTouchUpInside];
    vagueButton.tag = 103;
    [backgroundView addSubview:vagueButton];
    
    UIButton *familiarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    familiarButton.frame = CGRectMake(110.f, buttonY, 50.f, 40.f);
    [familiarButton setImage:[UIImage imageNamed:@"familiar_normal"] forState:UIControlStateNormal];
    [familiarButton setImage:[UIImage imageNamed:@"familiar_click"] forState:UIControlStateHighlighted];
    [familiarButton addTarget:self action:@selector(signWord:) forControlEvents:UIControlEventTouchUpInside];
    familiarButton.tag = 102;
    [backgroundView addSubview:familiarButton];
    
    if (_function == 3) {
        UIButton *originButton = [UIButton buttonWithType:UIButtonTypeCustom];
        originButton.frame = CGRectMake(self.view.frame.size.width-90.f, buttonY, 40.f, 40.f);
        [originButton setImage:[UIImage imageNamed:@"origin_normal"] forState:UIControlStateNormal];
        [originButton setImage:[UIImage imageNamed:@"origin_click"] forState:UIControlStateHighlighted];
        [originButton addTarget:self action:@selector(showEnglish) forControlEvents:UIControlEventTouchUpInside];
        [backgroundView addSubview:originButton];
    }
    
    if (_function == 2) {
        UIButton *translateButton = [UIButton buttonWithType:UIButtonTypeCustom];
        translateButton.frame = CGRectMake(self.view.frame.size.width-90.f, buttonY, 40.f, 40.f);
        [translateButton setImage:[UIImage imageNamed:@"translate_normal"] forState:UIControlStateNormal];
        [translateButton setImage:[UIImage imageNamed:@"translate_click"] forState:UIControlStateHighlighted];
        [translateButton addTarget:self action:@selector(showChinese) forControlEvents:UIControlEventTouchUpInside];
        [backgroundView addSubview:translateButton];
    }
    
    UIButton *volumeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    volumeButton.frame = CGRectMake(self.view.frame.size.width-50.f, buttonY, 40.f, 40.f);
    [volumeButton setImage:[UIImage imageNamed:@"volume_normal"] forState:UIControlStateNormal];
    [volumeButton setImage:[UIImage imageNamed:@"volume_click"] forState:UIControlStateHighlighted];
    [volumeButton addTarget:self action:@selector(repeat) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:volumeButton];
    
    
    CGFloat yy = bgviewHeight - 90.0f;
    
    UIImageView *line = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, yy+0.5f, self.view.frame.size.width, 1.5f)];
    line.image = [UIImage imageNamed:@"line"];
    [backgroundView addSubview:line];
    
    // share
    UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
    shareButton.frame = CGRectMake(0.f, yy+20.f, 50.f, 50.f);
    [shareButton setImage:[UIImage imageNamed:@"share_normal"] forState:UIControlStateNormal];
    [shareButton setImage:[UIImage imageNamed:@"share_click"] forState:UIControlStateHighlighted];
    [shareButton addTarget:self action:@selector(showOnlineDictionarys) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:shareButton];
    
    // count
    _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(50.f, yy, 90.f, 90.f)];
    _countLabel.backgroundColor = [UIColor clearColor];
    _countLabel.font = [UIFont systemFontOfSize:16];
    _countLabel.textColor = [UIColor grayColor];
    _countLabel.textAlignment = NSTextAlignmentLeft;
    [backgroundView addSubview:_countLabel];
    
    // prev
    UIButton *prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    prevButton.frame = CGRectMake(self.view.frame.size.width-200, yy+25, 40, 40);
    [prevButton setImage:[UIImage imageNamed:@"prev_normal"] forState:UIControlStateNormal];
    [prevButton setImage:[UIImage imageNamed:@"prev_click"] forState:UIControlStateHighlighted];
    [prevButton addTarget:self action:@selector(prev) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:prevButton];
    
    // pause
    _pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _pauseButton.frame = CGRectMake(self.view.frame.size.width-140, yy+20, 50, 50);
    [_pauseButton setImage:[UIImage imageNamed:@"pause_normal"] forState:UIControlStateNormal];
    [_pauseButton setImage:[UIImage imageNamed:@"pause_click"] forState:UIControlStateHighlighted];
    [_pauseButton addTarget:self action:@selector(pause) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:_pauseButton];
    
    // continue
    _continueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _continueButton.frame = CGRectMake(self.view.frame.size.width-140, yy+20, 50, 50);
    [_continueButton setImage:[UIImage imageNamed:@"play_normal"] forState:UIControlStateNormal];
    [_continueButton setImage:[UIImage imageNamed:@"play_click"] forState:UIControlStateHighlighted];
    [_continueButton addTarget:self action:@selector(continue) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:_continueButton];
    _continueButton.hidden = YES;
    
    // next
    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    nextButton.frame = CGRectMake(self.view.frame.size.width-70, yy+25, 40, 40);
    [nextButton setImage:[UIImage imageNamed:@"next_normal"] forState:UIControlStateNormal];
    [nextButton setImage:[UIImage imageNamed:@"next_click"] forState:UIControlStateHighlighted];
    [nextButton addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:nextButton];
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
        hud.label.text = @"已是第一个";
        hud.removeFromSuperViewOnHide = YES;
        
        [hud hideAnimated:YES afterDelay:0.75f];
    }
}

- (void)pause
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
    
    _pauseButton.hidden = YES;
    _continueButton.hidden = NO;
    
    [_audioPlayer pause];
}

- (void)continue
{
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
        hud.label.text = @"已是最后一个";
        hud.removeFromSuperViewOnHide = YES;
        
        [hud hideAnimated:YES afterDelay:0.75f];
    }
}

- (void)willShowWordInformation
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
    _continueButton.hidden = YES;
    _pauseButton.hidden = NO;
}

- (void)signWord:(id)sender
{
    UIButton *button = (UIButton *)sender;
    int status = (int)button.tag-100;
    
    sqlite3 *database;
    //    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    NSString *dbPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"NCE.db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //        NSLog(@"ok");
    }
    
    NSString *updateSql = [NSString stringWithFormat:@"update words set `word_status`=%d where `word_name`='%@'",status,[[_items objectAtIndex:_currentIndex] objectForKey:@"english"]];
    
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [updateSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
    }
    
    if (sqlite3_step(statement) == SQLITE_DONE) {
        //        NSLog(@"done.");
    } else {
        //        NSLog(@"%@, %s",updateSql, sqlite3_errmsg(database));
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
    
}

- (void)showEnglish
{
    if (_englishLabel.text) _englishLabel.text = nil;
    else _englishLabel.text = [[_items objectAtIndex:_currentIndex] objectForKey:@"english"];
}

- (void)showChinese
{
    _chineseLabel.hidden = !_chineseLabel.hidden;
    _wordImageView.hidden = !_wordImageView.hidden;
}

- (void)repeat
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(next) object:nil];
    
    NSString *soundName = [NSString stringWithFormat:@"data/words/wav/%@.wav",[[_items objectAtIndex:_currentIndex] objectForKey:@"english"]];
    NSString *soundPath =  [[NSBundle mainBundle] pathForResource:soundName ofType:nil];
    
    if (soundPath) {
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath] error:nil];
        _audioPlayer.delegate = self;
        [_audioPlayer play];
    }
}

- (void)showOnlineDictionarys
{
    [self pause];
    
    CKAlertView *alertView = [[CKAlertView alloc] initWithTitle:@"在线词典"
                                                        message:nil
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"有道在线词典", @"爱词霸在线词典", @"百度在线词典", @"海词在线词典", nil];
    [alertView show];
}

@end

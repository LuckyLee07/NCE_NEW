//
//  WordDictationViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "WordDictationViewController.h"
#import "sqlite3.h"
#import "CKAlertView.h"
#import "MBProgressHUD.h"
#import "AdmobManager.h"
#import "NCEWordResourceStore.h"
#import <AVFoundation/AVFoundation.h>

static NSString* const kWordDictationViewControllerCellReuseId = @"kWordDictationViewControllerCellReuseId";

@interface WordDictationViewController () <UITableViewDataSource, UITableViewDelegate, CKAlertViewDelegate, UITextFieldDelegate>
{
    int _bookId;
    NSMutableArray *_items;
    int _lessonId;
    
    int _currentIndex;
    
    int _correctAnswers;
    
    UILabel *_countLabel;
    UILabel *_scoreLabel;
    
    UILabel *_questionLabel;
    UITextField *_answerField;
    
    MBProgressHUD *_hud;
    
    AVAudioPlayer *_audioPlayer;
    UIButton *_volumeButton;
    
    //    CKAlertView *_alertView;
}

@property (nonatomic, strong) UITableView *tableView;

- (void)initData;
- (void)addTableView;

- (void)showWordInformation;
- (void)isAnswerWrong:(BOOL)wrong;

- (void)submit;
- (void)pass;
- (void)repeat;

@end

@implementation WordDictationViewController

- (id)initWithBookId:(int)bookId withLessonId:(int)lessonId
{
    self = [super init];
    if (self) {
        self.titleString = NCELocalizedString(@"单词听写");
        _bookId = bookId;
        _lessonId = lessonId;
        
        [self initData];
        
        _currentIndex = 0;
        _correctAnswers = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self addTableView];
    
    _hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // Configure for text only and offset down
    //    _hud.mode = MBProgressHUDModeText;
    _hud.label.text = NCELocalizedString(@"载入中…");
    _hud.removeFromSuperViewOnHide = YES;
    
    [self performSelector:@selector(showWordInformation) withObject:nil afterDelay:0.1f];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self submit];
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    textField.text = @"  ";
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    textField.text = @"  ";
    return NO;
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kWordDictationViewControllerCellReuseId
                                                            forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSArray *array = [cell.contentView subviews];
    for (UIView *view in array) {
        [view removeFromSuperview];
    }
    
    CGFloat height = tableView.frame.size.height/8;
    
    if (indexPath.row == 1) {
        height *= 1.8;
        
        _questionLabel = [[UILabel alloc] initWithFrame:CGRectMake(height/4, 0, self.view.frame.size.width-height/2, height*5/6)];
        _questionLabel.backgroundColor = [self.colorArray objectAtIndex:6];
        _questionLabel.layer.cornerRadius = height/10;
        _questionLabel.layer.masksToBounds = YES;
        _questionLabel.font = [UIFont systemFontOfSize:8*height/50];
        _questionLabel.textColor = [UIColor darkGrayColor];
        _questionLabel.textAlignment = NSTextAlignmentCenter;
        _questionLabel.numberOfLines = 0;
        _questionLabel.adjustsFontSizeToFitWidth = YES;
        _questionLabel.minimumScaleFactor = 0.6;
        [cell.contentView addSubview:_questionLabel];
    } else if (indexPath.row > 1) {
        UIView *background = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, height)];
        background.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.3];
        //        [cell.contentView addSubview:background];
        
        UIColor *color = [UIColor colorWithRed:61/255.f
                                         green:205/255.f
                                          blue:122/255.f
                                         alpha:1.f];
        
        _answerField = [[UITextField alloc] initWithFrame:CGRectMake(height/4, height/2-20, self.view.frame.size.width-80.f-height*9/4, 40)];
        _answerField.backgroundColor = [UIColor clearColor];
        _answerField.font = [UIFont systemFontOfSize:14.f];
        _answerField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        _answerField.delegate = self;
        _answerField.accessibilityIdentifier = @"dictation-answer";
        _answerField.returnKeyType = UIReturnKeyDone;
        _answerField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _answerField.layer.cornerRadius = 6;
        _answerField.layer.masksToBounds = YES;
        _answerField.layer.borderWidth = 1;
        _answerField.layer.borderColor = [color CGColor];
        _answerField.textColor = [UIColor blackColor];
        _answerField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:NCELocalizedString(@"请输入答案") attributes:@{NSForegroundColorAttributeName:[UIColor lightGrayColor],NSFontAttributeName:[UIFont systemFontOfSize:14.f]}];
        [cell.contentView addSubview:_answerField];
        
        
        UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
        submitButton.frame = CGRectMake(self.view.frame.size.width-70.f-height*2, height/2-22, height, 44);
        submitButton.layer.cornerRadius = 10;
        submitButton.layer.masksToBounds = YES;
        submitButton.layer.borderWidth = 1;
        submitButton.layer.borderColor = [color CGColor];
        [submitButton setTitle:NCELocalizedString(@"提交") forState:UIControlStateNormal];
        [submitButton setTitleColor:color forState:UIControlStateNormal];
        submitButton.titleLabel.font = [UIFont systemFontOfSize:12.f];
        submitButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        submitButton.titleLabel.minimumScaleFactor = 0.65;
        [submitButton addTarget:self action:@selector(submit) forControlEvents:UIControlEventTouchUpInside];
        submitButton.accessibilityIdentifier = @"dictation-submit";
        [cell.contentView addSubview:submitButton];
        
        UIButton *passButton = [UIButton buttonWithType:UIButtonTypeCustom];
        passButton.frame = CGRectMake(self.view.frame.size.width-60.f-height, height/2-22, height, 44);
        passButton.layer.cornerRadius = 10;
        passButton.layer.masksToBounds = YES;
        passButton.layer.borderWidth = 1;
        passButton.layer.borderColor = [color CGColor];
        [passButton setTitle:NCELocalizedString(@"跳过") forState:UIControlStateNormal];
        [passButton setTitleColor:color forState:UIControlStateNormal];
        passButton.titleLabel.font = [UIFont systemFontOfSize:12.f];
        passButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        passButton.titleLabel.minimumScaleFactor = 0.65;
        [passButton addTarget:self action:@selector(pass) forControlEvents:UIControlEventTouchUpInside];
        passButton.accessibilityIdentifier = @"dictation-pass";
        [cell.contentView addSubview:passButton];
        
        _volumeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _volumeButton.frame = CGRectMake(self.view.frame.size.width-50.f, height/2-20, 40.f, 40.f);
        UIImage *volumeImage = [UIImage imageNamed:@"volume_click"];
        if ([@[@"ja", @"ko"] containsObject:NCELocalization.sharedLocalization.languageCode]) {
            UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
            volumeImage = [UIImage systemImageNamed:@"speaker.wave.2" withConfiguration:configuration] ?: volumeImage;
            _volumeButton.tintColor = color;
        }
        [_volumeButton setImage:volumeImage forState:UIControlStateNormal];
        //        [_volumeButton setImage:[UIImage imageNamed:@"volume_click"] forState:UIControlStateHighlighted];
        [_volumeButton addTarget:self action:@selector(repeat) forControlEvents:UIControlEventTouchUpInside];
        _volumeButton.accessibilityIdentifier = @"dictation-repeat";
        _volumeButton.accessibilityLabel = NCELocalizedString(@"重读单词");
        [cell.contentView addSubview:_volumeButton];
    } else {
        _scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(height/4, 0, height*2, height)];
        _scoreLabel.backgroundColor = [UIColor clearColor];
        _scoreLabel.font = [UIFont boldSystemFontOfSize:12*height/50];
        _scoreLabel.textColor = [UIColor darkGrayColor];
        _scoreLabel.textAlignment = NSTextAlignmentLeft;
        [cell.contentView addSubview:_scoreLabel];
        
        _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width-height*2.25, 0, height*2, height)];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.font = [UIFont boldSystemFontOfSize:12*height/50];
        _countLabel.textColor = [UIColor darkGrayColor];
        _countLabel.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:_countLabel];
    }
    
    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = tableView.frame.size.height/8;
    
    if (indexPath.row == 1) height *= 1.8;
    
    return height;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor clearColor];
}

#pragma mark -
#pragma mark CKAlertViewDelegate

- (void)alertView:(UIView *)alertView customClickedButtonAtIndex:(NSInteger)buttonIndex
{
    __weak typeof(self) weakSelf = self;
    [[AdmobManager sharedInstance] handleCompletedWordBreakWithCompletion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.navigationController popViewControllerAnimated:YES];
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
        //        NSLog(@"ok");
    }
    
    NSString *selectSql;
    if (_lessonId == 0) {
        selectSql = [NSString stringWithFormat:@"select `word_name`,`word_translation` from words where book_id=%d order by random() limit 20",_bookId+1];
    } else {
        selectSql = [NSString stringWithFormat:@"select `word_name`,`word_translation` from words where lesson_id=%d and book_id=%d order by random()",_lessonId,_bookId+1];
        
    }
    
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
    }
    
    while (sqlite3_step(statement)==SQLITE_ROW) {
        NSMutableDictionary *item = [[NSMutableDictionary alloc] initWithCapacity:3];
        
        NSString *englishString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
        [item setObject:englishString forKey:@"english"];
        
        NSString *chineseString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 1) encoding:NSUTF8StringEncoding];
        [item setObject:[[NCEWordResourceStore sharedStore] translationForWord:englishString fallback:chineseString] forKey:@"chinese"];
        
        [_items addObject:item];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
}

- (void)showResult
{
    CKAlertView *alertView = [[CKAlertView alloc] initWithTitle:NCELocalizedString(@"测验结果")
                                                        message:[NSString stringWithFormat:NCELocalizedString(@"一共 %d 单词，答对 %d 个"), (int)_items.count, _correctAnswers]
                                                       delegate:self
                                              cancelButtonTitle:NCELocalizedString(@"返回")
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)showWordInformation
{
    if (_hud) [_hud hideAnimated:YES];
    
    if (_currentIndex >= _items.count) {
        [self showResult];
    } else {
        _scoreLabel.text = [NSString stringWithFormat:NCELocalizedString(@"%d 分"),_correctAnswers*100/(int)_items.count];
        _countLabel.text = [NSString stringWithFormat:@"%d / %d",_currentIndex+1, (int)_items.count];
        
        NSDictionary *item = [_items objectAtIndex:_currentIndex];
        _questionLabel.text = [item objectForKey:@"chinese"];
        
        NSString *soundPath = [[NCEWordResourceStore sharedStore] audioPathForWord:item[@"english"]];
        
        if (soundPath) {
            _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath] error:nil];
            [_audioPlayer play];
            
            _volumeButton.hidden = NO;
        } else {
            _volumeButton.hidden = YES;
        }
    }
}

- (void)addTableView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:view];
    
    CGRect tableViewFrame = [self getTableViewFrame];
    self.tableView = [[UITableView alloc] initWithFrame:tableViewFrame style:UITableViewStylePlain];
    
    self.tableView.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9f];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.scrollEnabled = NO;
    
    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:kWordDictationViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
}

- (void)isAnswerWrong:(BOOL)wrong
{
    if (_currentIndex < 0 || _currentIndex >= _items.count) return;
    sqlite3 *database;
    //    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    NSString *dbPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"NCE.db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //        NSLog(@"ok");
    }
    
    sqlite3_stmt *statement = NULL;
    if (sqlite3_prepare_v2(database, "UPDATE words SET wrong=? WHERE word_name=?", -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_int(statement, 1, wrong);
        sqlite3_bind_text(statement, 2, [_items[_currentIndex][@"english"] UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_step(statement);
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
}

- (void)submit
{
    if (_currentIndex < 0 || _currentIndex >= _items.count) return;
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // Configure for text only and offset down
    HUD.mode = MBProgressHUDModeCustomView;
    HUD.removeFromSuperViewOnHide = YES;
    
    NSDictionary *item = [_items objectAtIndex:_currentIndex];
    NSString *answerString = [_answerField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([[NCEWordResourceStore sharedStore] answer:answerString matchesWord:item[@"english"]]) {
        HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"answer_correct"]];
        
        _correctAnswers++;
        
        [self isAnswerWrong:NO];
    } else {
        HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"answer_incorrect"]];
        
        [self isAnswerWrong:YES];
    }
    
    [HUD hideAnimated:YES afterDelay:0.5f];
    
    [self pass];
}

- (void)pass
{
    if (_currentIndex < 0 || _currentIndex >= _items.count) return;
    _answerField.text = nil;
    
    [_answerField resignFirstResponder];
    
    _currentIndex++;
    [self showWordInformation];
}

- (void)repeat
{
    if (_currentIndex < 0 || _currentIndex >= _items.count) return;
    NSString *soundPath = [[NCEWordResourceStore sharedStore] audioPathForWord:_items[_currentIndex][@"english"]];
    
    if (soundPath) {
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath] error:nil];
        [_audioPlayer play];
    }
}

@end

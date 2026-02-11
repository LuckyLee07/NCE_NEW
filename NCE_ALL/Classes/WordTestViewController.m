//
//  WordTestViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "WordTestViewController.h"
#import "sqlite3.h"
#import "MBProgressHUD.h"
#import "CKAlertView.h"
#import "AdmobManager.h"

static NSString* const kWordTestViewControllerCellReuseId = @"kWordTestViewControllerCellReuseId";

@interface WordTestViewController () <UITableViewDataSource, UITableViewDelegate, CKAlertViewDelegate, UIAlertViewDelegate>
{
    int _bookId;
    NSMutableArray *_items;
    int _function; // 5：英汉练习 6：汉英练习
    
    int _lessonId;
    int _currentIndex;
    
    int _correctAnswers;
    
    UILabel *_countLabel;
    UILabel *_scoreLabel;
    
    UILabel *_questionLabel;
    
    int _rightAnswerTag;
    
    MBProgressHUD *_hud;
}

@property (nonatomic, strong) UITableView *tableView;

//@property (nonatomic, strong) GADInterstitial *interstitial;

- (void)initData;
- (void)addTableView;

- (void)showWordInformation:(id)sender;
- (void)isAnswerWrong:(BOOL)wrong;

@end

@implementation WordTestViewController

- (id)initWithBookId:(int)bookId withLessonId:(int)lessonId withFunction:(int)function
{
    self = [super init];
    if (self) {
        _bookId = bookId;
        _function = function;
        
        self.titleString = @"单词练习";
        
        _lessonId = lessonId;
        
        _currentIndex = 0;
        _correctAnswers = 0;
        
        [self initData];
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
    _hud.label.text = @"loading...";
    _hud.removeFromSuperViewOnHide = YES;
    
    // [self showWordInformation];
    [self performSelector:@selector(showWordInformation:) withObject:nil afterDelay:0.1f];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 6;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kWordTestViewControllerCellReuseId
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
    UILabel *idLabel;
    
    if (indexPath.row == 1) {
        height *= 1.8;
        
        _questionLabel = [[UILabel alloc] initWithFrame:CGRectMake(height/4, 0, self.view.frame.size.width-height/2, height*5/6)];
        _questionLabel.backgroundColor = [self.colorArray objectAtIndex:6];
        _questionLabel.layer.cornerRadius = height/10;
        _questionLabel.layer.masksToBounds = YES;
        _questionLabel.font = [UIFont systemFontOfSize:12*height/50];
        _questionLabel.textColor = [UIColor darkGrayColor];
        _questionLabel.textAlignment = NSTextAlignmentCenter;
        [cell.contentView addSubview:_questionLabel];
    } else if (indexPath.row > 1) {
        height *= 1.2;
        
        NSArray *idArray = @[@"A", @"B", @"C", @"D"];
        idLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 0.f, height, height)];
        idLabel.backgroundColor = [self.colorArray objectAtIndex:indexPath.row];
        idLabel.font = [UIFont systemFontOfSize:14*height/50];
        idLabel.textColor = [UIColor whiteColor];
        idLabel.textAlignment = NSTextAlignmentCenter;
        idLabel.text = idArray[indexPath.row-2];
        [cell.contentView addSubview:idLabel];
        
        UILabel *answerLabel = [[UILabel alloc] initWithFrame:CGRectMake(height, 0, self.view.frame.size.width-height, height)];
        answerLabel.backgroundColor = [[self.colorArray objectAtIndex:indexPath.row] colorWithAlphaComponent:0.75f];
        //        answerLabel.alpha = 0.5f;
        answerLabel.font = [UIFont systemFontOfSize:14*height/50];
        answerLabel.textColor = [UIColor whiteColor];
        answerLabel.textAlignment = NSTextAlignmentCenter;
        answerLabel.tag = 100+indexPath.row;
        [cell.contentView addSubview:answerLabel];
        
        // line
        UILabel *line = [[UILabel alloc] initWithFrame:CGRectMake(0, height-0.5f, self.view.frame.size.width, 0.5f)];
        line.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.75f];
        [cell.contentView addSubview:line];
        
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
    
    // show when the cell is selected
    UIView *maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, height)];
    maskView.backgroundColor = [UIColor clearColor];
    maskView.tag = 1000+indexPath.row;
    [cell.contentView addSubview:maskView];
    
    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = tableView.frame.size.height/8;
    
    if (indexPath.row == 1) height *= 1.8;
    else if (indexPath.row > 1) height *= 1.2;
    //    else height *= 0.8f;
    
    return height;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row <= 1) return;
    if (_currentIndex >= _items.count) return;
    
    if (indexPath.row > 1) [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.3f];
    
    int answerTag = 100 + (int)indexPath.row;
    
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // Configure for text only and offset down
    HUD.mode = MBProgressHUDModeCustomView;
    HUD.removeFromSuperViewOnHide = YES;
    
    if (answerTag == _rightAnswerTag) {
        HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"answer_correct"]];
        
        
        _correctAnswers++;
        
        [self isAnswerWrong:NO];
    } else {
        HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"answer_incorrect"]];
        
        [self isAnswerWrong:YES];
    }
    
    [HUD hideAnimated:YES afterDelay:0.5f];
    
    // 防止溢出
    if (_currentIndex <= _items.count) {
        _currentIndex++;
    }
    
    [self performSelector:@selector(showWordInformation:) withObject:indexPath afterDelay:0.5f];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor clearColor];
}

#pragma mark -
#pragma mark CKAlertViewDelegate

- (void)alertView:(UIView *)alertView customClickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self.navigationController popViewControllerAnimated:YES];
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
        [item setObject:chineseString forKey:@"chinese"];
        
        [_items addObject:item];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
}

- (void)showWordInformation:(id)sender
{
    if (_hud) [_hud hideAnimated:YES];
    
    if (sender) {
        NSIndexPath *indexPath = (NSIndexPath *)sender;
        [self tableView:self.tableView didDeselectRowAtIndexPath:indexPath];
    }
    
    if (_currentIndex >= _items.count) {
        if ([[AdmobManager sharedInstance] adIsCanShow]) {
            [[AdmobManager sharedInstance] showNativeScene];
        } else {
            [self showResult];
        }
    } else {
        _scoreLabel.text = [NSString stringWithFormat:@"%d 分",_correctAnswers*100/(int)_items.count];
        _countLabel.text = [NSString stringWithFormat:@"%d / %d",_currentIndex+1, (int)_items.count];
        
        // right answer tag
        _rightAnswerTag = 102 + arc4random() % (3+1);
        UILabel *rightAnswerLabel = (UILabel *)[self.view viewWithTag:_rightAnswerTag];
        NSDictionary *item = [_items objectAtIndex:_currentIndex];
        
        NSString *columns;
        
        if (_function == 5) {
            _questionLabel.text = [item objectForKey:@"english"];
            
            rightAnswerLabel.text = [item objectForKey:@"chinese"];
            
            columns = @"`word_translation`";
        } else {
            _questionLabel.text = [item objectForKey:@"chinese"];
            
            rightAnswerLabel.text = [item objectForKey:@"english"];
            
            columns = @"`word_name`";
        }
        
        // wrong answer;
        NSMutableArray *wrongAnswerArray = [[NSMutableArray alloc] initWithCapacity:3];
        
        sqlite3 *database;
        NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
        
        if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
            //            NSLog(@"ok");
        }
        
        NSString *selectSql;
        
        if (_lessonId == 0) {
            selectSql = [NSString stringWithFormat:@"select %@ from words where book_id=%d and %@ != '%@' order by random() limit 3",columns,_bookId+1,columns,rightAnswerLabel.text];
        } else {
            selectSql = [NSString stringWithFormat:@"select %@ from words where lesson_id=%d and book_id=%d and %@ != '%@' order by random() limit 3",columns,_lessonId,_bookId+1,columns,rightAnswerLabel.text];
            
        }
        
        sqlite3_stmt *statement;
        if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
            //            NSLog(@"select ok.");
        }
        
        while (sqlite3_step(statement)==SQLITE_ROW) {
            NSString *answerString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
            [wrongAnswerArray addObject:answerString];
        }
        
        sqlite3_finalize(statement);
        sqlite3_close(database);
        
        int yy = 0;
        for (int ii = 0; ii < 4; ii++) {
            int answerTag = 102 + ii;
            if (answerTag == _rightAnswerTag) continue;
            UILabel *answerLabel = (UILabel *)[self.view viewWithTag:answerTag];
            answerLabel.text = [wrongAnswerArray objectAtIndex:yy];
            yy++;
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
           forCellReuseIdentifier:kWordTestViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
}

- (void)isAnswerWrong:(BOOL)wrong
{
    sqlite3 *database;
    //    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    NSString *dbPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"NCE.db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //        NSLog(@"ok");
    }
    
    NSString *updateSql = [NSString stringWithFormat:@"update words set `wrong`=%d where `word_name`='%@'",wrong,[[_items objectAtIndex:_currentIndex] objectForKey:@"english"]];
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [updateSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
    }
    
    if (sqlite3_step(statement) == SQLITE_DONE) {
        //        NSLog(@"done.");
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
}

- (void)showResult
{
    CKAlertView *myAlertView = [[CKAlertView alloc] initWithTitle:@"测验结果"
                                                          message:[NSString stringWithFormat:@"一共 %d 单词，答对 %d 个", (int)_items.count, _correctAnswers]
                                                         delegate:self
                                                cancelButtonTitle:@"返回"
                                                otherButtonTitles:nil];
    [myAlertView show];
}

@end


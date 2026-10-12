//
//  LessonViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "LessonViewController.h"
#import "sqlite3.h"
#import "AdmobManager.h"
#import "TextViewController.h"
#import "WordViewController.h"
#import "WordTestViewController.h"
#import "WordDictationViewController.h"

static NSString* const kLessonViewControllerCellReuseId = @"kLessonViewControllerCellReuseId";

@interface LessonViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *_items;
    int _bookId;
    int _function;
    int _showTimes;
    NSInteger _currIndex;
}

@property (nonatomic, strong) UITableView *tableView;

- (void)initData;
- (void)addTableView;

@end

@implementation LessonViewController

- (id)initWithBookId:(int)bookId withTitle:(NSString *)title withFunction:(int)function
{
    self = [super init];
    if (self) {
        _bookId = bookId;
        self.titleString = title;
        _function = function;
        _showTimes = 1;
        _currIndex = -1;
        
        [self initData];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self addTableView];
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
    NCEAcademyCell *cell=[tableView dequeueReusableCellWithIdentifier:kLessonViewControllerCellReuseId forIndexPath:indexPath];
    
    NSArray *parts=[_items[indexPath.row][@"name"] componentsSeparatedByString:@"－"];
    NSString *title=parts.count>1 ? parts[1] : _items[indexPath.row][@"name"];
    NSString *subtitle=parts.count>2 ? NCEChineseText(parts[2]) : @"";
    NSString *badge=[NSString stringWithFormat:@"%03d",[_items[indexPath.row][@"id"] intValue]];
    [cell configureTitle:title subtitle:subtitle badge:badge symbol:nil];
    NSDictionary *resume=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"NCEAcademyResume"];
    [cell setEmphasized:[resume[@"book"] intValue]==_bookId && [resume[@"lesson"][@"id"] isEqual:_items[indexPath.row][@"id"]]];
    cell.accessibilityIdentifier=[NSString stringWithFormat:@"lesson-%ld",(long)indexPath.row];

    return cell;
}


#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.15f];
    
    NSDictionary *lesson = [_items objectAtIndex:indexPath.row];
    
    if (_function == 0) {
        TextViewController *textController = [[TextViewController alloc] initWithBookId:_bookId
                                                                             withLesson:lesson];
        [self.navigationController pushViewController:textController animated:YES];
    
    } else if (_function < 4) {
        WordViewController *wordController = [[WordViewController alloc] initWithBookId:_bookId
                                                                             withLesson:lesson
                                                                           withFunction:_function];
        wordController.titleString = self.titleString;
        [self.navigationController pushViewController:wordController animated:YES];
    } else if (_function == 4) {
        WordDictationViewController *dictationController = [[WordDictationViewController alloc]
                                                            initWithBookId:_bookId
                                                            withLessonId:[[lesson objectForKey:@"id"] intValue]];
        [self.navigationController pushViewController:dictationController animated:YES];
    } else if (_function < 7) {
        WordTestViewController *wortTestController = [[WordTestViewController alloc]
                                                      initWithBookId:_bookId
                                                      withLessonId:[[lesson objectForKey:@"id"] intValue]
                                                      withFunction:_function];
        [self.navigationController pushViewController:wortTestController animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
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
    
    NSString *selectSql = [NSString stringWithFormat:@"select `name`,`lesson_id` from play_list_lessons where book_id=%d order by order_id",_bookId+1];
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //                NSLog(@"select ok.");
    }
    
    while (sqlite3_step(statement)==SQLITE_ROW) {
        NSMutableDictionary *item = [[NSMutableDictionary alloc] initWithCapacity:2];
        
        NSString *nameString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
        [item setObject:nameString forKey:@"name"];
        
        NSString *idString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 1) encoding:NSUTF8StringEncoding];
        [item setObject:idString forKey:@"id"];
        
        [_items addObject:item];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
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
    
    [self.tableView registerClass:[NCEAcademyCell class]
           forCellReuseIdentifier:kLessonViewControllerCellReuseId];
    
    NCEPrepareTable(self.tableView);
    self.tableView.tableHeaderView=[[NCEAcademyHeader alloc] initWithEyebrow:@"MY COURSE" title:[NSString stringWithFormat:NCELocalizedString(@"第%d册"),_bookId+1] subtitle:self.titleString image:@"academy-books"];
    [self.view addSubview:self.tableView];
}

@end

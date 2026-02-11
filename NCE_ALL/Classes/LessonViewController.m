//
//  LessonViewController.m
//  NCE1
//
//  Created by lizi on 17/8/1.
//  Copyright © 2017年 PalmGame. All rights reserved.
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kLessonViewControllerCellReuseId
                                                            forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSArray *array = [cell.contentView subviews];
    for (UIView *view in array) {
        [view removeFromSuperview];
    }
    
    CGFloat height = tableView.frame.size.height/10;
    
    NSString *nameString = [[_items objectAtIndex:indexPath.row] objectForKey:@"name"];
    NSArray *lessonArray = [nameString componentsSeparatedByString:@"－"];
    
    // lesson name
    UILabel *idLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, height, height)];
    idLabel.backgroundColor = [self.colorArray objectAtIndex:indexPath.row%9];
    idLabel.font = [UIFont systemFontOfSize:12*height/50];
    idLabel.textColor = [UIColor whiteColor];
    idLabel.text = [lessonArray objectAtIndex:0];
    idLabel.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:idLabel];
    
    // english title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height*4/3, height/12, tableView.frame.size.width-height, height/2)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14*height/50];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = [lessonArray objectAtIndex:1];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:titleLabel];
    
    // chinese title
    UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height*4/3, height*7/12, tableView.frame.size.width-height, height*5/12)];
    subTitleLabel.backgroundColor = [UIColor clearColor];
    subTitleLabel.font = [UIFont systemFontOfSize:12*height/50];
    subTitleLabel.textColor = [UIColor darkGrayColor];
    subTitleLabel.text = [lessonArray objectAtIndex:2];
    subTitleLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:subTitleLabel];
    
    // show when the cell is selected
    UIView *maskView = [[UIView alloc] initWithFrame:CGRectMake(height, 0, tableView.frame.size.width-height, height)];
    maskView.backgroundColor = [UIColor clearColor];
    maskView.tag = 1000+indexPath.row;
    [cell.contentView addSubview:maskView];
    
    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.frame.size.height/10;
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
    CGFloat height = tableView.frame.size.height/10;
    
    if ([tableView respondsToSelector:@selector(setSeparatorInset:)])
    {
        [tableView setSeparatorInset:UIEdgeInsetsMake(0, height, 0, 0)];
    }
    
    else if ([tableView respondsToSelector:@selector(setLayoutMargins:)])
    {
        [tableView setLayoutMargins:UIEdgeInsetsMake(0, height, 0, 0)];
    }
    
    else if ([cell respondsToSelector:@selector(setLayoutMargins:)])
    {
        [cell setLayoutMargins:UIEdgeInsetsMake(0, height, 0, 0)];
    }
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
    
    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:kLessonViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
}

@end

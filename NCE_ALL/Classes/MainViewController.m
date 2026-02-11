//
//  MainViewController.m
//  NCE1
//
//  Created by lizi on 17/8/1.
//  Copyright © 2017年 PalmGame. All rights reserved.
//

#import "MainViewController.h"
#import "sqlite3.h"
#import "LessonViewController.h"
#import "WordBookViewController.h"
#import "WordTestViewController.h"
#import "WordSearchViewController.h"
#import "WordDictationViewController.h"
#import "CKAlertView.h"

static NSString* const kMainViewControllerCellReuseId = @"kMainViewControllerCellReuseId";

@interface MainViewController () <UITableViewDataSource, UITableViewDelegate, CKAlertViewDelegate>
{
    NSMutableArray *_items;
    int _bookId;
}

@property (nonatomic, strong) UITableView *tableView;

- (void)initData;
- (void)addTableView;

@end

@implementation MainViewController

- (id)initWithBookId:(int)bookId
{
    self = [super init];
    if (self) {
        NSArray *bookTitles = @[@"一", @"二", @"三", @"四"];
        _bookId = bookId;
        self.titleString = [NSString stringWithFormat:@"第%@册", [bookTitles objectAtIndex:_bookId]];
        
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMainViewControllerCellReuseId
                                                            forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSArray *array = [cell.contentView subviews];
    for (UIView *view in array) {
        [view removeFromSuperview];
    }
    
    CGFloat height = tableView.frame.size.height/_items.count;
    
    UILabel *idLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, height, height)];
    idLabel.backgroundColor = [self.colorArray objectAtIndex:indexPath.row];
    idLabel.font = [UIFont systemFontOfSize:20*height/50];
    idLabel.textColor = [UIColor whiteColor];
    idLabel.text = [NSString stringWithFormat:@"%ld",(long)indexPath.row+1];
    idLabel.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:idLabel];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height*4/3, 0, tableView.frame.size.width-height, height)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14*height/50];
    titleLabel.textColor = [self.colorArray objectAtIndex:indexPath.row];
    titleLabel.text = [_items objectAtIndex:indexPath.row];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:titleLabel];
    
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
    return tableView.frame.size.height/_items.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    int index = (int)indexPath.row;
    [self.view viewWithTag:1000+index].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.15f];
    
    if (index < 4) {
        LessonViewController *lessonController = [[LessonViewController alloc] initWithBookId:_bookId withTitle:[_items objectAtIndex:index] withFunction:index];
        [self.navigationController pushViewController:lessonController animated:YES];
    } else if (index < 7) {
        
        CKAlertView *alertView = [[CKAlertView alloc] initWithTitle:@"请选择测试内容"
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:@"单元测试", @"随机测试", nil];
        alertView.tag = 10000+indexPath.row;
        [alertView show];
    } else if (index == 7) {
        WordSearchViewController *wordSearchController = [[WordSearchViewController alloc] initWithBookId:_bookId];
        [self.navigationController pushViewController:wordSearchController animated:YES];
    } else {
        WordBookViewController *wordBookController = [[WordBookViewController alloc] initWithBookId:_bookId withTitle:[_items objectAtIndex:index]];
        [self.navigationController pushViewController:wordBookController animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = tableView.frame.size.height/_items.count;
    
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
#pragma mark CKAlertViewDelegate

- (void)alertView:(UIView *)alertView customClickedButtonAtIndex:(NSInteger)buttonIndex
{
    int index = (int)alertView.tag-10000;
    if (buttonIndex == 0) {
        LessonViewController *lessonController = [[LessonViewController alloc] initWithBookId:_bookId
                                                                                    withTitle:[_items objectAtIndex:index]
                                                                                 withFunction:index];
        [self.navigationController pushViewController:lessonController animated:YES];
    } else if (buttonIndex == 1) {
        if (index == 4) {
            WordDictationViewController *dictationController = [[WordDictationViewController alloc] initWithBookId:_bookId withLessonId:0];
            [self.navigationController pushViewController:dictationController animated:YES];
        } else {
            WordTestViewController *testController = [[WordTestViewController alloc] initWithBookId:_bookId
                                                                                       withLessonId:0
                                                                                       withFunction:index];
            [self.navigationController pushViewController:testController animated:YES];
        }
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
        //        NSLog(@"ok");
    }
    
    NSString *selectSql = @"select `name` from play_learn_mode order by order_id";
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
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
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:view];
    
    CGRect tableViewFrame = [self getTableViewFrame];
    self.tableView = [[UITableView alloc] initWithFrame:tableViewFrame style:UITableViewStylePlain];
    
    self.tableView.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9f];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.scrollEnabled = NO;
    
    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:kMainViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
}

@end

//
//  WordBookViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "WordBookViewController.h"
#import "sqlite3.h"
#import "WordBookDetailViewController.h"

static NSString* const kWordBookViewControllerCellReuseId = @"kWordBookViewControllerCellReuseId";

@interface WordBookViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *_items;
    int _bookId;
    
    NSMutableDictionary *_wordBook;
}

@property (nonatomic, strong) UITableView *tableView;

- (void)initData;
- (void)addTableView;

@end

@implementation WordBookViewController

- (id)initWithBookId:(int)bookId withTitle:(NSString *)title
{
    self = [super init];
    if (self) {
        _bookId = bookId;
        self.titleString = title;
        
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kWordBookViewControllerCellReuseId
                                                            forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSArray *array = [cell.contentView subviews];
    for (UIView *view in array) {
        [view removeFromSuperview];
    }
    
    CGFloat height = tableView.frame.size.height/8;
    
    UILabel *idLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, height, height)];
    idLabel.backgroundColor = [self.colorArray objectAtIndex:indexPath.row];
    idLabel.font = [UIFont systemFontOfSize:20*height/50];
    idLabel.textColor = [UIColor whiteColor];
    idLabel.text = [NSString stringWithFormat:@"%ld",(long)indexPath.row+1];
    idLabel.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:idLabel];
    
    // title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height*4/3, height/12, tableView.frame.size.width-height, height/2)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14*height/50];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = [_items objectAtIndex:indexPath.row];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:titleLabel];
    
    // count
    NSString *count = [_wordBook objectForKey:[NSString stringWithFormat:@"%d",(int)indexPath.row]];
    if (!count) count = @"0";
    
    UILabel *countLabel = [[UILabel alloc] initWithFrame:CGRectMake(height*4/3, height*7/12, tableView.frame.size.width-height, height*5/12)];
    countLabel.backgroundColor = [UIColor clearColor];
    countLabel.font = [UIFont systemFontOfSize:12*height/50];
    countLabel.textColor = [UIColor darkGrayColor];
    countLabel.text = count;
    countLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:countLabel];
    
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
    return tableView.frame.size.height/8;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.15f];
    
    
    NSDictionary *whereDictionary;
    if (indexPath.row == 4) {
        whereDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:@(1), @"value", @"wrong", @"key", nil];
    } else {
        NSString *value = [NSString stringWithFormat:@"%d", (int)indexPath.row];
        whereDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:value, @"value", @"word_status", @"key", nil];
    }
    
    WordBookDetailViewController *detailController = [[WordBookDetailViewController alloc] initWithBookId:_bookId
                                                                                                withTitle:[_items objectAtIndex:indexPath.row]
                                                                                            withCondition:whereDictionary];
    [self.navigationController pushViewController:detailController animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([tableView respondsToSelector:@selector(setSeparatorInset:)])
    {
        [tableView setSeparatorInset:UIEdgeInsetsMake(0, 0, 0, 0)];
    }
    
    else if ([tableView respondsToSelector:@selector(setLayoutMargins:)])
    {
        [tableView setLayoutMargins:UIEdgeInsetsMake(0, 0, 0, 0)];
    }
    
    else if ([cell respondsToSelector:@selector(setLayoutMargins:)])
    {
        [cell setLayoutMargins:UIEdgeInsetsMake(0, 0, 0, 0)];
    }
}

#pragma mark -
#pragma mark Private Methods

- (void)initData
{
    _items = [[NSMutableArray alloc] init];
    
    sqlite3 *database;
    //    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    NSString *dbPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"NCE.db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        NSLog(@"ok");
    }
    
    NSString *selectSql = @"select `name_cn` from word_book order by order_id";
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        NSLog(@"select ok.");
    } else {
        NSAssert1(0, @"Error:%s", sqlite3_errmsg(database));
    }
    
    while (sqlite3_step(statement)==SQLITE_ROW) {
        NSString *nameString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
        
        [_items addObject:nameString];
    }
    
    sqlite3_finalize(statement);
    
    
    _wordBook = [[NSMutableDictionary alloc] init];
    NSString *groupSql = [NSString stringWithFormat:@"select `word_status`,count(`id`) from words where `book_id`=%d group by `word_status` order by `word_status`",(int)_bookId+1];
    sqlite3_stmt *groupStatement;
    if (sqlite3_prepare_v2(database, [groupSql UTF8String], -1, &groupStatement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
    }
    
    while (sqlite3_step(groupStatement)==SQLITE_ROW) {
        NSString *statusString = [NSString stringWithFormat:@"%d",sqlite3_column_int(groupStatement, 0)];
        NSString *countString = [NSString stringWithFormat:@"%d", sqlite3_column_int(groupStatement, 1)];
        
        [_wordBook setObject:countString forKey:statusString];
    }
    
    sqlite3_finalize(groupStatement);
    
    
    NSString *wrongSql = [NSString stringWithFormat:@"select count(`id`) from words where `book_id`=%d and `wrong`=1",(int)_bookId+1];
    sqlite3_stmt *wrongStatement;
    if (sqlite3_prepare_v2(database, [wrongSql UTF8String], -1, &wrongStatement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
    }
    
    while (sqlite3_step(wrongStatement)==SQLITE_ROW) {
        NSString *countString = [NSString stringWithFormat:@"%d",sqlite3_column_int(wrongStatement, 0)];
        
        [_wordBook setObject:countString forKey:@"4"];
    }
    
    sqlite3_finalize(wrongStatement);
    
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
           forCellReuseIdentifier:kWordBookViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
}

@end

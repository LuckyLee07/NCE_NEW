//
//  WordBookDetailViewController.m
//  NCE1
//
//  Created by lizi on 17/8/1.
//  Copyright © 2017年 PalmGame. All rights reserved.
//

#import "WordBookDetailViewController.h"
#import "sqlite3.h"
#import "MBProgressHUD.h"
#import "WordViewController.h"

static NSString* const kWordBookDetailViewControllerCellReuseId = @"kWordBookDetailViewControllerCellReuseId";

@interface WordBookDetailViewController () <UITableViewDataSource, UITableViewDelegate>
{
    NSMutableArray *_items;
    int _bookId;
    
    NSDictionary *_where;
    
    MBProgressHUD *_hud;
}

@property (nonatomic, strong) UITableView *tableView;

- (void)initData;
- (void)addTableView;

@end

@implementation WordBookDetailViewController

- (id)initWithBookId:(int)bookId withTitle:(NSString *)title withCondition:(NSDictionary *)where
{
    self = [super init];
    if (self) {
        _bookId = bookId;
        self.titleString = title;
        
        _where = where;
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
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [self initData];
    [self.tableView reloadData];
    
    //    _hud.mode = MBProgressHUDModeText;
    //    _hud.labelText = @"向左滑动可以进行编辑";
    //    [_hud hide:YES afterDelay:0.75f];
    [_hud hideAnimated:YES];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kWordBookDetailViewControllerCellReuseId
                                                            forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSArray *array = [cell.contentView subviews];
    for (UIView *view in array) {
        [view removeFromSuperview];
    }
    
    CGFloat height = tableView.frame.size.height/12;
    NSDictionary *item = [_items objectAtIndex:indexPath.row];
    
    UILabel *idLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, height, height)];
    idLabel.backgroundColor = [self.colorArray objectAtIndex:indexPath.row%9];
    idLabel.font = [UIFont systemFontOfSize:20*height/50];
    idLabel.textColor = [UIColor whiteColor];
    idLabel.text = [NSString stringWithFormat:@"%ld",(long)indexPath.row+1];
    idLabel.textAlignment = NSTextAlignmentCenter;
    [cell.contentView addSubview:idLabel];
    
    // english
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height*4/3, height/12, tableView.frame.size.width-height, height/2)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14*height/50];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = [item objectForKey:@"english"];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:titleLabel];
    
    // chinese
    UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height*4/3, height*7/12, tableView.frame.size.width-height, height*5/12)];
    subTitleLabel.backgroundColor = [UIColor clearColor];
    subTitleLabel.font = [UIFont systemFontOfSize:12*height/50];
    subTitleLabel.textColor = [UIColor darkGrayColor];
    subTitleLabel.text = [item objectForKey:@"chinese"];
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
    return tableView.frame.size.height/12;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.15f];
    
    WordViewController *wordController = [[WordViewController alloc] initWithData:_items withIndex:(int)indexPath.row];
    wordController.titleString = self.titleString;
    [self.navigationController pushViewController:wordController animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = tableView.frame.size.height/12;
    
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
    //    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    NSString *dbPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"NCE.db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //        NSLog(@"ok");
    }
    
    NSString *selectSql = [NSString stringWithFormat:@"select `word_name`,`word_translation`,`lesson_id` from words where `book_id`=%d and `%@`=%@ order by order_id",_bookId+1,[_where objectForKey:@"key"],[_where objectForKey:@"value"]];
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
           forCellReuseIdentifier:kWordBookDetailViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
}

@end


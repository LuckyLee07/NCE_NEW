//
//  WordBookDetailViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "WordBookDetailViewController.h"
#import "sqlite3.h"
#import "NCEWordResourceStore.h"
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
    _hud.label.text = NCELocalizedString(@"载入中…");
    _hud.removeFromSuperViewOnHide = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self initData];
    self.tableView.backgroundView=_items.count ? nil : NCEEmptyState(NCELocalizedString(@"这里还没有单词"),NCELocalizedString(@"学习时标记熟悉程度，单词会自动归入这里。"));
    self.tableView.tableHeaderView=[[NCEAcademyHeader alloc] initWithEyebrow:@"MY WORDS" title:self.titleString subtitle:[NSString stringWithFormat:NCELocalizedString(@"%@ 个单词"),@(_items.count)] image:@"academy-books"];
    [self.view setNeedsLayout];
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
    NCEAcademyCell *cell=[tableView dequeueReusableCellWithIdentifier:kWordBookDetailViewControllerCellReuseId forIndexPath:indexPath];
    
    NSDictionary *item=_items[indexPath.row];
    [cell configureTitle:[NCEWordResourceStore.sharedStore displayNameForWord:item[@"english"]] subtitle:item[@"chinese"] badge:nil symbol:@"speaker.wave.2"];
    cell.accessibilityIdentifier=[@"wordbook-word-" stringByAppendingString:item[@"english"]];

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
        [item setObject:[[NCEWordResourceStore sharedStore] translationForWord:englishString fallback:chineseString] forKey:@"chinese"];
        
        NSString *lessonId = [NSString stringWithFormat:@"%d",sqlite3_column_int(statement, 2)];
        [item setObject:lessonId forKey:@"lesson_id"];
        item[@"book_id"]=@(_bookId+1);
        
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
           forCellReuseIdentifier:kWordBookDetailViewControllerCellReuseId];
    
    NCEPrepareTable(self.tableView);
    [self.view addSubview:self.tableView];
}

@end

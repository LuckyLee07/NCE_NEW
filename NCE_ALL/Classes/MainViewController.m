//
//  MainViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
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
        NSString *code = NCELocalization.sharedLocalization.languageCode;
        NSString *number = [@[@"ja", @"ko"] containsObject:code] ? @(_bookId + 1).stringValue : bookTitles[_bookId];
        self.titleString = [NSString stringWithFormat:NCELocalizedString(@"第%@册"), number];
        
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
    NCEAcademyCell *cell=[tableView dequeueReusableCellWithIdentifier:kMainViewControllerCellReuseId forIndexPath:indexPath];
    
    NSArray *symbols=@[@"headphones",@"square.stack.3d.up",@"text.bubble",@"textformat.abc",@"waveform",@"character.bubble",@"character.book.closed",@"magnifyingglass",@"square.and.pencil"];
    NSArray *hints=@[@"听一句，再读一句",@"图片、释义与发音一起记",@"先想一想，再看释义",@"看释义，回想英文",@"听发音，写下单词",@"根据英文选择释义",@"根据释义选择英文",@"查找本册的单词或释义",@"按熟悉程度安排复习"];
    [cell configureTitle:NCEChineseText(_items[indexPath.row]) subtitle:NCELocalizedString(hints[indexPath.row]) badge:nil symbol:symbols[indexPath.row]];
    cell.accessibilityIdentifier=[NSString stringWithFormat:@"mode-%ld",(long)indexPath.row];
    [cell setEmphasized:indexPath.row==0];

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
    int index = (int)indexPath.row;
    [self.view viewWithTag:1000+index].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.15f];
    
    if (index < 4) {
        LessonViewController *lessonController = [[LessonViewController alloc] initWithBookId:_bookId withTitle:[_items objectAtIndex:index] withFunction:index];
        [self.navigationController pushViewController:lessonController animated:YES];
    } else if (index < 7) {
        
        CKAlertView *alertView = [[CKAlertView alloc] initWithTitle:NCELocalizedString(@"请选择测试内容")
                                                            message:nil
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NCELocalizedString(@"单元测试"), NCELocalizedString(@"随机测试"), nil];
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
    self.tableView.scrollEnabled = YES;
    
    [self.tableView registerClass:[NCEAcademyCell class]
           forCellReuseIdentifier:kMainViewControllerCellReuseId];
    
    NCEPrepareTable(self.tableView);
    self.tableView.tableHeaderView=[[NCEAcademyHeader alloc] initWithEyebrow:@"NEW CONCEPT ENGLISH" title:self.titleString subtitle:NCELocalizedString(@"听、记、练，找到适合你的学习方式。") image:@"academy-books"];
    [self.view addSubview:self.tableView];
}

@end

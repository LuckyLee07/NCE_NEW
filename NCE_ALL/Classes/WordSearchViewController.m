//
//  WordSearchViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "WordSearchViewController.h"
#import "sqlite3.h"
#import "MBProgressHUD.h"
#import "WordViewController.h"
#import "NCEWordResourceStore.h"

static NSString* const kWordSearchViewControllerCellReuseId = @"kWordSearchViewControllerCellReuseId";

@interface WordSearchViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate>
{
    UISearchBar *_searchBar;
    NSMutableArray *_items;
    NSMutableArray *_originData;
    
    MBProgressHUD *_hud;
    
    int _bookId;
}

@property (nonatomic, strong) UITableView *tableView;

- (void)addSearchBar;
- (void)dismissKeyBoard;
- (void)addTableView;

@end

@implementation WordSearchViewController

- (id)initWithBookId:(int)bookId
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
        _originData = [[NSMutableArray alloc] init];
        
        self.titleString = NCELocalizedString(@"单词搜索");
        
        _bookId = bookId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // Configure for text only and offset down
    //    _hud.mode = MBProgressHUDModeText;
    _hud.label.text = NCELocalizedString(@"载入中…");
    _hud.removeFromSuperViewOnHide = YES;
    
    [self initData];
    
    [self addSearchBar];
    [self addTableView];
}

//- (void)didReceiveMemoryWarning {
//    [super didReceiveMemoryWarning];
//    // Dispose of any resources that can be recreated.
//}
//
//- (void)viewWillAppear:(BOOL)animated
//{
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
//}
//
//- (void)viewWillDisappear:(BOOL)animated
//{
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
//}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NCEAcademyCell *cell=[tableView dequeueReusableCellWithIdentifier:kWordSearchViewControllerCellReuseId forIndexPath:indexPath];
    
    NSDictionary *item=_items[indexPath.row];
    [cell configureTitle:[NCEWordResourceStore.sharedStore displayNameForWord:item[@"english"]] subtitle:item[@"chinese"] badge:nil symbol:@"speaker.wave.2"];
    cell.accessibilityIdentifier=[@"search-word-" stringByAppendingString:item[@"english"]];

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
#pragma mark UITableViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.dragging) [self dismissKeyBoard];
}


#pragma mark -
#pragma mark UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    searchBar.placeholder = NCELocalizedString(@"单词或释义");
    //_items = nil;
    //self.tableView.backgroundView=_items.count ? nil : NCEEmptyState(NCELocalizedString(@"没有找到这个单词"),NCELocalizedString(@"试试英文拼写，或换一个释义关键词。"));
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    _items = nil;
    if (searchText.length > 0)
    {
        _items = [[NSMutableArray alloc] init];
        for (NSDictionary *dic in _originData) {
            if ([self wordItem:dic matchesSearchText:searchText]) {
                [_items addObject:dic];
            }
        }
    }
    else //search word is empty
    {
        _items = [_originData copy];
    }
    
    self.tableView.backgroundView=_items.count ? nil : NCEEmptyState(NCELocalizedString(@"没有找到这个单词"),NCELocalizedString(@"试试英文拼写，或换一个释义关键词。"));
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    
    _items = nil;
    _items = [[NSMutableArray alloc] init];
    
    for (NSDictionary *dic in _originData) {
        if ([self wordItem:dic matchesSearchText:searchBar.text]) {
            [_items addObject:dic];
        }
    }
    
    self.tableView.backgroundView=_items.count ? nil : NCEEmptyState(NCELocalizedString(@"没有找到这个单词"),NCELocalizedString(@"试试英文拼写，或换一个释义关键词。"));
    [self.tableView reloadData];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    
    searchBar.text = nil;
    
    _items = nil;
    _items = [_originData copy];
    
    self.tableView.backgroundView=_items.count ? nil : NCEEmptyState(NCELocalizedString(@"没有找到这个单词"),NCELocalizedString(@"试试英文拼写，或换一个释义关键词。"));
    [self.tableView reloadData];
}

#pragma mark -
#pragma mark Private Methods

- (BOOL)wordItem:(NSDictionary *)item matchesSearchText:(NSString *)text
{
    if (!text.length) return YES;
    NSString *word = item[@"english"];
    NSString *display = [NCEWordResourceStore.sharedStore displayNameForWord:word];
    NSString *simplified = item[@"simplified"];
    NSString *traditional = [NCELocalization.sharedLocalization traditionalChineseText:simplified];
    NSString *sourceMeaning = [NCEWordResourceStore.sharedStore sourceTranslationForWord:word fallback:simplified];
    NSString *traditionalMeaning = [NCELocalization.sharedLocalization traditionalChineseText:sourceMeaning];
    NSString *localizedMeaning = [NCEWordResourceStore.sharedStore translationForWord:word fallback:simplified];
    for (NSString *candidate in @[word, display, simplified, traditional, sourceMeaning, traditionalMeaning, localizedMeaning ?: @""]) {
        if ([candidate rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    return NO;
}

- (void)initData
{
    sqlite3 *database;
    NSString *dbPath = [[NSBundle mainBundle] pathForResource:@"data/NCE" ofType:@"db"];
    
    if (sqlite3_open([dbPath UTF8String], &database) == SQLITE_OK) {
        //        NSLog(@"ok");
    }
    
    NSString *selectSql = [NSString stringWithFormat:@"select `word_name`,`word_translation`,`lesson_id` from words where book_id=%d order by `word_name`", _bookId+1];
    
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //        NSLog(@"select ok.");
    }
    
    while (sqlite3_step(statement)==SQLITE_ROW) {
        NSMutableDictionary *item = [[NSMutableDictionary alloc] initWithCapacity:3];
        
        NSString *englishString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
        [item setObject:englishString forKey:@"english"];
        
        NSString *chineseString = [[NSString alloc] initWithCString:(char *)sqlite3_column_text(statement, 1) encoding:NSUTF8StringEncoding];
        [item setObject:chineseString forKey:@"simplified"];
        [item setObject:[[NCEWordResourceStore sharedStore] translationForWord:englishString fallback:chineseString] forKey:@"chinese"];
        
        NSString *lessonId = [NSString stringWithFormat:@"%d",sqlite3_column_int(statement, 2)];
        [item setObject:lessonId forKey:@"lesson_id"];
        item[@"book_id"]=@(_bookId+1);
        
        [_originData addObject:item];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
    
    _items = [_originData copy];
}

- (void)addSearchBar
{
    _searchBar=[[UISearchBar alloc] initWithFrame:CGRectZero];
    _searchBar.placeholder=NCELocalizedString(@"搜索单词或释义");
    _searchBar.delegate=self; _searchBar.searchBarStyle=UISearchBarStyleMinimal;
    _searchBar.tintColor=NCEBlue();_searchBar.searchTextField.backgroundColor=NCESurface();
    _searchBar.searchTextField.textColor=NCEInk();_searchBar.searchTextField.font=NCEFont(16,UIFontWeightRegular);
    _searchBar.showsCancelButton=NO;
    [self.view addSubview:_searchBar];
}


- (void)dismissKeyBoard
{
    [_searchBar resignFirstResponder];
}

- (void)addTableView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:view];
    
    self.viewType = ViewType_Searchs;
    
    CGRect tableViewFrame = [self getTableViewFrame];
    self.tableView = [[UITableView alloc] initWithFrame:tableViewFrame style:UITableViewStylePlain];
    
    self.tableView.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    [self.tableView registerClass:[NCEAcademyCell class]
           forCellReuseIdentifier:kWordSearchViewControllerCellReuseId];
    
    NCEPrepareTable(self.tableView);
    [self.view addSubview:self.tableView];
    
    [_hud hideAnimated:YES];
}

- (void)layoutAcademyViews
{
    CGRect frame=[self academyContentFrame];
    _searchBar.frame=CGRectMake(frame.origin.x+8,frame.origin.y+4,frame.size.width-16,56);
}

@end

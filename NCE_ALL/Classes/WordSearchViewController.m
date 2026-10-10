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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kWordSearchViewControllerCellReuseId
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
    
    NSDictionary *item = [_items objectAtIndex:indexPath.row];
    cell.accessibilityIdentifier = [@"search-word-" stringByAppendingString:item[@"english"]];
    
    // english title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.f, height/12, tableView.frame.size.width-height, height/2)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14*height/50];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = [[NCEWordResourceStore sharedStore] displayNameForWord:item[@"english"]];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [cell.contentView addSubview:titleLabel];
    
    // chinese title
    UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.f, height*7/12, tableView.frame.size.width-height, height*5/12)];
    subTitleLabel.backgroundColor = [UIColor clearColor];
    subTitleLabel.font = [UIFont systemFontOfSize:12*height/50];
    subTitleLabel.textColor = [UIColor darkGrayColor];
    subTitleLabel.text = [item objectForKey:@"chinese"];
    subTitleLabel.textAlignment = NSTextAlignmentLeft;
    subTitleLabel.numberOfLines = 2;
    subTitleLabel.adjustsFontSizeToFitWidth = YES;
    subTitleLabel.minimumScaleFactor = 0.65;
    [cell.contentView addSubview:subTitleLabel];
    
    // show when the cell is selected
    UIView *maskView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, tableView.frame.size.width, height)];
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
    if ([tableView respondsToSelector:@selector(setSeparatorInset:)])
    {
        [tableView setSeparatorInset:UIEdgeInsetsZero];
    }
    
    else if ([tableView respondsToSelector:@selector(setLayoutMargins:)])
    {
        [tableView setLayoutMargins:UIEdgeInsetsZero];
    }
    
    else if ([cell respondsToSelector:@selector(setLayoutMargins:)])
    {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

#pragma mark -
#pragma mark UITableViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self dismissKeyBoard];
}

#pragma mark -
#pragma mark UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    searchBar.placeholder = NCELocalizedString(@"单词或释义");
    //_items = nil;
    //[self.tableView reloadData];
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
    
    [self.tableView reloadData];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    
    searchBar.text = nil;
    
    _items = nil;
    _items = [_originData copy];
    
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
        
        [_originData addObject:item];
    }
    
    sqlite3_finalize(statement);
    sqlite3_close(database);
    
    _items = [_originData copy];
}

- (void)addSearchBar
{
    CGRect barframe = CGRectMake(0.f, [self getHeaderPosY], self.view.frame.size.width, 40.f);
    _searchBar = [[UISearchBar alloc] initWithFrame:barframe];
    _searchBar.placeholder = NCELocalizedString(@"搜索单词或释义");
    _searchBar.backgroundColor = [UIColor colorWithRed:156/255.f
                                                 green:229/255.f
                                                  blue:201/255.f
                                                 alpha:1.f];
    _searchBar.backgroundImage = [UIImage imageNamed:@"clear"];
    _searchBar.delegate = self;
    
    _searchBar.showsCancelButton = YES;
    UIColor* itemColor = [UIColor colorWithRed:23/255.f green:191/255.f blue:169/255.f alpha:1.f];
    NSDictionary* dicts = [NSDictionary dictionaryWithObjectsAndKeys: itemColor, NSForegroundColorAttributeName,
                           [UIFont systemFontOfSize:14.f], NSFontAttributeName, nil];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[UIBarButtonItem appearanceWhenContainedIn:[UISearchBar class], nil] setTitle:NCELocalizedString(@"取消")];
    [[UIBarButtonItem appearanceWhenContainedIn:[UISearchBar class], nil] setTitleTextAttributes:dicts forState:UIControlStateNormal];
#pragma clang diagnostic pop
    
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
    
    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:kWordSearchViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
    
    [_hud hideAnimated:YES];
}

@end

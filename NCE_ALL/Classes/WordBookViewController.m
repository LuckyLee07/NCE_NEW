#import "WordBookViewController.h"
#import "NCEStudyStore.h"
#import "NCEStudyViews.h"
#import "NCEPracticeViewController.h"
#import "WordViewController.h"
#import "NCEWordResourceStore.h"

@interface WordBookViewController () <UITableViewDelegate,UITableViewDataSource,UISearchBarDelegate>
@end
@implementation WordBookViewController {
    NSInteger _book;
    NSArray *_words,*_visible;
    UITableView *_table;
    UIView *_header;
    NCEVolumeControl *_volume;
    UISearchBar *_search;
    UISegmentedControl *_filters;
    UILabel *_count;
    UIButton *_review;
}
- (id)initWithBookId:(int)bookId withTitle:(NSString *)title {if((self=[super init])){_book=bookId;self.titleString=title;}return self;}
- (void)viewDidLoad {
    [super viewDidLoad];self.navigationController.navigationBar.prefersLargeTitles=YES;self.navigationItem.largeTitleDisplayMode=UINavigationItemLargeTitleDisplayModeAlways;_table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];NCEPrepareTable(_table);_table.separatorStyle=UITableViewCellSeparatorStyleSingleLine;_table.delegate=self;_table.dataSource=self;_table.rowHeight=UITableViewAutomaticDimension;_table.estimatedRowHeight=76;_table.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;[_table registerClass:NCEStudyRow.class forCellReuseIdentifier:@"word"];[self.view addSubview:_table];
    _header=[UIView new];_volume=[NCEVolumeControl new];[_volume addTarget:self action:@selector(pickBook) forControlEvents:UIControlEventTouchUpInside];[_header addSubview:_volume];_volume.hidden=!self.showsBookSwitcher;
    _search=[UISearchBar new];_search.searchBarStyle=UISearchBarStyleMinimal;_search.placeholder=NCELocalizedString(@"搜索单词或释义");_search.delegate=self;_search.accessibilityIdentifier=@"wordbook-search";[_header addSubview:_search];
    _filters=[[UISegmentedControl alloc] initWithItems:@[NCELocalizedString(@"全部"),NCELocalizedString(@"待复习"),NCELocalizedString(@"熟悉"),NCELocalizedString(@"错词"),NCELocalizedString(@"收藏")]];_filters.selectedSegmentIndex=0;_filters.accessibilityIdentifier=@"wordbook-filters";[_filters addTarget:self action:@selector(filter) forControlEvents:UIControlEventValueChanged];[_header addSubview:_filters];
    _count=NCELabel(nil,13,UIFontWeightRegular,NCEMuted());[_header addSubview:_count];[self.view addSubview:_header];
    _review=NCEButton(NCELocalizedString(@"开始复习"),@"arrow.right",YES,self,@selector(review));_review.accessibilityIdentifier=@"wordbook-review";[self.view addSubview:_review];
}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];if(self.showsBookSwitcher)_book=[NCEStudyStore selectedBook];_volume.book=_book;_words=[NCEStudyStore wordsForBook:_book lesson:0];[self filter];}
- (void)filter {
    NSInteger filter=_filters.selectedSegmentIndex;NSString *query=[_search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    _visible=[_words filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *word,NSDictionary *bindings){NSInteger status=[word[@"status"] integerValue];BOOL selected=filter==0 || (filter==1 && (status==1 || status==3)) || (filter==2 && status==2) || (filter==3 && [word[@"wrong"] boolValue]) || (filter==4 && [NCEStudyStore isBookmarked:word]);return selected && (!query.length || [[NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]] localizedCaseInsensitiveContainsString:query] || [[NCEStudyStore meaningForWord:word] localizedCaseInsensitiveContainsString:query]);}]];
    _count.text=[NSString stringWithFormat:NCELocalizedString(@"%@ 个单词"),@(_visible.count)];_review.hidden=_visible.count==0;_review.enabled=_visible.count>0;
    _table.backgroundView=nil;
    if(!_visible.count){BOOL emptyWrong=filter==3 && !query.length;NCEStudyEmptyView *empty=[[NCEStudyEmptyView alloc] initWithSymbol:query.length ? @"magnifyingglass" : @"bookmark" title:NCELocalizedString(emptyWrong ? @"暂无错词" : query.length ? @"没有找到单词" : @"这里还没有单词") message:NCELocalizedString(emptyWrong ? @"练习中答错的单词会出现在这里。" : query.length ? @"试试其他拼写或释义。" : @"学习时标记或收藏单词，就能在这里复习。") action:NCELocalizedString(emptyWrong ? @"查看本册课程" : @"查看全部") target:self selector:emptyWrong ? @selector(showCourses) : @selector(clearFilters)];empty.frame=CGRectMake(0,0,_table.bounds.size.width,260);_table.tableFooterView=empty;}else _table.tableFooterView=[UIView new];
    [_table reloadData];[self.view setNeedsLayout];
}
- (void)showCourses {self.tabBarController.selectedIndex=1;}
- (void)clearFilters {_search.text=@"";_filters.selectedSegmentIndex=0;[self.view endEditing:YES];[self filter];}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {[self filter];}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {[searchBar resignFirstResponder];}
- (void)pickBook {NCEShowBookPicker(self,_book,^(NSInteger book){self->_book=book;[NCEStudyStore selectBook:book];self->_volume.book=book;self->_search.text=@"";self->_words=[NCEStudyStore wordsForBook:book lesson:0];[self filter];});}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return _visible.count;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *word=_visible[indexPath.row];NCEStudyRow *cell=[tableView dequeueReusableCellWithIdentifier:@"word" forIndexPath:indexPath];
    [cell configureTitle:[NCEWordResourceStore.sharedStore displayNameForWord:word[@"english"]] subtitle:[NCEStudyStore meaningForWord:word] number:nil current:NO];cell.accessibilityIdentifier=[@"wordbook-word-" stringByAppendingString:word[@"english"]];return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {[self.view endEditing:YES];WordViewController *page=[[WordViewController alloc] initWithData:_visible withIndex:(int)indexPath.row];page.titleString=NCELocalizedString(@"单词本");[self.navigationController pushViewController:page animated:YES];}
- (void)review {if(!_visible.count)return;[self.view endEditing:YES];NCEPracticeViewController *page=[[NCEPracticeViewController alloc] initWithWords:_visible key:[NSString stringWithFormat:@"wordbook-%ld-%ld-%@",(long)_book,(long)_filters.selectedSegmentIndex,_search.text ?: @""] mode:0];[self.navigationController pushViewController:page animated:YES];}
- (void)layoutAcademyViews {
    CGRect frame=[self academyContentFrame];CGFloat w=frame.size.width,y=0;
    if(self.showsBookSwitcher){CGFloat h=[_volume sizeThatFits:CGSizeMake(w-48,CGFLOAT_MAX)].height;_volume.frame=CGRectMake(24,0,w-48,h);y=h+8;}
    _search.frame=CGRectMake(16,y,w-32,52);y+=64;
    _filters.frame=CGRectMake(24,y,w-48,44);y+=60;
    _count.frame=CGRectMake(24,y,w-48,24);y+=36;
    CGFloat reviewHeight=_review.hidden ? 0 : 72;
    BOOL compact=frame.size.height<y+reviewHeight+150 || UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
    if(compact){
        BOOL headerChanged=_table.tableHeaderView!=_header || fabs(_header.bounds.size.height-y)>0.5 || fabs(_header.bounds.size.width-w)>0.5;
        _header.frame=CGRectMake(0,0,w,y);
        if(headerChanged)_table.tableHeaderView=_header;
        _table.frame=CGRectMake(frame.origin.x,frame.origin.y,w,MAX(0,frame.size.height-reviewHeight));
    }else{
        if(_table.tableHeaderView){_table.tableHeaderView=nil;[self.view addSubview:_header];}
        _header.frame=CGRectMake(frame.origin.x,frame.origin.y,w,y);
        _table.frame=CGRectMake(frame.origin.x,frame.origin.y+y,w,MAX(0,frame.size.height-y-reviewHeight));
    }
    _review.frame=CGRectMake(frame.origin.x+24,CGRectGetMaxY(frame)-56,w-48,52);
}
@end

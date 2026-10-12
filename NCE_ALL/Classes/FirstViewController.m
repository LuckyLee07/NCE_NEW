#import "FirstViewController.h"
#import "NCEStudyStore.h"
#import "NCEStudyViews.h"
#import "NCECourseViewController.h"
#import "WordBookViewController.h"
#import "SettingViewController.h"

@interface FirstViewController () <UITableViewDelegate,UITableViewDataSource,UISearchBarDelegate>
@property(nonatomic) BOOL libraryOnly;
@end
@implementation FirstViewController {
    NSInteger _book;
    NSArray *_lessons,*_visible,*_recent;
    NSDictionary *_resume;
    UITableView *_table;
    UIView *_header;
    NCEVolumeControl *_volume;
    UISearchBar *_search;
    UILabel *_eyebrow,*_lessonTitle,*_lessonSubtitle,*_sectionLabel;
    UIButton *_continueButton,*_allLessons,*_wordsShortcut,*_practiceShortcut;
}
- (instancetype)init {if((self=[super init]))self.hidesBottomBarWhenPushed=NO;return self;}
- (void)viewDidLoad {
    self.bannerHeight=_libraryOnly ? [self getDefaultBottomHeight] : 0;
    self.titleString=NCELocalizedString(_libraryOnly ? @"课程" : @"学习");[super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles=YES;self.navigationItem.largeTitleDisplayMode=UINavigationItemLargeTitleDisplayModeAlways;
    UIButton *settings=NCEButton(nil,@"gearshape",NO,self,@selector(settings));settings.frame=CGRectMake(0,0,44,44);settings.accessibilityLabel=NCELocalizedString(@"设置");settings.accessibilityIdentifier=@"settings";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithCustomView:settings];if(@available(iOS 26.0,*))self.navigationItem.rightBarButtonItem.hidesSharedBackground=YES;
    _table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];_table.delegate=self;_table.dataSource=self;_table.rowHeight=UITableViewAutomaticDimension;_table.estimatedRowHeight=82;_table.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;NCEPrepareTable(_table);_table.separatorStyle=UITableViewCellSeparatorStyleSingleLine;[_table registerClass:NCEStudyRow.class forCellReuseIdentifier:@"lesson"];_table.accessibilityIdentifier=_libraryOnly ? @"course-library" : @"learning-home";[self.view addSubview:_table];
    _header=[UIView new];_volume=[NCEVolumeControl new];[_volume addTarget:self action:@selector(pickBook) forControlEvents:UIControlEventTouchUpInside];[_header addSubview:_volume];
    if(_libraryOnly){_search=[UISearchBar new];_search.placeholder=NCELocalizedString(@"搜索课号或标题");_search.searchBarStyle=UISearchBarStyleMinimal;_search.delegate=self;_search.accessibilityIdentifier=@"lesson-search";[_header addSubview:_search];}
    else{
        _eyebrow=NCELabel(nil,14,UIFontWeightSemibold,NCEBlue());_lessonTitle=NCELabel(nil,28,UIFontWeightBold,NCEInk());_lessonSubtitle=NCELabel(nil,14,UIFontWeightRegular,NCEMuted());
        _continueButton=NCEButton(nil,@"play.fill",YES,self,@selector(continueLearning));_continueButton.accessibilityIdentifier=@"home-continue";
        _wordsShortcut=NCEButton(NCELocalizedString(@"本课单词"),@"list.bullet",NO,self,@selector(openWords));_wordsShortcut.accessibilityIdentifier=@"home-words";
        _practiceShortcut=NCEButton(NCELocalizedString(@"本课练习"),@"pencil",NO,self,@selector(openPractice));_practiceShortcut.accessibilityIdentifier=@"home-practice";
        _allLessons=NCEButton(NCELocalizedString(@"全部课程"),@"arrow.right",NO,self,@selector(showLibrary));_allLessons.accessibilityIdentifier=@"home-all-lessons";
        for(UIView *v in @[_eyebrow,_lessonTitle,_lessonSubtitle,_continueButton,_allLessons,_wordsShortcut,_practiceShortcut])[_header addSubview:v];
    }
    _sectionLabel=NCELabel(NCELocalizedString(_libraryOnly ? @"课程目录" : @"最近学习"),18,UIFontWeightSemibold,NCEInk());[_header addSubview:_sectionLabel];_table.tableHeaderView=_header;
}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self reload];}
- (void)addBanner {if(_libraryOnly)[super addBanner];}
- (void)reload {
    _book=[NCEStudyStore selectedBook];_volume.book=_book;_lessons=[NCEStudyStore lessonsForBook:_book];_resume=[NCEStudyStore resumeForBook:_book];_recent=[NCEStudyStore recentLessonsForBook:_book];_allLessons.hidden=_recent.count==0;
    NSDictionary *lesson=_resume[@"lesson"] ?: _lessons.firstObject;
    _eyebrow.text=NCELocalizedString(_resume ? @"继续学习" : @"从第一课开始");_lessonTitle.text=[NCEStudyStore lessonTitle:lesson];_lessonSubtitle.text=[NSString stringWithFormat:@"%@ · %@",[NSString stringWithFormat:NCELocalizedString(@"第%@课"),lesson[@"id"] ?: @"1"],[NCEStudyStore lessonTranslation:lesson]];
    NCESetButtonTitle(_continueButton,NCELocalizedString(_resume ? @"继续听读" : @"开始学习"));[self filter];[self.view setNeedsLayout];
}
- (void)filter {
    NSString *query=[_search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
    _visible=[_lessons filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *lesson,NSDictionary *bindings){return !query.length || [[NCEStudyStore lessonTitle:lesson] localizedCaseInsensitiveContainsString:query] || [[NCEStudyStore lessonTranslation:lesson] localizedCaseInsensitiveContainsString:query] || [lesson[@"name"] localizedCaseInsensitiveContainsString:query] || [lesson[@"id"] isEqual:query];}]];
    BOOL empty=_libraryOnly ? !_visible.count : !_recent.count;
    _table.backgroundView=empty ? [[NCEStudyEmptyView alloc] initWithSymbol:_libraryOnly ? @"magnifyingglass" : @"book" title:NCELocalizedString(_libraryOnly ? @"没有找到课程" : @"还没有学习记录") message:NCELocalizedString(_libraryOnly ? @"试试课号或英文标题。" : @"开始一课后，这里会留下你的足迹。") action:nil target:nil selector:NULL] : nil;
    // Home's first-use message belongs below its introduction, not behind the table header.
    if(empty && _libraryOnly){_table.backgroundView=nil;NCEStudyEmptyView *emptyView=[[NCEStudyEmptyView alloc] initWithSymbol:@"magnifyingglass" title:NCELocalizedString(@"没有找到课程") message:NCELocalizedString(@"试试课号或英文标题。") action:NCELocalizedString(@"清除搜索") target:self selector:@selector(clearSearch)];emptyView.frame=CGRectMake(0,0,_table.bounds.size.width,230);_table.tableFooterView=emptyView;}else if(empty && !_libraryOnly){_table.backgroundView=nil;UILabel *tip=NCELabel(NCELocalizedString(@"开始一课后，这里会留下你的足迹。"),14,UIFontWeightRegular,NCEMuted());tip.frame=CGRectMake(0,0,_table.bounds.size.width,70);tip.textAlignment=NSTextAlignmentCenter;_table.tableFooterView=tip;}else _table.tableFooterView=[UIView new];
    [_table reloadData];
}
- (void)clearSearch {_search.text=@"";[self.view endEditing:YES];[self filter];}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {[self filter];}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {[searchBar resignFirstResponder];}
- (void)pickBook {NCEShowBookPicker(self,_book,^(NSInteger book){[NCEStudyStore selectBook:book];self->_search.text=@"";[self reload];});}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {return _libraryOnly ? _visible.count : MIN(5,_recent.count);}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *lesson=_libraryOnly ? _visible[indexPath.row] : _recent[indexPath.row][@"lesson"];
    NCEStudyRow *cell=[tableView dequeueReusableCellWithIdentifier:@"lesson" forIndexPath:indexPath];BOOL current=[lesson[@"id"] isEqual:_resume[@"lesson"][@"id"]];
    NSString *detail=[NCEStudyStore lessonTranslation:lesson];if(current)detail=[detail stringByAppendingFormat:@" · %@",NCELocalizedString(@"上次学到")];
    [cell configureTitle:[NCEStudyStore lessonTitle:lesson] subtitle:detail number:[NSString stringWithFormat:@"%03d",[lesson[@"id"] intValue]] current:current];cell.accessibilityIdentifier=[NSString stringWithFormat:@"lesson-%@",lesson[@"id"]];return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {[self openLesson:_libraryOnly ? _visible[indexPath.row] : _recent[indexPath.row][@"lesson"]];}
- (void)openLesson:(NSDictionary *)lesson {if(!lesson)return;[self.view endEditing:YES];[self.navigationController pushViewController:[[NCECourseViewController alloc] initWithBook:_book lesson:lesson section:0] animated:YES];}
- (void)openWords {[self openSection:1];}
- (void)openPractice {[self openSection:2];}
- (void)openSection:(NSInteger)section {NSDictionary *lesson=_resume[@"lesson"] ?: _lessons.firstObject;if(lesson)[self.navigationController pushViewController:[[NCECourseViewController alloc] initWithBook:_book lesson:lesson section:section] animated:YES];}
- (void)continueLearning {[self openLesson:_resume[@"lesson"] ?: _lessons.firstObject];}
- (void)showLibrary {self.tabBarController.selectedIndex=1;}
- (void)settings {[self.navigationController pushViewController:[SettingViewController new] animated:YES];}
- (void)layoutAcademyViews {
    CGRect frame=[self academyContentFrame];_table.frame=frame;CGFloat w=frame.size.width,x=24,inner=w-48,y=0;
    CGFloat volumeHeight=[_volume sizeThatFits:CGSizeMake(inner,CGFLOAT_MAX)].height;_volume.frame=CGRectMake(x,y,inner,volumeHeight);y+=volumeHeight+16;
    if(_libraryOnly){_search.frame=CGRectMake(16,y,w-32,52);y+=72;}
    else{for(UILabel *label in @[_eyebrow,_lessonTitle,_lessonSubtitle]){CGFloat h=NCETextHeight(label.text,label.font,inner);label.frame=CGRectMake(x,y,inner,h);y+=h+12;}y+=6;_continueButton.frame=CGRectMake(x,y,inner,52);y+=62;_wordsShortcut.frame=CGRectMake(x,y,inner/2-4,44);_practiceShortcut.frame=CGRectMake(x+inner/2+4,y,inner/2-4,44);y+=64;_allLessons.frame=CGRectMake(w-154,y-6,130,36);}
    CGFloat h=NCETextHeight(_sectionLabel.text,_sectionLabel.font,inner);_sectionLabel.frame=CGRectMake(x,y,inner,h);y+=h+16;
    if(fabs(_header.bounds.size.height-y)>0.5 || _header.bounds.size.width!=w){_header.frame=CGRectMake(0,0,w,y);_table.tableHeaderView=_header;}
}
@end
UITabBarController *NCECreateLearningRoot(void)
{
    UITabBarController *tabs=[UITabBarController new];
    FirstViewController *home=[FirstViewController new];
    FirstViewController *library=[FirstViewController new]; library.libraryOnly=YES;
    NSInteger book=MIN(3,MAX(0,[NSUserDefaults.standardUserDefaults integerForKey:@"NCEAcademyBook"]));
    WordBookViewController *words=[[WordBookViewController alloc] initWithBookId:(int)book withTitle:NCELocalizedString(@"单词本")];
    words.showsBookSwitcher=YES; words.hidesBottomBarWhenPushed=NO;
    NSArray *titles=@[@"学习",@"课程",@"单词本"], *symbols=@[@"book.closed",@"books.vertical",@"square.and.pencil"];
    NSMutableArray *controllers=[NSMutableArray new];
    for(NSInteger index=0;index<3;index++) {
        UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:@[home,library,words][index]];
        navigation.tabBarItem=[[UITabBarItem alloc] initWithTitle:NCELocalizedString(titles[index]) image:[UIImage systemImageNamed:symbols[index]] tag:index];
        navigation.tabBarItem.accessibilityIdentifier=[NSString stringWithFormat:@"home-tab-%ld",(long)index];
        [controllers addObject:navigation];
    }
    UITabBarAppearance *appearance=[UITabBarAppearance new];
    [appearance configureWithOpaqueBackground]; appearance.backgroundColor=NCEBackground(); appearance.shadowColor=NCELine();
    tabs.tabBar.standardAppearance=appearance; tabs.tabBar.scrollEdgeAppearance=appearance;
    tabs.tabBar.tintColor=NCEBlue(); tabs.tabBar.unselectedItemTintColor=NCEMuted();
    tabs.viewControllers=controllers;
    if (@available(iOS 18.0,*)) tabs.mode=UITabBarControllerModeTabBar;
    return tabs;
}

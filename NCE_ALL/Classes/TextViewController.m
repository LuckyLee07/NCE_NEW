//
//  TextViewController.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "TextViewController.h"
#import "sqlite3.h"
#import "AdmobManager.h"
#import <AVFoundation/AVFoundation.h>

static NSString* const kTextViewControllerCellReuseId = @"kTextViewControllerCellReuseId";

@interface TextViewController () <UITableViewDataSource, UITableViewDelegate, AVAudioPlayerDelegate, UIAlertViewDelegate>
{
    int _bookId;
    NSMutableArray *_items;
    NSDictionary *_lesson;
    
    BOOL _showChinese;
    
    NSMutableDictionary *_contentDictionary;
    
    AVAudioPlayer *_audioPlayer;
    int _currentIndex;    
    int _learnedCount;
    
    UIButton *_continueButton;
    UIButton *_pauseButton;
    
    UISlider *_contentSlider;
    UIButton *_circleButton;
}

@property (nonatomic, strong) UITableView *tableView;

//@property (nonatomic, strong) GADInterstitial *interstitial;
//@property (nonatomic, assign) NSInteger showTimes;

- (void)initData;
- (void)addTableView;
- (void)addRightButton;
- (void)showChinese:(UIButton *)button;
- (NSDictionary *)getContentItem:(NSUInteger)item;

@end

@implementation TextViewController

- (id)initWithBookId:(int)bookId withLesson:(NSDictionary *)lesson
{
    self = [super init];
    if (self) {
        _bookId = bookId;
        _lesson = lesson;
        
        NSArray *lessonArray = [[lesson objectForKey:@"name"] componentsSeparatedByString:@"－"];
        self.titleString = [NSString stringWithFormat:@"%@－%@",lessonArray[0], lessonArray[1]];
        
        [self initData];
        
        _showChinese = YES;
        
        _contentDictionary = [[NSMutableDictionary alloc] initWithCapacity:5];
        
        _currentIndex = 0;
        _learnedCount = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //self.showTimes = 1;
    
    [self addTableView];
    
    [self addRightButton];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_currentIndex inSection:0];
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
    
    [self addBottomView];
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTextViewControllerCellReuseId
                                                            forIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSArray *array = [cell.contentView subviews];
    for (UIView *view in array) {
        [view removeFromSuperview];
    }
    CGFloat headerHeight = [self getConstHeight];
    CGFloat height = (tableView.frame.size.height-headerHeight)/8;
    NSDictionary *contentItem = [self getContentItem:indexPath.row];
    
    // englist title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height/3, height/12, tableView.frame.size.width-height*2/3, [[contentItem objectForKey:@"englishHeight"] floatValue])];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.font = [UIFont systemFontOfSize:14*height/50];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.text = [contentItem objectForKey:@"english"];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.numberOfLines = 0;
    titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    titleLabel.tag = 100+indexPath.row;
    [titleLabel sizeToFit];
    [cell.contentView addSubview:titleLabel];
    
    // chinese title
    UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(height/3, height/6+[[contentItem objectForKey:@"englishHeight"] floatValue], tableView.frame.size.width-height*2/3, [[contentItem objectForKey:@"chineseHeight"] floatValue])];
    subTitleLabel.backgroundColor = [UIColor clearColor];
    subTitleLabel.font = [UIFont systemFontOfSize:12*height/50];
    subTitleLabel.textColor = [UIColor darkGrayColor];
    subTitleLabel.text = [contentItem objectForKey:@"chinese"];
    subTitleLabel.textAlignment = NSTextAlignmentLeft;
    subTitleLabel.numberOfLines = 0;
    subTitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    subTitleLabel.tag = 10000+indexPath.row;
    [titleLabel sizeToFit];
    [cell.contentView addSubview:subTitleLabel];
    if (!_showChinese) subTitleLabel.hidden = YES;;
    
    // show when the cell is selected
    UIView *maskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, cell.frame.size.height)];
    maskView.backgroundColor = [UIColor clearColor];
    maskView.tag = 1000+indexPath.row;
    [cell.contentView addSubview:maskView];
    
    if (_currentIndex == indexPath.row) {
        maskView.backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.1f];
        titleLabel.textColor = [UIColor colorWithRed:16/255.f
                                               green:165/255.f
                                                blue:79/255.f
                                               alpha:1.f];
        subTitleLabel.textColor = [UIColor colorWithRed:16/255.f
                                                  green:165/255.f
                                                   blue:79/255.f
                                                  alpha:0.7f];
    }
    
    return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *contentItem = [self getContentItem:indexPath.row];
    
    CGFloat contentHeight = [[contentItem objectForKey:@"englishHeight"] floatValue]+[[contentItem objectForKey:@"chineseHeight"] floatValue];
    
    return contentHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.view viewWithTag:1000+_currentIndex].backgroundColor = [UIColor clearColor];
    [self.view viewWithTag:1000+indexPath.row].backgroundColor = [UIColor colorWithWhite:0.3f alpha:0.1f];
    
    UILabel *lastTitle = (UILabel *)[self.view viewWithTag:100+_currentIndex];
    lastTitle.textColor = [UIColor darkGrayColor];
    UILabel *currentTitle = (UILabel *)[self.view viewWithTag:100+indexPath.row];
    currentTitle.textColor = [UIColor colorWithRed:16/255.f
                                             green:165/255.f
                                              blue:79/255.f
                                             alpha:1.f];
    
    UILabel *lastSubTitle = (UILabel *)[self.view viewWithTag:10000+_currentIndex];
    lastSubTitle.textColor = [UIColor grayColor];
    UILabel *currentSubTitle = (UILabel *)[self.view viewWithTag:10000+indexPath.row];
    currentSubTitle.textColor = [UIColor colorWithRed:16/255.f
                                                green:165/255.f
                                                 blue:79/255.f
                                                alpha:0.7f];
    
    _currentIndex = (int)indexPath.row;
    
    [self play];
    
    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    
    _contentSlider.value = _currentIndex;
    
    _continueButton.hidden = YES;
    _pauseButton.hidden = NO;
}

#pragma mark -
#pragma mark AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (_currentIndex == _items.count-1 && _circleButton.selected) return;
    
    [self.view viewWithTag:1000+_currentIndex].backgroundColor = [UIColor clearColor];
    UILabel *lastTitle = (UILabel *)[self.view viewWithTag:100+_currentIndex];
    lastTitle.textColor = [UIColor darkGrayColor];
    UILabel *lastSubTitle = (UILabel *)[self.view viewWithTag:10000+_currentIndex];
    lastSubTitle.textColor = [UIColor grayColor];
    
    if (_currentIndex < _items.count-1) _currentIndex++;
    else _currentIndex = 0;
    
    NSIndexPath *next = [NSIndexPath indexPathForRow:_currentIndex inSection:0];
    [self tableView:self.tableView didSelectRowAtIndexPath:next];
    
    _learnedCount++;
    if (_learnedCount == _items.count-1) {
        _learnedCount = -1;
        [[AdmobManager sharedInstance] showNativeScene];
    } else if (_learnedCount == 7 && _items.count > 12) {
        [[AdmobManager sharedInstance] showNativeScene];
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
    
    int lessonId = [[_lesson objectForKey:@"id"] intValue];
    NSString *selectSql = [NSString stringWithFormat:@"select `name` from play_list_sentences where lesson_id=%d and book_id=%d order by order_id",lessonId,_bookId+1];
    sqlite3_stmt *statement;
    if (sqlite3_prepare_v2(database, [selectSql UTF8String], -1, &statement, nil)==SQLITE_OK) {
        //                NSLog(@"select ok.");
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
    
    self.viewType = ViewType_Lessons;
    CGRect tableViewFrame = [self getTableViewFrame];
    self.tableView = [[UITableView alloc] initWithFrame:tableViewFrame style:UITableViewStylePlain];
    
    self.tableView.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9f];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    [self.tableView registerClass:[UITableViewCell class]
           forCellReuseIdentifier:kTextViewControllerCellReuseId];
    
    [self.view addSubview:self.tableView];
}

- (void)addRightButton
{
    UIButton *showChineseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    showChineseButton.frame = CGRectMake(0, 0, 40, 40);
    showChineseButton.titleLabel.font = [UIFont systemFontOfSize:14.f];
    [showChineseButton setTitle:@"汉" forState:UIControlStateNormal];
    [showChineseButton setTitle:@"英" forState:UIControlStateSelected];
    [showChineseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [showChineseButton addTarget:self action:@selector(showChinese:) forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:showChineseButton];
}

- (void)showChinese:(UIButton *)button;
{
    button.selected = !button.selected;
    _showChinese = !_showChinese;
    [self.tableView reloadData];
}

- (NSDictionary *)getContentItem:(NSUInteger)item
{
    NSString *name = [_items objectAtIndex:item];
    
    NSDictionary *contentItem = [_contentDictionary objectForKey:name];
    if (!contentItem) {
        NSString *fileName = [NSString stringWithFormat:@"data/lessons/lrc/%@.lrc",name];
        NSString *filePath =  [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
        NSString *contentString = [[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSArray *contentArray = [contentString componentsSeparatedByString:@"－"];
        
        CGFloat height = self.tableView.frame.size.height/8;
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];
        paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
        NSDictionary *attributes = @{NSFontAttributeName:[UIFont systemFontOfSize:14*height/50], NSParagraphStyleAttributeName:paragraphStyle.copy};
        NSDictionary *attributes1 = @{NSFontAttributeName:[UIFont systemFontOfSize:12*height/50], NSParagraphStyleAttributeName:paragraphStyle.copy};
        
        CGSize content0Size = [[contentArray objectAtIndex:0] boundingRectWithSize:CGSizeMake(self.tableView.frame.size.width-height*2/3, MAXFLOAT)
                                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                                        attributes:attributes
                                                                           context:nil].size;
        
        CGSize content1Size = [[contentArray objectAtIndex:1] boundingRectWithSize:CGSizeMake(self.tableView.frame.size.width-height*2/3, MAXFLOAT)
                                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                                        attributes:attributes1
                                                                           context:nil].size;
        
        contentItem = [[NSDictionary alloc] initWithObjectsAndKeys:[contentArray objectAtIndex:0], @"english" ,[contentArray objectAtIndex:1], @"chinese", @(content0Size.height), @"englishHeight", @(content1Size.height), @"chineseHeight", nil];
        
        [_contentDictionary setObject:contentItem forKey:name];
    }
    return contentItem;
}

- (void)play
{
    NSString *fileName = [NSString stringWithFormat:@"data/lessons/mp3/%@.mp3",[_items objectAtIndex:_currentIndex]];
    NSString *filePath =  [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    
    NSLog(@"Fxkk=====>>>%@", filePath);
    
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath] error:nil];
    _audioPlayer.delegate = self;
    [_audioPlayer prepareToPlay];
    [_audioPlayer play];
}

- (void)addBottomView
{
    CGFloat headerHight = [self getPlayViewHeight];
    
    CGFloat bgviewPosy = self.tableView.frame.origin.y + self.tableView.frame.size.height;
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.f, bgviewPosy, self.view.frame.size.width, headerHight)];
    backgroundView.backgroundColor = [UIColor colorWithWhite:1.f alpha:0.9f];
    
    [self.view addSubview:backgroundView];
    
    UIImageView *line = [[UIImageView alloc] initWithFrame:CGRectMake(0.f, 0.5f, self.view.frame.size.width, 0.5f)];
    line.image = [UIImage imageNamed:@"line"];
    [backgroundView addSubview:line];
    
    // prev
    UIButton *prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    prevButton.frame = CGRectMake(self.view.frame.size.width-headerHight*20/9, headerHight*5/18, headerHight*4/9, headerHight*4/9);
    [prevButton setImage:[UIImage imageNamed:@"prev_normal"] forState:UIControlStateNormal];
    [prevButton setImage:[UIImage imageNamed:@"prev_click"] forState:UIControlStateHighlighted];
    [prevButton addTarget:self action:@selector(prev) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:prevButton];
    
    // pause
    _pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _pauseButton.frame = CGRectMake(self.view.frame.size.width-headerHight*15/9, headerHight*2/9, headerHight*5/9, headerHight*5/9);
    [_pauseButton setImage:[UIImage imageNamed:@"pause_normal"] forState:UIControlStateNormal];
    [_pauseButton setImage:[UIImage imageNamed:@"pause_click"] forState:UIControlStateHighlighted];
    [_pauseButton addTarget:self action:@selector(pause) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:_pauseButton];
    
    // continue
    _continueButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _continueButton.frame = CGRectMake(self.view.frame.size.width-headerHight*15/9, headerHight*2/9, headerHight*5/9, headerHight*5/9);
    [_continueButton setImage:[UIImage imageNamed:@"play_normal"] forState:UIControlStateNormal];
    [_continueButton setImage:[UIImage imageNamed:@"play_click"] forState:UIControlStateHighlighted];
    [_continueButton addTarget:self action:@selector(continue) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:_continueButton];
    _continueButton.hidden = YES;
    
    // next
    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    nextButton.frame = CGRectMake(self.view.frame.size.width-headerHight*7/9, headerHight*5/18, headerHight*4/9, headerHight*4/9);
    [nextButton setImage:[UIImage imageNamed:@"next_normal"] forState:UIControlStateNormal];
    [nextButton setImage:[UIImage imageNamed:@"next_click"] forState:UIControlStateHighlighted];
    [nextButton addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:nextButton];
    
    // init and add the content slider
    CGSize size = CGSizeMake(headerHight/9, headerHight/9);
    
    UIImage *leftImage = [UIImage imageNamed:@"progressBar_left"];
    UIImage *newLeftImage = [self OriginImage:leftImage scaleToSize:size];
    
    UIImage *rightImage = [UIImage imageNamed:@"progressBar_right"];
    UIImage *newRightImage = [self OriginImage:rightImage scaleToSize:size];
    
    UIImage *bgImage = [UIImage imageNamed:@"progressBar_bg"];
    UIImage *newbgImage = [self OriginImage:bgImage scaleToSize:size];
    
    _contentSlider = [[UISlider alloc] initWithFrame:CGRectMake(headerHight*10/9, headerHight*4/9, self.view.frame.size.width-headerHight*33/9, headerHight/9)];
    _contentSlider.maximumValue = (float)_items.count-1;
    _contentSlider.minimumValue = 0.f;
    _contentSlider.value = 0.f;
    [_contentSlider setMinimumTrackImage:[newLeftImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, newLeftImage.size.height*0.4, 0, newLeftImage.size.height*0.4)] forState:UIControlStateNormal];
    [_contentSlider setMaximumTrackImage:[newbgImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, newbgImage.size.height*0.4, 0, newbgImage.size.height*0.4)] forState:UIControlStateNormal];
    [_contentSlider setThumbImage:newRightImage forState:UIControlStateNormal];
    [_contentSlider setThumbImage:newRightImage forState:UIControlStateHighlighted];
    [_contentSlider addTarget:self action:@selector(gotoContentItem:) forControlEvents:UIControlEventValueChanged];
    [backgroundView addSubview:_contentSlider];
    
    // init playing circle setting
    _circleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _circleButton.frame = CGRectMake(headerHight/3, headerHight*5/18, headerHight*4/9, headerHight*4/9);
    [_circleButton setImage:[UIImage imageNamed:@"playing_circle_btn"] forState:UIControlStateNormal];
    [_circleButton setImage:[UIImage imageNamed:@"playing_single_btn"] forState:UIControlStateSelected];
    [_circleButton addTarget:self action:@selector(circleOrSingle:) forControlEvents:UIControlEventTouchUpInside];
    [backgroundView addSubview:_circleButton];
}

-(UIImage *)OriginImage:(UIImage *)image scaleToSize:(CGSize)size
{
    UIGraphicsBeginImageContext(size);
    
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

- (void)prev
{
    if (_currentIndex > 0) {
        NSIndexPath *last = [NSIndexPath indexPathForRow:_currentIndex-1 inSection:0];
        [self tableView:self.tableView didSelectRowAtIndexPath:last];
    }
}

- (void)pause
{
    _pauseButton.hidden = YES;
    _continueButton.hidden = NO;
    
    [_audioPlayer pause];
}

- (void)continue
{
    _continueButton.hidden = YES;
    _pauseButton.hidden = NO;
    
    [_audioPlayer play];
}

- (void)next
{
    if (_currentIndex < _items.count - 1) {
        NSIndexPath *last = [NSIndexPath indexPathForRow:_currentIndex+1 inSection:0];
        [self tableView:self.tableView didSelectRowAtIndexPath:last];
    }
}

- (void)gotoContentItem:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    NSIndexPath *index = [NSIndexPath indexPathForRow:slider.value inSection:0];
    [self tableView:self.tableView didSelectRowAtIndexPath:index];
}

- (void)circleOrSingle:(id)sender
{
    UIButton *button = (UIButton *)sender;
    button.selected = !button.selected;
}

@end

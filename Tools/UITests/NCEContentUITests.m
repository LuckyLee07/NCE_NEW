#import <XCTest/XCTest.h>

@interface NCEContentUITests : XCTestCase
@property(nonatomic,strong) XCUIApplication *app;
@end
@implementation NCEContentUITests
- (void)setUp {
    [super setUp];self.continueAfterFailure=NO;
    NSString *bundle=[[NSBundle bundleForClass:self.class] objectForInfoDictionaryKey:@"NCEQAAppBundleIdentifier"];
    XCTAssertTrue([bundle containsString:@".resourceqa"],@"Use an isolated QA identity.");
    self.app=[[XCUIApplication alloc] initWithBundleIdentifier:bundle];self.app.launchArguments=@[@"-NCEOfflineResourceQA",@"-NCEResetStudyQA",@"-AppleLanguages",@"(zh-Hans)",@"-AppleLocale",@"zh_CN"];
    [self.app launch];XCTAssertTrue([self.app.buttons[@"book-picker"] waitForExistenceWithTimeout:20]);
}
- (void)reveal:(XCUIElement *)element {
    for(NSInteger i=0;i<8 && (!element.exists || !element.hittable);i++){
        XCUIElement *scroll=element.elementType==XCUIElementTypeCell ? self.app.tables.allElementsBoundByIndex.lastObject : self.app.scrollViews[@"practice-content"];
        if(!scroll.exists)scroll=self.app.tables.firstMatch;
        if(!scroll.exists)scroll=self.app.scrollViews.firstMatch;
        if(!scroll.exists)break;
        BOOL above=element.exists && CGRectGetMidY(element.frame)<CGRectGetMidY(scroll.frame);
        XCUICoordinate *start=[scroll coordinateWithNormalizedOffset:CGVectorMake(0.5,above ? 0.3 : 0.75)];
        XCUICoordinate *end=[scroll coordinateWithNormalizedOffset:CGVectorMake(0.5,above ? 0.75 : 0.3)];
        [start pressForDuration:0.05 thenDragToCoordinate:end];
    }
}
- (void)tap:(XCUIElement *)element {if(!element.exists)XCTAssertTrue([element waitForExistenceWithTimeout:5]);[self reveal:element];XCTAssertTrue(element.exists && element.hittable,@"Missing/inaccessible element: %@",element);[element tap];}
- (void)capture:(NSString *)name {XCTAttachment *attachment=[XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];attachment.name=name;attachment.lifetime=XCTAttachmentLifetimeKeepAlways;[self addAttachment:attachment];}
- (void)back {[self tap:self.app.buttons[@"back"]];}
- (void)book:(NSInteger)book {[self tap:self.app.buttons[@"book-picker"]];[self tap:self.app.cells[[NSString stringWithFormat:@"book-%ld",(long)book]]];}
- (void)section:(NSString *)section {[self tap:self.app.segmentedControls[@"course-sections"].buttons[section]];}
- (void)mode:(NSInteger)mode {[self tap:self.app.buttons[@"practice-mode-picker"]];[self tap:self.app.cells[[NSString stringWithFormat:@"practice-mode-%ld",(long)mode]]];}
- (void)openCourse {[self tap:self.app.buttons[@"home-continue"]];XCTAssertTrue([self.app.segmentedControls[@"course-sections"] waitForExistenceWithTimeout:8]);if(self.app.buttons[@"lesson-pause"].exists)[self tap:self.app.buttons[@"lesson-pause"]];}
- (void)tab:(NSInteger)index {XCUIElement *button=[self.app.buttons matchingIdentifier:[NSString stringWithFormat:@"home-tab-%ld",(long)index]].firstMatch;if(!button.exists)button=[self.app.buttons matchingIdentifier:@[@"学习",@"课程",@"单词本"][index]].firstMatch;[self tap:button];}
- (void)relaunchPreservingStudy {
    [self.app terminate];NSMutableArray *args=self.app.launchArguments.mutableCopy;[args removeObject:@"-NCEResetStudyQA"];self.app.launchArguments=args;[self.app launch];XCTAssertTrue([self.app.buttons[@"book-picker"] waitForExistenceWithTimeout:15]);
}
- (void)testFourBooksAndFirstLessonControls {
    [self capture:@"home-first-use"];
    for(NSInteger book=1;book<=4;book++){
        [self book:book];[self openCourse];XCTAssertTrue(self.app.staticTexts[@"lesson-english-0"].exists);
        [self tap:self.app.buttons[@"lesson-next"]];[self tap:self.app.buttons[@"lesson-prev"]];[self tap:self.app.buttons[@"lesson-pause"]];
        [self tap:self.app.buttons[@"lesson-show-translation"]];XCTAssertFalse(self.app.staticTexts[@"lesson-translation-0"].exists);[self tap:self.app.buttons[@"lesson-show-translation"]];
        XCTAssertEqual(self.app.tabBars.count,0u);[self capture:[NSString stringWithFormat:@"book-%ld-reading",(long)book]];[self back];
    }
    [self capture:@"home-resume"];
}
- (void)testCatalogSearchAndEmptyStates {
    [self tab:1];[self capture:@"course-catalog"];XCUIElement *field=self.app.searchFields.firstMatch;[self tap:field];[field typeText:@"zzznomatchinglesson\n"];XCTAssertTrue(self.app.staticTexts[@"没有找到课程"].exists);[self capture:@"course-empty"];[self tap:self.app.buttons[@"empty-action"]];XCTAssertGreaterThan(self.app.tables.cells.count,0u);
    [self book:2];[self tap:self.app.cells[@"lesson-1"]];XCTAssertTrue(self.app.staticTexts[@"course-title"].exists);
}
- (void)testDraftKeyboardAndSectionRestore {
    [self openCourse];[self section:@"练习"];
    XCUIElement *field=self.app.textFields[@"dictation-answer"];[self tap:field];[field typeText:@"enginer"];
    XCTAssertTrue(self.app.keyboards.firstMatch.exists);XCTAssertTrue(self.app.buttons[@"practice-submit"].hittable);[self capture:@"dictation-keyboard"];
    [self section:@"单词"];XCTAssertTrue(self.app.staticTexts[@"word-english"].exists);[self section:@"练习"];XCTAssertEqualObjects(self.app.textFields[@"dictation-answer"].value,@"enginer");
    [self relaunchPreservingStudy];[self openCourse];[self section:@"练习"];XCTAssertEqualObjects(self.app.textFields[@"dictation-answer"].value,@"enginer");
    [self tap:self.app.buttons[@"practice-submit"]];XCTAssertTrue(self.app.staticTexts[@"practice-feedback"].exists);XCTAssertFalse(self.app.keyboards.firstMatch.exists);XCTAssertTrue(self.app.buttons[@"practice-next"].hittable);[self capture:@"dictation-feedback"];
}
- (void)finishWithSkips {
    for(NSInteger question=0;question<21 && !self.app.staticTexts[@"practice-result"].exists;question++){
        if(self.app.buttons[@"practice-skip"].exists)[self tap:self.app.buttons[@"practice-skip"]];
        if(self.app.buttons[@"practice-next"].exists)[self tap:self.app.buttons[@"practice-next"]];
    }
    XCTAssertTrue(self.app.staticTexts[@"practice-result"].exists);
    XCTAssertTrue(self.app.staticTexts[@"practice-result"].hittable,@"A completed round should open at the result heading.");
}
- (void)testDictationAndBothChoiceTestsComplete {
    [self openCourse];[self section:@"练习"];
    for(NSInteger mode=2;mode<=4;mode++){
        [self mode:mode];
        if(mode==2){[self tap:self.app.textFields[@"dictation-answer"]];[self.app.textFields[@"dictation-answer"] typeText:@"deliberatelywrong\n"];}
        else{XCTAssertFalse(self.app.buttons[@"practice-submit"].enabled);[self tap:self.app.buttons[@"practice-option-1"]];[self tap:self.app.buttons[@"practice-submit"]];}
        XCTAssertTrue(self.app.staticTexts[@"practice-feedback"].exists);[self capture:[NSString stringWithFormat:@"mode-%ld-feedback",(long)mode]];[self tap:self.app.buttons[@"practice-next"]];[self finishWithSkips];[self capture:[NSString stringWithFormat:@"mode-%ld-result",(long)mode]];
        if(mode==2){[self tap:self.app.buttons[@"practice-retry-wrong"]];XCTAssertTrue([self.app.staticTexts[@"practice-progress"].label containsString:@"1 / 1"]);[self finishWithSkips];}
    }
}
- (void)testBothRecallModes {
    [self openCourse];[self section:@"练习"];
    for(NSInteger mode=0;mode<=1;mode++){[self mode:mode];XCTAssertTrue(self.app.buttons[@"practice-reveal"].exists);[self tap:self.app.buttons[@"practice-reveal"]];[self capture:[NSString stringWithFormat:@"recall-%ld",(long)mode]];[self tap:self.app.buttons[@"practice-remembered"]];XCTAssertTrue(self.app.staticTexts[@"practice-feedback"].exists);[self tap:self.app.buttons[@"practice-next"]];}
}
- (void)testAllCorrectResult {
    [self openCourse];[self section:@"练习"];[self mode:0];
    for(NSInteger i=0;i<21 && !self.app.staticTexts[@"practice-result"].exists;i++){[self tap:self.app.buttons[@"practice-reveal"]];[self tap:self.app.buttons[@"practice-remembered"]];[self tap:self.app.buttons[@"practice-next"]];}
    XCTAssertTrue(self.app.staticTexts[@"全部答对，做得不错！"].exists);XCTAssertFalse(self.app.buttons[@"practice-retry-wrong"].exists);[self capture:@"all-correct-result"];[self tap:self.app.buttons[@"practice-return"]];XCTAssertTrue(self.app.buttons[@"lesson-play"].exists);
}
- (void)checkWordSamples:(NSArray *)samples {
    [self tab:2];
    for(NSArray *sample in samples){[self book:[sample[0] integerValue]];XCUIElement *field=self.app.searchFields.firstMatch;[self tap:field];[field typeText:[sample[1] stringByAppendingString:@"\n"]];[self tap:self.app.cells[[ @"wordbook-word-" stringByAppendingString:sample[2]]]];
        XCUIElement *english=self.app.staticTexts[@"word-english"],*translation=self.app.staticTexts[@"word-translation"],*image=self.app.images[@"word-image"];
        XCTAssertEqualObjects(english.label,sample[1]);XCTAssertTrue(translation.exists);XCTAssertTrue(image.exists);XCTAssertFalse(CGRectIntersectsRect(image.frame,translation.frame));[self capture:[@"word-" stringByAppendingString:sample[2]]];[self back];
    }
}
- (void)testGeneratedImagesAndCorrectedNames {[self checkWordSamples:@[@[@1,@"handbag",@"handbag"],@[@1,@"bookcase",@"bookcase"],@[@2,@"stocking",@"stocking"],@[@2,@"doorknob",@"doorknob"],@[@4,@"memory-chip",@"memory-chip"],@[@4,@"maitre d'hotel",@"maitre d'hotel"],@[@4,@"glider",@"glider"],@[@4,@"vole",@"vole"],@[@4,@"New Jersey",@"Mew Jersey"],@[@4,@"St. Petersburg",@"St.Petersbrug"]]];}
- (void)checkAcademyVisuals:(NSArray *)samples book:(NSInteger)book {
    [self tab:2];[self book:book];
    for(NSArray *sample in samples) {
        XCUIElement *field=self.app.searchFields.firstMatch;[self tap:field];
        NSString *previous=[field.value isKindOfClass:NSString.class] ? field.value : @"";
        if(previous.length && ![previous isEqual:field.placeholderValue])
            [field typeText:[@"" stringByPaddingToLength:previous.length withString:XCUIKeyboardKeyDelete startingAtIndex:0]];
        [field typeText:[sample[0] stringByAppendingString:@"\n"]];
        [self tap:self.app.cells[[@"wordbook-word-" stringByAppendingString:sample[0]]]];
        XCUIElement *visual=self.app.images[@"word-image"],*translation=self.app.staticTexts[@"word-translation"];
        XCTAssertTrue(visual.exists);XCTAssertTrue(visual.hittable);
        XCTAssertFalse(CGRectIntersectsRect(visual.frame,translation.frame));
        XCTAssertLessThanOrEqual(CGRectGetMaxX(visual.frame),CGRectGetWidth(self.app.frame));
        if([sample[1] length]){
            XCUIElement *caption=self.app.staticTexts[@"word-visual-caption"];
            XCTAssertTrue([visual.label containsString:sample[1]] || [caption.label isEqual:sample[1]],@"Visual context must be accessible.");
            if(caption.exists){XCTAssertFalse(CGRectIntersectsRect(visual.frame,caption.frame));XCTAssertFalse(CGRectIntersectsRect(caption.frame,translation.frame));}
        }
        [self capture:[@"academy-" stringByAppendingString:sample[0]]];[self back];
    }
}
- (void)testAcademyBookOneVisuals {
    [self checkAcademyVisuals:@[@[@"me",@"Please help ___."],@[@"January",@""],@[@"may",@"___ I come in?"],@[@"during",@"It happened ___ this period."],@[@"is",@"She ___ a student."],@[@"cinema",@""]] book:1];
}
- (void)testAcademyBookTwoVisuals {
    [self checkAcademyVisuals:@[@[@"private",@"This diary is ___."],@[@"hand",@"The long ___ points to twelve."],@[@"bank",@""],@[@"key",@""],@[@"whether",@"I do not know ___ he will come."],@[@"last",@"The meeting will ___ one hour."]] book:2];
}
- (void)testAcademyBookTwoEmbedded {
    [self book:2];[self openCourse];[self section:@"单词"];
    for(NSInteger i=0;i<16 && ![self.app.staticTexts[@"word-english"].label isEqual:@"private"];i++)[self tap:self.app.buttons[@"word-next"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label,@"private");
    XCUIElement *visual=self.app.images[@"word-image"],*caption=self.app.staticTexts[@"word-visual-caption"],*translation=self.app.staticTexts[@"word-translation"];
    XCTAssertTrue(visual.hittable);XCTAssertEqualObjects(caption.label,@"This diary is ___.");
    XCTAssertFalse(CGRectIntersectsRect(visual.frame,caption.frame));XCTAssertFalse(CGRectIntersectsRect(caption.frame,translation.frame));
    XCTAssertTrue(CGRectContainsRect(self.app.scrollViews[@"word-content"].frame,translation.frame));
    [self capture:@"academy-book2-private-embedded"];
}
- (void)testAcademyBookThreeVisuals {
    [self checkAcademyVisuals:@[@[@"puma",@""],@[@"spot",@"The hiker can ___ a footprint."],@[@"cling",@"The wet leaf will ___ to the coat."],@[@"unpack",@"Take the clothes out: ___ the suitcase."],@[@"fraction",@"Only a small ___ of the whole."],@[@"IBM",@"International Business Machines is usually abbreviated to ___."]] book:3];
}
- (void)testAcademyBookThreeEmbedded {
    [self book:3];[self openCourse];[self section:@"单词"];
    for(NSInteger i=0;i<18 && ![self.app.staticTexts[@"word-english"].label isEqual:@"spot"];i++)[self tap:self.app.buttons[@"word-next"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label,@"spot");
    XCUIElement *visual=self.app.images[@"word-image"],*caption=self.app.staticTexts[@"word-visual-caption"],*translation=self.app.staticTexts[@"word-translation"];
    XCTAssertTrue(visual.hittable);XCTAssertEqualObjects(caption.label,@"The hiker can ___ a footprint.");
    XCTAssertFalse(CGRectIntersectsRect(visual.frame,caption.frame));XCTAssertFalse(CGRectIntersectsRect(caption.frame,translation.frame));
    XCTAssertTrue(CGRectContainsRect(self.app.scrollViews[@"word-content"].frame,translation.frame));
    [self capture:@"academy-book3-spot-embedded"];
}
- (void)testAcademyBookFourVisuals {
    [self checkAcademyVisuals:@[@[@"fossil man",@""],@[@"recount",@"He will ___ the voyage."],@[@"court",@"He seems to ___ danger."],@[@"glider",@"The bird is a natural ___."],@[@"port",@"The highlighted side is ___."],@[@"Indonesia",@"Jakarta is a city in ___."]] book:4];
}
- (void)testAcademyBookFourEmbedded {
    [self book:4];[self openCourse];[self section:@"单词"];
    for(NSInteger i=0;i<18 && ![self.app.staticTexts[@"word-english"].label isEqual:@"recount"];i++)[self tap:self.app.buttons[@"word-next"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label,@"recount");
    XCUIElement *visual=self.app.images[@"word-image"],*caption=self.app.staticTexts[@"word-visual-caption"],*translation=self.app.staticTexts[@"word-translation"];
    XCTAssertTrue(visual.hittable);XCTAssertEqualObjects(caption.label,@"He will ___ the voyage.");
    XCTAssertFalse(CGRectIntersectsRect(visual.frame,caption.frame));XCTAssertFalse(CGRectIntersectsRect(caption.frame,translation.frame));
    XCTAssertTrue(CGRectContainsRect(self.app.scrollViews[@"word-content"].frame,translation.frame));
    [self capture:@"academy-book4-recount-embedded"];
}
- (void)testAcademyContextEmbedded {
    [self openCourse];[self section:@"单词"];
    for(NSInteger i=0;i<12 && ![self.app.staticTexts[@"word-english"].label isEqual:@"me"];i++)[self tap:self.app.buttons[@"word-next"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label,@"me");
    XCUIElement *visual=self.app.images[@"word-image"],*caption=self.app.staticTexts[@"word-visual-caption"],*english=self.app.staticTexts[@"word-english"];
    XCTAssertTrue(visual.hittable);XCTAssertTrue(caption.hittable);XCTAssertEqualObjects(caption.label,@"Please help ___.");
    XCTAssertFalse(CGRectIntersectsRect(visual.frame,caption.frame));XCTAssertFalse(CGRectIntersectsRect(caption.frame,english.frame));
    XCTAssertTrue(self.app.buttons[@"word-next"].hittable);
    XCTAssertTrue(CGRectContainsRect(self.app.scrollViews[@"word-content"].frame,self.app.staticTexts[@"word-translation"].frame),@"The meaning should fit fully in the initial lesson viewport.");[self capture:@"academy-me-embedded"];
    for(NSInteger i=0;i<12 && ![self.app.staticTexts[@"word-english"].label isEqual:@"is"];i++)[self tap:self.app.buttons[@"word-next"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label,@"is");
    XCTAssertFalse(self.app.staticTexts[@"word-visual-caption"].exists,@"Previous scene caption must be cleared when a grammar hint loads.");
    XCTAssertTrue([self.app.images[@"word-image"].label containsString:@"She ___ a student."]);[self capture:@"academy-is-embedded"];
}
- (void)testCompactAndTabletWordLayout {[self checkWordSamples:@[@[@4,@"AT&T",@"AT&T"],@[@3,@"Justitieombudsman",@"Justiteombudsman"],@[@4,@"St. Petersburg",@"St.Petersbrug"]]];}
- (void)testWordbookMarkSurvivesRelaunch {
    [self openCourse];[self section:@"单词"];[self capture:@"lesson-words"];[self tap:self.app.buttons[@"word-bookmark"]];[self tap:self.app.buttons[@"word-strange"]];NSString *word=self.app.staticTexts[@"word-english"].label;[self relaunchPreservingStudy];[self tab:2];[self tap:self.app.buttons[@"收藏"]];XCTAssertTrue([self.app.cells[[@"wordbook-word-" stringByAppendingString:word]].firstMatch waitForExistenceWithTimeout:5]);[self capture:@"wordbook-bookmarks"];[self tap:self.app.buttons[@"wordbook-review"]];XCTAssertTrue(self.app.buttons[@"practice-reveal"].exists);
}
- (void)testWordbookEmptyFilter {
    [self tab:2];[self tap:self.app.buttons[@"收藏"]];XCTAssertTrue(self.app.staticTexts[@"这里还没有单词"].exists);XCTAssertFalse(self.app.buttons[@"wordbook-review"].exists);[self capture:@"wordbook-empty"];[self tap:self.app.buttons[@"empty-action"]];XCTAssertGreaterThan(self.app.tables.cells.count,0u);
}
- (void)chooseLanguage:(NSString *)name {[self tap:self.app.buttons[@"settings"]];[self tap:self.app.cells[@"settings-language"]];[self tap:self.app.buttons[name]];XCTAssertTrue([self.app.cells[@"settings-language"] waitForExistenceWithTimeout:5]);[self back];}
- (void)testFourLanguagesAndProgress {
    NSArray *names=@[@"简体中文",@"繁體中文",@"日本語",@"한국어"];
    for(NSInteger i=0;i<names.count;i++){
        [self chooseLanguage:names[i]];[self capture:[NSString stringWithFormat:@"language-%ld-home",(long)i]];[self openCourse];[self capture:[NSString stringWithFormat:@"language-%ld-reading",(long)i]];
        [self tap:[self.app.segmentedControls[@"course-sections"].buttons elementBoundByIndex:1]];
        XCTAssertTrue(self.app.staticTexts[@"word-english"].exists);[self capture:[NSString stringWithFormat:@"language-%ld-word",(long)i]];
        [self tap:[self.app.segmentedControls[@"course-sections"].buttons elementBoundByIndex:2]];[self capture:[NSString stringWithFormat:@"language-%ld-practice",(long)i]];[self back];
    }
}
- (void)testSettingsCredits {[self tap:self.app.buttons[@"settings"]];[self capture:@"settings"];[self tap:self.app.cells[@"settings-credits"]];XCTAssertTrue(self.app.navigationBars.count>0);[self capture:@"credits"];}
- (void)testLargeTypeLayout {
    [self.app terminate];self.app.launchArguments=[self.app.launchArguments arrayByAddingObjectsFromArray:@[@"-UIPreferredContentSizeCategoryName",@"UICTContentSizeCategoryAccessibilityXL"]];[self.app launch];
    [self capture:@"large-type-home"];[self openCourse];[self capture:@"large-type-reader"];[self section:@"单词"];
    XCTAssertFalse(CGRectIntersectsRect(self.app.images[@"word-image"].frame,self.app.staticTexts[@"word-translation"].frame));[self tap:self.app.buttons[@"word-familiar"]];[self capture:@"large-type-word"];[self section:@"练习"];
    [self tap:self.app.textFields[@"dictation-answer"]];[self.app.textFields[@"dictation-answer"] typeText:@"draft"];[self capture:@"large-type-keyboard"];[self.app.textFields[@"dictation-answer"] typeText:@"\n"];[self tap:self.app.buttons[@"practice-next"]];
}
- (void)testTabletLearningContentBelowNavigationBar {
    [self openCourse];XCUIElement *title=self.app.staticTexts[@"course-title"];
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(title.frame),CGRectGetMaxY(self.app.navigationBars.firstMatch.frame));[self section:@"单词"];[self capture:@"tablet-course-word"];
    [self section:@"练习"];[self mode:3];[self capture:@"tablet-practice"];[self tap:self.app.buttons[@"practice-option-0"]];[self tap:self.app.buttons[@"practice-submit"]];[self capture:@"tablet-feedback"];
}
- (void)testAudioPreparationCancellation {
    [self.app terminate];
    self.app.launchArguments=@[@"-NCEOfflineResourceQA",@"-NCEAudioPreparationPreview",@"-AppleLanguages",@"(zh-Hans)"];
    [self.app launch];[self tap:self.app.buttons[@"home-continue"]];
    XCUIElement *play=self.app.buttons[@"lesson-play"];
    XCTNSPredicateExpectation *waiting=[[XCTNSPredicateExpectation alloc] initWithPredicate:[NSPredicate predicateWithFormat:@"exists == YES AND enabled == NO"] object:play];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[waiting] timeout:3],XCTWaiterResultCompleted);
    XCTAssertTrue(self.app.staticTexts[@"lesson-english-0"].exists);
    [self capture:@"audio-inline-loading"];
    [self section:@"单词"];[self section:@"听读"];
    XCTAssertTrue(play.enabled);
    XCTNSPredicateExpectation *stalePlayback=[[XCTNSPredicateExpectation alloc] initWithPredicate:[NSPredicate predicateWithFormat:@"exists == YES"] object:self.app.buttons[@"lesson-pause"]];
    stalePlayback.inverted=YES;
    XCTAssertEqual([XCTWaiter waitForExpectations:@[stalePlayback] timeout:5],XCTWaiterResultCompleted);
    [play tap];XCTAssertTrue([self.app.buttons[@"lesson-pause"] waitForExistenceWithTimeout:8]);
    [self tap:self.app.buttons[@"lesson-pause"]];XCTAssertTrue(play.enabled);
}
- (void)testStartupLoadingAndRecovery {
    // Preserve the existing selected book through startup, including a failed attempt.
    NSString *selection=self.app.buttons[@"book-picker"].label;
    [self.app terminate];
    self.app.launchArguments=@[@"-NCEOfflineResourceQA",@"-NCEStartupFailOnce",@"-AppleLanguages",@"(zh-Hans)"];
    [self.app launch];
    XCUIElement *retry=self.app.buttons[@"startup-retry"];
    XCTAssertTrue([retry waitForExistenceWithTimeout:8]);
    XCTAssertTrue(retry.hittable);
    XCTAssertTrue([self.app.staticTexts[@"startup-status"].label containsString:@"重试"]);
    XCTAssertFalse(self.app.buttons[@"book-picker"].exists);
    [self capture:@"startup-error"];[retry tap];
    XCTAssertTrue([self.app.buttons[@"book-picker"] waitForExistenceWithTimeout:15]);
    XCTAssertEqualObjects(selection,self.app.buttons[@"book-picker"].label);
    XCTAssertFalse(self.app.buttons[@"startup-retry"].exists);
    [self.app terminate];
    self.app.launchArguments=@[@"-NCEOfflineResourceQA",@"-AppleLanguages",@"(zh-Hans)"];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"book-picker"] waitForExistenceWithTimeout:8]);
    XCTAssertEqualObjects(selection,self.app.buttons[@"book-picker"].label);
}
- (void)testStartupSlowPreparation {
    [self.app terminate];
    self.app.launchArguments=@[@"-NCEOfflineResourceQA",@"-NCEStartupPreview",@"-NCEStartupReduceMotion",@"-AppleLanguages",@"(zh-Hans)"];
    [self.app launch];
    XCUIElement *status=self.app.staticTexts[@"startup-status"];
    XCTAssertTrue([status waitForExistenceWithTimeout:5]);
    XCTAssertEqualObjects(status.label,@"正在准备学习内容…");
    XCTAssertFalse(self.app.buttons[@"startup-retry"].exists);
    XCTAssertFalse(self.app.buttons[@"book-picker"].exists);
    [self capture:@"startup-loading-light"];
    XCTAssertTrue([self.app.buttons[@"book-picker"] waitForExistenceWithTimeout:20]);
    XCTAssertFalse(status.exists);
}
- (void)storeMediaMarker:(NSString *)event language:(NSString *)language scene:(NSString *)scene {NSLog(@"NCE_STORE|%@|%@|%@|%.6f",event,language,scene,NSDate.date.timeIntervalSince1970);}
- (void)captureStoreScene:(NSString *)scene language:(NSString *)language {
    [NSThread sleepForTimeInterval:1.5];XCTAssertEqual(self.app.keyboards.count,0u);[self storeMediaMarker:@"START" language:language scene:scene];[self capture:[NSString stringWithFormat:@"store-%@-%@",language,scene]];[NSThread sleepForTimeInterval:8];[self storeMediaMarker:@"END" language:language scene:scene];
}
- (void)testCaptureStoreMedia {
    // Only the dedicated host capture command starts the video recorder.
    XCTSkipUnless([[[NSBundle bundleForClass:self.class] objectForInfoDictionaryKey:@"NCEQAAppBundleIdentifier"] containsString:@".storemedia"],@"Run Tools/capture_store_media.py for store recordings.");
    NSDictionary *names=@{@"zh-Hans":@"简体中文",@"zh-Hant":@"繁體中文",@"ja":@"日本語",@"ko":@"한국어"};
    for(NSString *code in @[@"zh-Hans",@"zh-Hant",@"ja",@"ko"]){
        [self chooseLanguage:names[code]];[self storeMediaMarker:@"READY" language:code scene:@"session"];[NSThread sleepForTimeInterval:5];[self captureStoreScene:@"01-home" language:code];
        [self openCourse];[self captureStoreScene:@"02-lesson" language:code];[self tap:[self.app.segmentedControls[@"course-sections"].buttons elementBoundByIndex:1]];[self captureStoreScene:@"03-word" language:code];
        [self tap:[self.app.segmentedControls[@"course-sections"].buttons elementBoundByIndex:2]];[self mode:3];[self tap:self.app.buttons[@"practice-option-0"]];[self captureStoreScene:@"04-practice" language:code];[self back];[self tab:2];[self captureStoreScene:@"05-wordbook" language:code];[self tab:0];[self storeMediaMarker:@"DONE" language:code scene:@"session"];
    }
}
@end

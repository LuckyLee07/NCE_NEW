#import <XCTest/XCTest.h>

@interface NCEContentUITests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation NCEContentUITests

- (void)setUp
{
    [super setUp];
    self.continueAfterFailure = NO;
    NSString *bundle = [[NSBundle bundleForClass:self.class] objectForInfoDictionaryKey:@"NCEQAAppBundleIdentifier"];
    // Never launch the user's production App or mutate its learning records.
    XCTAssertTrue([bundle containsString:@".resourceqa"], @"Set NCE_APP_BUNDLE_IDENTIFIER to an independent .resourceqa identifier.");
    if (![bundle containsString:@".resourceqa"]) return;
    self.app = [[XCUIApplication alloc] initWithBundleIdentifier:bundle];
    self.app.launchArguments = @[@"-NCEOfflineResourceQA"];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"book-1"] waitForExistenceWithTimeout:15]);
}

- (void)tap:(XCUIElement *)element
{
    XCTAssertTrue([element waitForExistenceWithTimeout:10], @"Missing element: %@", element);
    XCTAssertTrue(element.hittable, @"Element is not hittable: %@", element);
    [element tap];
}

- (void)back
{
    [self tap:self.app.buttons[@"back"]];
}

- (void)capture:(NSString *)name
{
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testFourBooksAndFirstLessonControls
{
    for (NSInteger book = 1; book <= 4; book++) {
        [self tap:self.app.buttons[[NSString stringWithFormat:@"book-%ld", (long)book]]];
        [self tap:self.app.cells[@"mode-0"]];
        [self tap:self.app.cells[@"lesson-0"]];
        XCTAssertGreaterThan(self.app.tables.cells.count, 0u);
        [self tap:self.app.buttons[@"lesson-pause"]];
        [self tap:self.app.buttons[@"lesson-play"]];
        [self tap:self.app.buttons[@"lesson-pause"]];
        [self tap:self.app.buttons[@"lesson-next"]];
        [self tap:self.app.buttons[@"lesson-prev"]];
        [self capture:[NSString stringWithFormat:@"book-%ld-first-lesson", (long)book]];
        [self back]; [self back]; [self back];
    }
}

- (void)testGeneratedImagesAndCorrectedNames
{
    NSArray *samples = @[
        @[@1, @"handbag", @"handbag"], @[@1, @"bookcase", @"bookcase"],
        @[@2, @"stocking", @"stocking"], @[@2, @"doorknob", @"doorknob"],
        @[@4, @"memory-chip", @"memory-chip"], @[@4, @"maitre d'hotel", @"maitre d'hotel"],
        @[@4, @"glider", @"glider"], @[@4, @"vole", @"vole"],
        @[@4, @"New Jersey", @"Mew Jersey"], @[@4, @"St. Petersburg", @"St.Petersbrug"]
    ];
    [self checkWordSamples:samples];
}

- (void)testCompactAndTabletWordLayout
{
    [self checkWordSamples:@[
        @[@4, @"AT&T", @"AT&T"],
        @[@3, @"Justitieombudsman", @"Justiteombudsman"],
        @[@4, @"St. Petersburg", @"St.Petersbrug"]
    ]];
}

- (void)checkWordSamples:(NSArray *)samples
{
    for (NSArray *sample in samples) {
        [self tap:self.app.buttons[[NSString stringWithFormat:@"book-%@", sample[0]]]];
        [self tap:self.app.cells[@"mode-7"]];
        XCUIElement *field = self.app.searchFields.firstMatch;
        [self tap:field];
        [field typeText:sample[1]];
        [self tap:self.app.cells[[@"search-word-" stringByAppendingString:sample[2]]]];
        [self tap:self.app.buttons[@"word-pause"]];
        XCUIElement *image = self.app.images[@"word-image"];
        XCUIElement *translation = self.app.staticTexts[@"word-translation"];
        XCTAssertTrue(image.exists);
        XCTAssertFalse(CGRectIntersectsRect(image.frame, translation.frame), @"Word image obscures translation");
        [self capture:[@"word-" stringByAppendingString:sample[2]]];
        CGRect viewport = self.app.windows.firstMatch.frame;
        XCTAssertTrue(CGRectContainsRect(viewport, image.frame), @"Word image extends outside window: app=%@ window=%@ image=%@", NSStringFromCGRect(self.app.frame), NSStringFromCGRect(viewport), NSStringFromCGRect(image.frame));
        XCTAssertTrue(CGRectContainsRect(viewport, translation.frame), @"Translation extends outside viewport");
        XCTAssertTrue(CGRectContainsRect(viewport, self.app.staticTexts[@"word-english"].frame), @"English word extends outside viewport");
        [self tap:self.app.buttons[@"word-repeat"]];
        [self tap:self.app.buttons[@"word-pause"]];
        XCTAssertTrue(self.app.buttons[@"word-play"].exists);
        [self tap:self.app.buttons[@"word-strange"]];
        [self capture:[@"word-" stringByAppendingString:sample[2]]];
        [self back]; [self back]; [self back];
    }
}

- (void)testDictationAndBothChoiceTestsComplete
{
    for (NSInteger mode = 4; mode <= 6; mode++) {
        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[[NSString stringWithFormat:@"mode-%ld", (long)mode]]];
        [self tap:self.app.buttons[@"alert-choice-1"]];
        for (NSInteger question = 0; question < 20; question++) {
            if (mode == 4) {
                if (question == 0) {
                    [self tap:self.app.buttons[@"dictation-repeat"]];
                    XCUIElement *answer = self.app.textFields[@"dictation-answer"];
                    [self tap:answer];
                    [answer typeText:@"deliberatelywronganswer\n"];
                } else {
                    [self tap:self.app.buttons[@"dictation-pass"]];
                }
            } else {
                [self tap:self.app.cells[@"test-row-2"]];
            }
        }
        XCTAssertTrue([self.app.buttons[@"alert-cancel"] waitForExistenceWithTimeout:10]);
        [self capture:[NSString stringWithFormat:@"test-%ld-result", (long)mode]];
        [self tap:self.app.buttons[@"alert-cancel"]];
        XCTAssertTrue(self.app.cells[@"mode-8"].exists);
        [self back];
    }
}

- (void)testWordbookMarkSurvivesRelaunch
{
    [self tap:self.app.buttons[@"book-1"]];
    [self tap:self.app.cells[@"mode-7"]];
    XCUIElement *field = self.app.searchFields.firstMatch;
    [self tap:field];
    [field typeText:@"handbag"];
    [self tap:self.app.cells[@"search-word-handbag"]];
    [self tap:self.app.buttons[@"word-pause"]];
    [self tap:self.app.buttons[@"word-strange"]];
    [self.app terminate];
    [self.app launch];
    [self tap:self.app.buttons[@"book-1"]];
    [self tap:self.app.cells[@"mode-8"]];
    [self tap:self.app.cells[@"wordbook-1"]];
    XCUIElement *word = self.app.cells[@"wordbook-word-handbag"];
    if (!word.hittable) [self.app.tables.firstMatch swipeUp];
    [self tap:word];
    [self tap:self.app.buttons[@"word-pause"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label, @"handbag");
    [self capture:@"wordbook-persisted-mark"];
}

- (void)testBothRecallModes
{
    for (NSInteger mode = 2; mode <= 3; mode++) {
        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[[NSString stringWithFormat:@"mode-%ld", (long)mode]]];
        [self tap:self.app.cells[@"lesson-0"]];
        [self tap:self.app.buttons[@"word-pause"]];
        if (mode == 2) {
            XCTAssertFalse(self.app.images[@"word-image"].exists);
            [self tap:self.app.buttons[@"word-show-translation"]];
            XCTAssertTrue(self.app.images[@"word-image"].exists);
        } else {
            XCTAssertTrue(!self.app.staticTexts[@"word-english"].exists || self.app.staticTexts[@"word-english"].label.length == 0);
            [self tap:self.app.buttons[@"word-show-english"]];
            XCTAssertTrue(self.app.staticTexts[@"word-english"].label.length > 0);
        }
        [self capture:[NSString stringWithFormat:@"recall-%ld", (long)mode]];
        [self back]; [self back]; [self back];
    }
}

- (void)testSettingsCredits
{
    [self tap:self.app.buttons[@"settings"]];
    [self tap:self.app.cells[@"settings-credits"]];
    XCUIElement *credits = self.app.textViews.firstMatch;
    XCTAssertTrue([credits waitForExistenceWithTimeout:10]);
    XCTAssertTrue([credits.value containsString:@"Twemoji"]);
    XCTAssertTrue([credits.value containsString:@"CC BY 4.0"]);
    [self capture:@"offline-credits"];
    XCTAssertTrue(CGRectContainsRect(self.app.windows.firstMatch.frame, credits.frame), @"Credits extend outside window: app=%@ window=%@ text=%@", NSStringFromCGRect(self.app.frame), NSStringFromCGRect(self.app.windows.firstMatch.frame), NSStringFromCGRect(credits.frame));
}

- (void)testSettingsButtonInBothLanguages
{
    for (NSString *language in @[@"简体中文", @"繁體中文"]) {
        [self chooseLanguage:language];
        XCUIElement *button = self.app.buttons[@"settings"];
        XCTAssertTrue(button.hittable);
        XCTAssertGreaterThanOrEqual(CGRectGetWidth(button.frame), 44.0);
        XCTAssertGreaterThanOrEqual(CGRectGetHeight(button.frame), 44.0);
        XCTAssertTrue(CGRectContainsRect(self.app.windows.firstMatch.frame, button.frame));
        XCTAssertEqualObjects(button.label, [language isEqual:@"繁體中文"] ? @"設定" : @"设置");
        [self capture:[language stringByAppendingString:@"-settings-button"]];
        [self tap:button];
        XCTAssertTrue([self.app.cells[@"settings-language"] waitForExistenceWithTimeout:10]);
        [self back];
    }
}

- (void)chooseLanguage:(NSString *)name
{
    [self tap:self.app.buttons[@"settings"]];
    [self tap:self.app.cells[@"settings-language"]];
    [self tap:self.app.buttons[name]];
    [self back];
    XCTAssertTrue([self.app.buttons[@"book-1"] waitForExistenceWithTimeout:10]);
}

- (void)storeMediaMarker:(NSString *)event language:(NSString *)language scene:(NSString *)scene
{
    // The host recorder uses simulator wall-clock markers to keep only clean, settled scenes.
    NSLog(@"NCE_STORE|%@|%@|%@|%.6f", event, language, scene, NSDate.date.timeIntervalSince1970);
}

- (void)assertBelowNavigationBar:(XCUIElement *)element
{
    XCTAssertTrue(element.exists);
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(element.frame), CGRectGetMaxY(self.app.navigationBars.firstMatch.frame),
                               @"Content is hidden under the navigation bar: %@", element);
}

- (void)testTabletLearningContentBelowNavigationBar
{
    [self chooseLanguage:@"简体中文"];
    [self tap:self.app.buttons[@"book-1"]];
    [self tap:self.app.cells[@"mode-7"]];
    XCUIElement *field = self.app.searchFields.firstMatch;
    [self assertBelowNavigationBar:field];
    [self tap:field];
    [field typeText:@"umbrella"];
    [self tap:self.app.cells[@"search-word-umbrella"]];
    [self tap:self.app.buttons[@"word-pause"]];
    [self assertBelowNavigationBar:self.app.staticTexts[@"word-english"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label, @"umbrella");
    [self capture:@"tablet-nav-word"];
    [self back]; [self back]; [self back];
    [self tap:self.app.buttons[@"book-1"]];
    [self tap:self.app.cells[@"mode-5"]];
    [self tap:self.app.buttons[@"alert-choice-0"]];
    [self tap:self.app.cells[@"lesson-0"]];
    [self assertBelowNavigationBar:self.app.cells[@"test-row-0"]];
    [self capture:@"tablet-nav-practice"];
    [self back]; [self back]; [self back];
}

- (void)beginStoreScene:(NSString *)scene language:(NSString *)language
{
    [NSThread sleepForTimeInterval:1.5];
    XCTAssertEqual(self.app.keyboards.count, 0u);
    [self storeMediaMarker:@"START" language:language scene:scene];
    [self capture:[NSString stringWithFormat:@"store-%@-%@", language, scene]];
}

- (void)testCaptureStoreMedia
{
    NSDictionary *names = @{@"zh-Hans": @"简体中文", @"zh-Hant": @"繁體中文", @"ja": @"日本語", @"ko": @"한국어"};
    for (NSString *language in @[@"zh-Hans", @"zh-Hant", @"ja", @"ko"]) {
        [self chooseLanguage:names[language]];
        [self storeMediaMarker:@"READY" language:language scene:@"session"];
        [NSThread sleepForTimeInterval:5.0];

        [self beginStoreScene:@"01-home" language:language];
        for (NSInteger book = 1; book <= 4; book++) {
            XCUIElement *cover = self.app.buttons[[NSString stringWithFormat:@"book-%ld", (long)book]];
            XCTAssertTrue(cover.hittable);
        }
        [NSThread sleepForTimeInterval:8.0];
        [self storeMediaMarker:@"END" language:language scene:@"01-home"];

        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[@"mode-0"]];
        [self tap:self.app.cells[@"lesson-0"]];
        [self tap:self.app.buttons[@"lesson-pause"]];
        XCTAssertTrue(self.app.staticTexts[@"lesson-translation-0"].exists);
        for (NSInteger row = 0; row < 4; row++) {
            XCUIElement *english = self.app.staticTexts[[NSString stringWithFormat:@"lesson-english-%ld", (long)row]];
            XCUIElement *translation = self.app.staticTexts[[NSString stringWithFormat:@"lesson-translation-%ld", (long)row]];
            XCUIElement *following = self.app.staticTexts[[NSString stringWithFormat:@"lesson-english-%ld", (long)row + 1]];
            XCTAssertLessThan(CGRectGetMaxY(english.frame), CGRectGetMinY(translation.frame));
            XCTAssertLessThan(CGRectGetMaxY(translation.frame), CGRectGetMinY(following.frame));
        }
        [self beginStoreScene:@"02-lesson" language:language];
        [NSThread sleepForTimeInterval:2.5];
        [self tap:self.app.buttons[@"lesson-next"]];
        [NSThread sleepForTimeInterval:6.0];
        [self storeMediaMarker:@"END" language:language scene:@"02-lesson"];
        [self back]; [self back]; [self back];

        BOOL tablet = CGRectGetWidth(self.app.windows.firstMatch.frame) > 700;
        [self tap:self.app.buttons[@"book-1"]];
        if (tablet) {
            [self tap:self.app.cells[@"mode-8"]];
            [self tap:self.app.cells[@"wordbook-0"]];
            [self tap:self.app.cells[@"wordbook-word-umbrella"]];
        } else {
            [self tap:self.app.cells[@"mode-7"]];
            XCUIElement *field = self.app.searchFields.firstMatch;
            [self tap:field];
            [field typeText:@"umbrella"];
            [self tap:self.app.cells[@"search-word-umbrella"]];
        }
        [self tap:self.app.buttons[@"word-pause"]];
        XCTAssertTrue(self.app.images[@"word-image"].exists);
        XCTAssertTrue(self.app.staticTexts[@"word-translation"].label.length > 0);
        [self assertBelowNavigationBar:self.app.staticTexts[@"word-english"]];
        [self beginStoreScene:@"03-word" language:language];
        [NSThread sleepForTimeInterval:2.5];
        [self tap:self.app.buttons[@"word-repeat"]];
        [NSThread sleepForTimeInterval:6.0];
        [self storeMediaMarker:@"END" language:language scene:@"03-word"];
        [self back]; [self back]; [self back];
        if (tablet) [self back];

        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[@"mode-5"]];
        [self tap:self.app.buttons[@"alert-choice-0"]];
        [self tap:self.app.cells[@"lesson-0"]];
        XCTAssertTrue([self.app.cells[@"test-row-5"] waitForExistenceWithTimeout:10]);
        [self assertBelowNavigationBar:self.app.cells[@"test-row-0"]];
        [self beginStoreScene:@"04-practice" language:language];
        [NSThread sleepForTimeInterval:2.5];
        [self tap:self.app.cells[@"test-row-2"]];
        [NSThread sleepForTimeInterval:6.0];
        [self storeMediaMarker:@"END" language:language scene:@"04-practice"];
        [self back]; [self back]; [self back];

        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[@"mode-8"]];
        [self tap:self.app.cells[@"wordbook-0"]];
        XCTAssertGreaterThan(self.app.tables.cells.count, 4u);
        [self beginStoreScene:@"05-wordbook" language:language];
        [NSThread sleepForTimeInterval:2.5];
        [self.app.tables.firstMatch swipeUp];
        [NSThread sleepForTimeInterval:6.0];
        [self storeMediaMarker:@"END" language:language scene:@"05-wordbook"];
        [self back]; [self back]; [self back];
        [self storeMediaMarker:@"DONE" language:language scene:@"session"];
    }
    [self chooseLanguage:@"简体中文"];
}

- (void)testChineseLanguagesAcrossBooksAndWords
{
    NSMutableDictionary *originalEnglish = [NSMutableDictionary dictionary];
    for (NSString *language in @[@"zh-Hans", @"zh-Hant"]) {
        BOOL traditional = [language isEqual:@"zh-Hant"];
        [self chooseLanguage:traditional ? @"繁體中文" : @"简体中文"];
        XCTAssertEqualObjects(self.app.buttons[@"book-1"].label, traditional ? @"第1冊" : @"第1册");
        [self capture:[language stringByAppendingString:@"-home"]];
        for (NSInteger book = 1; book <= 4; book++) {
            [self tap:self.app.buttons[[NSString stringWithFormat:@"book-%ld", (long)book]]];
            [self tap:self.app.cells[@"mode-0"]];
            if (book == 1) [self capture:[language stringByAppendingString:@"-lesson-list"]];
            [self tap:self.app.cells[@"lesson-0"]];
            [self tap:self.app.buttons[@"lesson-pause"]];
            NSString *english = self.app.staticTexts[@"lesson-english-0"].label;
            NSString *key = [NSString stringWithFormat:@"%ld", (long)book];
            if (!traditional) originalEnglish[key] = english;
            else XCTAssertEqualObjects(english, originalEnglish[key], @"Localization changed the English source");
            if (book == 1) {
                XCTAssertTrue([self.app.staticTexts[@"lesson-translation-0"].label hasPrefix:traditional ? @"對不起" : @"对不起"]);
            }
            [self capture:[NSString stringWithFormat:@"%@-book-%ld-lesson", language, (long)book]];
            [self tap:self.app.buttons[@"lesson-show-translation"]];
            XCTAssertFalse(self.app.staticTexts[@"lesson-translation-0"].exists);
            [self tap:self.app.buttons[@"lesson-show-translation"]];
            XCTAssertTrue(self.app.staticTexts[@"lesson-translation-0"].exists);
            [self back]; [self back]; [self back];
        }
        [self tap:self.app.buttons[@"book-3"]];
        [self tap:self.app.cells[@"mode-7"]];
        XCUIElement *field = self.app.searchFields.firstMatch;
        for (NSString *query in @[@"软件", @"軟體"]) {
            [self tap:field];
            [field typeText:query];
            XCTAssertTrue([self.app.cells[@"search-word-software"] waitForExistenceWithTimeout:10]);
            [field typeText:[@"" stringByPaddingToLength:query.length withString:XCUIKeyboardKeyDelete startingAtIndex:0]];
        }
        [field typeText:@"software"];
        [self capture:[language stringByAppendingString:@"-word-search"]];
        [self tap:self.app.cells[@"search-word-software"]];
        [self tap:self.app.buttons[@"word-pause"]];
        XCTAssertEqualObjects(self.app.staticTexts[@"word-translation"].label, traditional ? @"n.軟體" : @"n.软件");
        XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label, @"software");
        XCTAssertTrue(self.app.images[@"word-image"].exists);
        [self capture:[language stringByAppendingString:@"-word-software"]];
        [self back]; [self back]; [self back];
        [self tap:self.app.buttons[@"settings"]];
        [self capture:[language stringByAppendingString:@"-settings"]];
        [self back];
    }
    [self chooseLanguage:@"简体中文"];
}

- (void)testLanguageChoicePreservesProgress
{
    [self chooseLanguage:@"简体中文"];
    [self tap:self.app.buttons[@"book-1"]];
    [self tap:self.app.cells[@"mode-7"]];
    XCUIElement *field = self.app.searchFields.firstMatch;
    [self tap:field];
    [field typeText:@"handbag"];
    [self tap:self.app.cells[@"search-word-handbag"]];
    [self tap:self.app.buttons[@"word-pause"]];
    [self tap:self.app.buttons[@"word-strange"]];
    [self back]; [self back]; [self back];
    [self chooseLanguage:@"繁體中文"];
    [self.app terminate];
    [self.app launch];
    XCTAssertTrue([self.app.buttons[@"book-1"] waitForExistenceWithTimeout:10]);
    XCTAssertEqualObjects(self.app.buttons[@"book-1"].label, @"第1冊");
    [self tap:self.app.buttons[@"book-1"]];
    [self tap:self.app.cells[@"mode-8"]];
    [self tap:self.app.cells[@"wordbook-1"]];
    XCUIElement *word = self.app.cells[@"wordbook-word-handbag"];
    if (!word.hittable) [self.app.tables.firstMatch swipeUp];
    [self tap:word];
    [self tap:self.app.buttons[@"word-pause"]];
    XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label, @"handbag");
    [self capture:@"zh-Hant-progress-retained"];
    [self back]; [self back]; [self back]; [self back];
    [self chooseLanguage:@"简体中文"];
}

- (void)testInternationalBookCovers
{
    NSDictionary *names = @{@"zh-Hans": @"简体中文", @"zh-Hant": @"繁體中文", @"ja": @"日本語", @"ko": @"한국어"};
    NSDictionary *labels = @{@"zh-Hans": @"第%ld册", @"zh-Hant": @"第%ld冊", @"ja": @"第%ld巻", @"ko": @"제%ld권"};
    for (NSString *language in @[@"zh-Hans", @"zh-Hant", @"ja", @"ko"]) {
        [self chooseLanguage:names[language]];
        CGRect viewport = self.app.windows.firstMatch.frame;
        NSMutableArray<NSValue *> *frames = [NSMutableArray array];
        for (NSInteger book = 1; book <= 4; book++) {
            XCUIElement *button = self.app.buttons[[NSString stringWithFormat:@"book-%ld", (long)book]];
            XCTAssertTrue(button.hittable);
            NSString *expectedLabel = [NSString stringWithFormat:labels[language], (long)book];
            XCTAssertEqualObjects(button.label, expectedLabel);
            XCTAssertTrue(CGRectContainsRect(viewport, button.frame));
            XCTAssertGreaterThanOrEqual(CGRectGetWidth(button.frame), 44);
            XCTAssertGreaterThanOrEqual(CGRectGetHeight(button.frame), 44);
            XCTAssertEqualWithAccuracy(CGRectGetWidth(button.frame) / CGRectGetHeight(button.frame), 5.0 / 7.0, 0.01);
            for (NSValue *frame in frames) {
                XCTAssertFalse(CGRectIntersectsRect(frame.CGRectValue, button.frame));
            }
            [frames addObject:[NSValue valueWithCGRect:button.frame]];
        }
        [self capture:[language stringByAppendingString:@"-brand-home"]];
        for (NSInteger book = 1; book <= 4; book++) {
            [self tap:self.app.buttons[[NSString stringWithFormat:@"book-%ld", (long)book]]];
            XCTAssertTrue([self.app.cells[@"mode-0"] waitForExistenceWithTimeout:10]);
            [self back];
        }
    }
    [self chooseLanguage:@"简体中文"];
}

- (void)testLocalizedCompactAndTabletLayout
{
    NSDictionary *names = @{@"zh-Hans": @"简体中文", @"zh-Hant": @"繁體中文", @"ja": @"日本語", @"ko": @"한국어"};
    for (NSString *language in @[@"zh-Hans", @"zh-Hant", @"ja", @"ko"]) {
        [self chooseLanguage:names[language]];
        CGRect viewport = self.app.windows.firstMatch.frame;
        for (NSInteger book = 1; book <= 4; book++) {
            XCUIElement *button = self.app.buttons[[NSString stringWithFormat:@"book-%ld", (long)book]];
            XCTAssertTrue(button.hittable);
            XCTAssertTrue(CGRectContainsRect(viewport, button.frame), @"Book lies outside viewport");
        }
        [self capture:[language stringByAppendingString:@"-layout-home"]];
        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[@"mode-0"]];
        [self tap:self.app.cells[@"lesson-0"]];
        [self tap:self.app.buttons[@"lesson-pause"]];
        XCUIElement *english = self.app.staticTexts[@"lesson-english-0"];
        XCUIElement *chinese = self.app.staticTexts[@"lesson-translation-0"];
        XCTAssertTrue(CGRectContainsRect(viewport, english.frame));
        XCTAssertTrue(CGRectContainsRect(viewport, chinese.frame));
        XCTAssertFalse(CGRectIntersectsRect(english.frame, chinese.frame), @"Sentence and translation overlap");
        [self capture:[language stringByAppendingString:@"-layout-lesson"]];
        [self back]; [self back]; [self back];
        [self tap:self.app.buttons[@"book-3"]];
        [self tap:self.app.cells[@"mode-7"]];
        XCUIElement *field = self.app.searchFields.firstMatch;
        [self tap:field];
        [field typeText:@"software"];
        [self tap:self.app.cells[@"search-word-software"]];
        [self tap:self.app.buttons[@"word-pause"]];
        XCUIElement *picture = self.app.images[@"word-image"];
        XCUIElement *meaning = self.app.staticTexts[@"word-translation"];
        XCTAssertTrue(picture.exists);
        XCTAssertTrue(CGRectContainsRect(viewport, picture.frame));
        XCTAssertTrue(CGRectContainsRect(viewport, meaning.frame));
        XCTAssertFalse(CGRectIntersectsRect(picture.frame, meaning.frame), @"Picture and meaning overlap");
        [self capture:[language stringByAppendingString:@"-layout-word"]];
        [self back]; [self back]; [self back];
        [self tap:self.app.buttons[@"settings"]];
        [self capture:[language stringByAppendingString:@"-layout-settings"]];
        [self back];
    }
    [self chooseLanguage:@"简体中文"];
}

- (void)testSystemLanguageAndEnglishDeviceFallback
{
    for (NSString *systemLanguage in @[@"zh-Hant", @"en-US", @"zh-Hans-SG", @"ja-JP", @"ko-KR"]) {
        [self.app terminate];
        self.app.launchArguments = @[@"-NCEOfflineResourceQA", @"-AppleLanguages", [NSString stringWithFormat:@"(%@)", systemLanguage]];
        [self.app launch];
        XCTAssertTrue([self.app.buttons[@"book-1"] waitForExistenceWithTimeout:10]);
        [self tap:self.app.buttons[@"settings"]];
        [self tap:self.app.cells[@"settings-language"]];
        XCUIElement *system = self.app.buttons[@"跟随系统"];
        if (!system.exists) system = self.app.buttons[@"跟隨系統"];
        if (!system.exists) system = self.app.buttons[@"システム設定に従う"];
        if (!system.exists) system = self.app.buttons[@"시스템 설정 따르기"];
        [self tap:system];
        [self back];
        NSDictionary *labels = @{@"zh-Hant": @"第1冊", @"ja-JP": @"第1巻", @"ko-KR": @"제1권"};
        XCTAssertEqualObjects(self.app.buttons[@"book-1"].label, labels[systemLanguage] ?: @"第1册");
        [self capture:[systemLanguage stringByAppendingString:@"-system-default"]];
    }
    [self.app terminate];
    self.app.launchArguments = @[@"-NCEOfflineResourceQA"];
    [self.app launch];
    [self chooseLanguage:@"简体中文"];
}

- (void)testLocalizedPracticeScreens
{
    NSDictionary *names = @{@"zh-Hans": @"简体中文", @"zh-Hant": @"繁體中文", @"ja": @"日本語", @"ko": @"한국어"};
    for (NSString *language in @[@"zh-Hans", @"zh-Hant", @"ja", @"ko"]) {
        [self chooseLanguage:names[language]];
        for (NSInteger mode = 4; mode <= 6; mode++) {
            [self tap:self.app.buttons[@"book-1"]];
            [self tap:self.app.cells[[NSString stringWithFormat:@"mode-%ld", (long)mode]]];
            [self tap:self.app.buttons[@"alert-choice-1"]];
            XCUIElement *control = mode == 4 ? self.app.buttons[@"dictation-submit"] : self.app.cells[@"test-row-2"];
            XCTAssertTrue([control waitForExistenceWithTimeout:10]);
            [self capture:[NSString stringWithFormat:@"%@-practice-%ld", language, (long)mode]];
            [self back]; [self back];
        }
        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[@"mode-8"]];
        [self capture:[language stringByAppendingString:@"-wordbook"]];
        [self back]; [self back];
    }
    [self chooseLanguage:@"简体中文"];
}

- (void)testJapaneseAndKoreanLearning
{
    NSDictionary *names = @{@"ja": @"日本語", @"ko": @"한국어"};
    NSDictionary *meaningQueries = @{@"ja": @"ソフトウェア", @"ko": @"소프트웨어"};
    NSMutableDictionary *englishSources = [NSMutableDictionary dictionary];
    for (NSString *code in @[@"ja", @"ko"]) {
        [self chooseLanguage:names[code]];
        XCTAssertEqualObjects(self.app.buttons[@"book-1"].label, [code isEqual:@"ja"] ? @"第1巻" : @"제1권");
        [self capture:[code stringByAppendingString:@"-home"]];
        for (NSInteger book = 1; book <= 4; book++) {
            [self tap:self.app.buttons[[NSString stringWithFormat:@"book-%ld", (long)book]]];
            [self tap:self.app.cells[@"mode-0"]];
            if (book == 1) [self capture:[code stringByAppendingString:@"-lesson-list"]];
            [self tap:self.app.cells[@"lesson-0"]];
            [self tap:self.app.buttons[@"lesson-pause"]];
            XCTAssertTrue(self.app.staticTexts[@"lesson-english-0"].label.length > 0);
            NSString *key = [NSString stringWithFormat:@"%ld", (long)book];
            if ([code isEqual:@"ja"]) englishSources[key] = self.app.staticTexts[@"lesson-english-0"].label;
            else XCTAssertEqualObjects(self.app.staticTexts[@"lesson-english-0"].label, englishSources[key]);
            NSString *translation = self.app.staticTexts[@"lesson-translation-0"].label;
            XCTAssertTrue(translation.length > 0);
            if (book == 1) XCTAssertFalse([translation hasPrefix:@"对不起"]);
            [self capture:[NSString stringWithFormat:@"%@-book-%ld-lesson", code, (long)book]];
            [self tap:self.app.buttons[@"lesson-show-translation"]];
            XCTAssertFalse(self.app.staticTexts[@"lesson-translation-0"].exists);
            [self tap:self.app.buttons[@"lesson-show-translation"]];
            XCTAssertTrue(self.app.staticTexts[@"lesson-translation-0"].exists);
            [self back]; [self back]; [self back];
        }
        [self tap:self.app.buttons[@"book-3"]];
        [self tap:self.app.cells[@"mode-7"]];
        XCUIElement *field = self.app.searchFields.firstMatch;
        [self tap:field];
        [field typeText:meaningQueries[code]];
        [self tap:self.app.cells[@"search-word-software"]];
        [self tap:self.app.buttons[@"word-pause"]];
        XCTAssertTrue([self.app.staticTexts[@"word-translation"].label containsString:meaningQueries[code]]);
        XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label, @"software");
        XCTAssertTrue(self.app.images[@"word-image"].exists);
        [self capture:[code stringByAppendingString:@"-software"]];
        [self back]; [self back]; [self back];
        [self tap:self.app.buttons[@"settings"]];
        [self capture:[code stringByAppendingString:@"-settings"]];
        [self back];
    }
    [self chooseLanguage:@"简体中文"];
}

- (void)testJapaneseAndKoreanToolbarAssets
{
    for (NSString *code in @[@"ja", @"ko"]) {
        [self chooseLanguage:[code isEqual:@"ja"] ? @"日本語" : @"한국어"];
        [self tap:self.app.buttons[@"book-3"]];
        [self tap:self.app.cells[@"mode-7"]];
        [self tap:self.app.searchFields.firstMatch];
        [self.app.searchFields.firstMatch typeText:@"software"];
        [self tap:self.app.cells[@"search-word-software"]];
        [self tap:self.app.buttons[@"word-pause"]];
        CGRect viewport = self.app.windows.firstMatch.frame;
        for (NSString *identifier in @[@"word-strange", @"word-vague", @"word-familiar", @"word-repeat"]) {
            XCUIElement *button = self.app.buttons[identifier];
            XCTAssertTrue(button.hittable);
            XCTAssertTrue(CGRectContainsRect(viewport, button.frame));
            XCTAssertTrue(button.label.length > 0);
        }
        [self capture:[code stringByAppendingString:@"-toolbar"]];
        [self tap:self.app.buttons[@"word-strange"]];
        [self tap:self.app.buttons[@"word-vague"]];
        [self tap:self.app.buttons[@"word-familiar"]];
        XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label, @"software");
        [self back]; [self back]; [self back];
        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[@"mode-4"]];
        [self tap:self.app.buttons[@"alert-choice-1"]];
        XCUIElement *repeat = self.app.buttons[@"dictation-repeat"];
        XCTAssertTrue([repeat waitForExistenceWithTimeout:10]);
        XCTAssertTrue(repeat.hittable);
        XCTAssertTrue(CGRectContainsRect(viewport, repeat.frame));
        [self capture:[code stringByAppendingString:@"-dictation-assets"]];
        [self back]; [self back];
    }
    [self chooseLanguage:@"简体中文"];
}

- (void)testJapaneseKoreanChoicePreservesProgress
{
    [self chooseLanguage:@"简体中文"];
    [self tap:self.app.buttons[@"book-1"]];
    [self tap:self.app.cells[@"mode-7"]];
    [self tap:self.app.searchFields.firstMatch];
    [self.app.searchFields.firstMatch typeText:@"handbag"];
    [self tap:self.app.cells[@"search-word-handbag"]];
    [self tap:self.app.buttons[@"word-pause"]];
    [self tap:self.app.buttons[@"word-strange"]];
    [self back]; [self back]; [self back];
    for (NSString *name in @[@"日本語", @"한국어"]) {
        [self chooseLanguage:name];
        [self.app terminate];
        [self.app launch];
        XCTAssertTrue([self.app.buttons[@"book-1"] waitForExistenceWithTimeout:10]);
        XCTAssertEqualObjects(self.app.buttons[@"book-1"].label, [name isEqual:@"日本語"] ? @"第1巻" : @"제1권");
        [self tap:self.app.buttons[@"book-1"]];
        [self tap:self.app.cells[@"mode-8"]];
        [self tap:self.app.cells[@"wordbook-1"]];
        XCUIElement *word = self.app.cells[@"wordbook-word-handbag"];
        if (!word.hittable) [self.app.tables.firstMatch swipeUp];
        [self tap:word];
        [self tap:self.app.buttons[@"word-pause"]];
        XCTAssertEqualObjects(self.app.staticTexts[@"word-english"].label, @"handbag");
        [self capture:[name isEqual:@"日本語"] ? @"ja-progress-retained" : @"ko-progress-retained"];
        [self back]; [self back]; [self back]; [self back];
    }
    [self chooseLanguage:@"简体中文"];
}
@end

//
//  AppDelegate.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "AppDelegate.h"
#import "AdmobManager.h"
#import "FirstViewController.h"
#import "SettingViewController.h"
#import "NCELocalization.h"
#import "NCEAcademyTheme.h"
#import "NCEStartupViewController.h"
#import<AVFoundation/AVFoundation.h>

@interface AppDelegate ()

- (void)configureNavigationBarAppearance;
- (NSError *)prepareDatabase;
- (void)finishStartup:(BOOL)displayedLoading;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
#if DEBUG
    if([AdmobManager isOfflineResourceQA] && [NSProcessInfo.processInfo.arguments containsObject:@"-NCEResetStudyQA"]) {
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        for(NSString *key in defaults.dictionaryRepresentation.allKeys)if([key hasPrefix:@"NCEStudy"] || [key hasPrefix:@"NCEPractice"] || [key hasPrefix:@"NCEAcademy"] || [key isEqual:@"NCELanguagePreference"])[defaults removeObjectForKey:key];
    }
#endif
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = NCEBackground();
    
    [self configureNavigationBarAppearance];
    __weak typeof(self) weakSelf=self;
    self.window.rootViewController = [[NCEStartupViewController alloc] initWithPreparation:^NSError *{
        return [weakSelf prepareDatabase];
    } completion:^(BOOL displayedLoading) {
        [weakSelf finishStartup:displayedLoading];
    }];
    [self.window makeKeyAndVisible];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(languagePreferenceChanged:) name:NCELanguagePreferenceDidChangeNotification object:nil];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // status bar setting
    [application setStatusBarHidden:NO];
    [application setStatusBarStyle:UIStatusBarStyleDefault];
#pragma clang diagnostic pop

    return YES;
}

- (void)finishStartup:(BOOL)displayedLoading
{
    UIViewController *home=NCECreateLearningRoot();
    if(displayedLoading && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView transitionWithView:self.window duration:0.18 options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowAnimatedContent animations:^{
            self.window.rootViewController=home;
        } completion:nil];
    } else { self.window.rootViewController=home; }
    NSError *audioSessionError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];
    [[AVAudioSession sharedInstance] setActive:YES error:&audioSessionError];
    if (audioSessionError) {
        NSLog(@"Audio session setup failed: %@", audioSessionError.localizedDescription);
    }
    
    // admob
    [[AdmobManager sharedInstance] preInit];
    
}

- (void)configureNavigationBarAppearance
{
    NCEConfigureNavigation([UINavigationBar appearance]);
    [UISwitch appearance].onTintColor = NCEBlue();
    [UIProgressView appearance].progressTintColor = NCEBlue();
    [UISlider appearance].minimumTrackTintColor = NCEBlue();
}


- (void)languagePreferenceChanged:(NSNotification *)notification
{
    // Rebuild displayed text and cached lesson/quiz content without restarting services or touching the database.
    dispatch_async(dispatch_get_main_queue(), ^{
        UITabBarController *tabs=NCECreateLearningRoot();
        self.window.rootViewController=tabs;
        UINavigationController *navigation=(UINavigationController *)tabs.viewControllers.firstObject;
        [navigation pushViewController:[SettingViewController new] animated:NO];
    });
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (NSError *)prepareDatabase
{
    NSFileManager *files=NSFileManager.defaultManager;
    NSURL *documents=[files URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *target=[documents URLByAppendingPathComponent:@"NCE.db"];
    // Never replace an existing database containing learning history.
    if([files fileExistsAtPath:target.path])return nil;
    NSURL *source=[NSBundle.mainBundle URLForResource:@"NCE" withExtension:@"db"];
    if(!source)return [NSError errorWithDomain:@"NCEStartup" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Bundled database is missing"}];
    NSError *error=nil;
    if(![files createDirectoryAtURL:documents withIntermediateDirectories:YES attributes:nil error:&error])return error;
    NSURL *temporary=[documents URLByAppendingPathComponent:[NSString stringWithFormat:@"NCE-startup-%@.tmp",NSUUID.UUID.UUIDString]];
    if(![files copyItemAtURL:source toURL:temporary error:&error] || ![files moveItemAtURL:temporary toURL:target error:&error]) {
        [files removeItemAtURL:temporary error:nil];
        return error;
    }
    return nil;
}

@end

//
//  AppDelegate.m
//  NEC_ALL
//
//  Created by Lizi on 02/11/26.
//  Copyright © 2026年 FancyGame. All rights reserved.
//

#import "AppDelegate.h"
#import "AdmobManager.h"
#import "IDFATrackingManager.h"
#import "FirstViewController.h"
#import<AVFoundation/AVFoundation.h>

@interface AppDelegate ()

- (void)configureNavigationBarAppearance;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    [self checkAndCreateDatabase];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor clearColor];
    
    FirstViewController *firstController = [[FirstViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:firstController];
    [self configureNavigationBarAppearance];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // status bar setting
    [application setStatusBarHidden:NO];
    [application setStatusBarStyle:UIStatusBarStyleLightContent];
#pragma clang diagnostic pop

    NSError *audioSessionError = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];
    [[AVAudioSession sharedInstance] setActive:YES error:&audioSessionError];
    if (audioSessionError) {
        NSLog(@"Audio session setup failed: %@", audioSessionError.localizedDescription);
    }
    
    // admob
    [[AdmobManager sharedInstance] preInit];
    
    return YES;
}

- (void)configureNavigationBarAppearance
{
    UIImage *image = [UIImage imageNamed:@"bg_navigation"];
    if (image) {
        image = [image stretchableImageWithLeftCapWidth:floorf(image.size.width / 2.0f)
                                           topCapHeight:floorf(image.size.height / 2.0f)];
    }

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        if (image) {
            appearance.backgroundImage = image;
        }
        appearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};

        UIBarButtonItemAppearance *plain = [[UIBarButtonItemAppearance alloc] initWithStyle:UIBarButtonItemStylePlain];
        [plain.normal setBackgroundImage:nil];
        [plain.highlighted setBackgroundImage:nil];
        [plain.focused setBackgroundImage:nil];
        [plain.disabled setBackgroundImage:nil];
        plain.normal.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
        plain.highlighted.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
        plain.focused.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
        plain.disabled.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};

        appearance.buttonAppearance = plain;
        appearance.doneButtonAppearance = plain;
        appearance.backButtonAppearance = plain;

        UINavigationBar *bar = [UINavigationBar appearance];
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
        bar.compactAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            bar.compactScrollEdgeAppearance = appearance;
        }
        bar.tintColor = UIColor.whiteColor;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIBarButtonItem *barButtonAppearance = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UINavigationBar class]]];
        UIImage *clearImage = [UIImage new];
        [barButtonAppearance setBackgroundImage:clearImage forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [barButtonAppearance setBackgroundImage:clearImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [barButtonAppearance setBackgroundImage:clearImage forState:UIControlStateDisabled barMetrics:UIBarMetricsDefault];
        [barButtonAppearance setBackButtonBackgroundImage:clearImage forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [barButtonAppearance setBackButtonBackgroundImage:clearImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
#pragma clang diagnostic pop
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if (image) {
            [[UINavigationBar appearance] setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
        }
#pragma clang diagnostic pop
        [[UINavigationBar appearance] setTintColor:UIColor.whiteColor];
    }
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
    [[IDFATrackingManager sharedInstance] requestIDFA];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)checkAndCreateDatabase
{
    BOOL success;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *databasePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"NCE.db"];
    success = [fileManager fileExistsAtPath:databasePath];
    if (success) {
        NSLog(@"doworking");
        return;
    } else{
        NSLog(@"notworking");
        NSString *databasePathFromApp = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"NCE.db"];
        [fileManager copyItemAtPath:databasePathFromApp toPath:databasePath error:nil];
    }
}

@end

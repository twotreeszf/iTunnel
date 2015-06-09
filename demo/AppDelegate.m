//
//  AppDelegate.m
//  demo
//
//  Created by fanzhang on 15/6/8.
//  Copyright (c) 2015年 fanzhang. All rights reserved.
//

#import "AppDelegate.h"
#import "../iTunnel/iTunnel.h"

@interface AppDelegate ()
{
    iTunnel* _tunnel;
}

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _tunnel = [iTunnel new];

    /*
    // generate rsa key pair
    NSString* tempPath = NSTemporaryDirectory();
    NSString* privateKey = [tempPath stringByAppendingPathComponent:@"private.txt"];
    NSString* publicKey = [tempPath stringByAppendingPathComponent:@"public.txt"];
    
    BOOL ret = [tunnel generateNewKeyPair:privateKey :publicKey];
    */
    
    NSString* keyFolder = [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"KeyPair"];
    NSString* privateKey = [keyFolder stringByAppendingPathComponent:@"private.txt"];

    [_tunnel startForwarding:7777 :@"162.243.131.71" :22 :@"fasttunnel" :privateKey :@"google.com" :80];
        
    return YES;
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

@end

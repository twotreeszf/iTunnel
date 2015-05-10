//
//  iTunnel.h
//  iTunnel
//
//  Created by fanzhang on 15/5/10.
//  Copyright (c) 2015年 fanzhang. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ITStatusDelegate <NSObject>
@optional
- (void) sshLoginFailed: (int)error;
- (void) sshLoginSuccessed;
- (void) sshSessionLost;
@end

@interface iTunnel : NSObject

@property(nonatomic, weak) id<ITStatusDelegate> delegate;

- (BOOL)generateNewKeyPair: (NSString*)privateKeyPath : (NSString*)publicKeyPath;
- (BOOL)startForwarding: (NSUInteger)localPort
                       : (NSString*)remoteHost
                       : (NSUInteger)remotePort
                       : (NSString*)privateKeyPath
                       : (NSString*)publicKeyPath;
- (BOOL)stopForwarding;

@end

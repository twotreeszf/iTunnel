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

@property (nonatomic, weak) id<ITStatusDelegate>    delegate;
@property (nonatomic, readonly) uint16_t            listeningPort;
@property (nonatomic, copy, readonly) NSString*     destHost;
@property (nonatomic, readonly) uint16_t            destPort;
@property (nonatomic, readonly) BOOL                connected;

@property (nonatomic, readonly) NSUInteger          connectionCount;
@property (nonatomic, readonly) NSUInteger          totalBytesWritten;
@property (nonatomic, readonly) NSUInteger          totalBytesRead;


- (BOOL)generateNewKeyPair: (NSString*)privateKeyPath : (NSString*)publicKeyPath;

- (void)startForwarding: (NSUInteger)localPort
                       : (NSString*)remoteHost
                       : (NSUInteger)remotePort
                       : (NSString*)userName
                       : (NSString*)privateKeyPath
                       : (NSString*)destHost
                       : (NSUInteger)destPort;

- (void)stopForwarding;

- (void)resetNetworkStatistics;

@end

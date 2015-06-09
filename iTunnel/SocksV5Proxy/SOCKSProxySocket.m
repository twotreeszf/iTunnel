//
//  SOCKSProxySocket.m
//  Tether
//
//  Created by Christopher Ballinger on 11/26/13.
//  Copyright (c) 2013 Christopher Ballinger. All rights reserved.
//

// Define various socket tags
#define SOCKS_OPEN					10100
#define SOCKS_CONNECT_INIT			10200
#define SOCKS_CONNECT_IPv4			10201
#define SOCKS_CONNECT_DOMAIN		10202
#define SOCKS_CONNECT_DOMAIN_LENGTH 10212
#define SOCKS_CONNECT_IPv6			10203
#define SOCKS_CONNECT_PORT			10210
#define SOCKS_CONNECT_REPLY			10300
#define SOCKS_INCOMING_READ			10400
#define SOCKS_INCOMING_WRITE		10401

// Timeouts
#define TIMEOUT_LOCAL_READ	5.00
#define TIMEOUT_TOTAL		80.00

#import "SOCKSProxySocket.h"
#include <arpa/inet.h>

@interface SOCKSProxySocket ()
{
	GCDAsyncSocket*		_proxySocket;
	dispatch_queue_t	_socketQueue;
}
@end

@implementation SOCKSProxySocket

- (NSString*)localHost
{
	NSString* host = _proxySocket.connectedHost;
	return host ? host : @"";
}

- (uint16_t)localPort
{
	return _proxySocket.connectedPort;
}

- (id)initWithSocket:(GCDAsyncSocket *)socket
            Delegate:(id<SOCKSProxySocketDelegate>)delegate
            DestHost: (NSString*)destHost
            DestPort: (uint16_t)destPort
{
    if (self = [super init])
    {
        _delegate = delegate;
        
        _socketQueue = dispatch_get_main_queue();
        
        _proxySocket = socket;
        _proxySocket.delegate = self;
        _proxySocket.delegateQueue = _socketQueue;
        
        _state = PSS_RequestNewChannel;
        _destinationHost = destHost;
        _destinationPort = destPort;
        _writeDataQueue = [NSMutableArray new];
    }
    return self;
}

- (void)socket:(GCDAsyncSocket*)sock
    didReadData:(NSData*)data
        withTag:(long)tag
{
    if (tag == SOCKS_INCOMING_READ)
    {
		@synchronized (_writeDataQueue)
		{
			[_writeDataQueue enqueue:data];
		}
		
		[_proxySocket readDataWithTimeout:-1 tag:SOCKS_INCOMING_READ];
    }
}

- (void)relayConnctionReady
{
	dispatch_async(_socketQueue, ^
	{
		[_proxySocket readDataWithTimeout:-1 tag:SOCKS_INCOMING_READ];
	});
}

- (void)relayRemoteData:(NSData*)data
{
    dispatch_async(_socketQueue, ^
	{
		[_proxySocket writeData:data withTimeout:-1 tag:SOCKS_INCOMING_WRITE];
		NSUInteger dataLength = data.length;
		_totalBytesRead += dataLength;
	 
		if (self.delegate && [self.delegate respondsToSelector:@selector(proxySocket:didReadDataOfLength:)])
		{
			dispatch_async(dispatch_get_main_queue(), ^
			{
				[self.delegate proxySocket:self didReadDataOfLength:dataLength];
			});
		}
    });
}

- (void)disconnectLocal
{
	dispatch_async(_socketQueue, ^
	{
		[_proxySocket disconnect];
	});
}

- (void)didClosed
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(proxySocketDidDisconnect:withError:)])
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate proxySocketDidDisconnect:self withError:nil];
		});
	}
}

- (void)didWriteData:(NSUInteger)length
{
	dispatch_async(_socketQueue, ^
	{
		_totalBytesRead += length;
		 
		if (self.delegate && [self.delegate respondsToSelector:@selector(proxySocket:didReadDataOfLength:)])
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.delegate proxySocket:self didReadDataOfLength:length];
			});
		}
    });
}

- (void)socketDidDisconnect:(GCDAsyncSocket*)sock withError:(NSError*)err
{
	_state = PSS_RequestCloseChannel;
}

@end

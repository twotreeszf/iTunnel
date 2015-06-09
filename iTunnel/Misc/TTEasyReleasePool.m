//
//  TTCFEasyRelease.m
//  PrettyTunnel
//
//  Created by zhang fan on 15/1/16.
//
//

#import "TTEasyReleasePool.h"

@implementation TTEasyReleasePool
{
	NSMutableArray* _objs;
}

- (instancetype)init
{
	self = [super init];
	
	_objs = [NSMutableArray new];
	
	return self;
}

- (void)dealloc
{
    for (void (^ block)() in _objs)
    {
        block();
    }
}

- (void)autoreleaseCF:(CFTypeRef)obj
{
    [_objs insertObject:^{ CFRelease(obj); } atIndex:0];
}

- (void)autoreleaseBlock: (void (^)(void))block
{
    [_objs insertObject:block atIndex:0];
}

@end

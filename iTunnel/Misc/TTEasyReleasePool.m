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
    while ([_objs count])
    {
        void (^ block)() = [_objs pop];
        block();
    }
}

- (void)autoreleaseCF:(CFTypeRef)obj
{
    [_objs push:^
    {
        CFRelease(obj);
    }];
}

- (void)autoreleaseBlock: (void (^)(void))block
{
    [_objs push:block];
}

@end

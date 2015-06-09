//
//  NSMutableArray+Stack.m
//  PrettyTunnel
//
//  Created by zhang fan on 14-8-7.
//
//

#import "NSMutableArray+Stack.h"

@implementation NSMutableArray (Stack)

- (id)popStack
{
	if (![self count])
		return nil;
	
    id lastObject = [self lastObject];
	[self removeLastObject];
	
    return lastObject;
}

- (void)pushStack:(id)obj
{
	[self addObject: obj];
}

@end

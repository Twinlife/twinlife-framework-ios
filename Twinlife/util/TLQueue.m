/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <stdlib.h>
#import <libkern/OSAtomic.h>

#import <CocoaLumberjack.h>

#import "TLQueue.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLQueue
//

@interface TLQueue ()

@property (readonly, nonnull) NSComparator comparator;

@end

//
// Implementation: TLQueue
//

#undef LOG_TAG
#define LOG_TAG @"TLQueue"

@implementation TLQueue

- (nonnull instancetype)initWithComparator:(nonnull NSComparator)comparator {
    DDLogVerbose(@"%@ initWithComparator: %@", LOG_TAG, comparator);
    
    self = [super init];
    if (self) {
        _queue = [[NSMutableArray alloc] init];
        _comparator = comparator;
    }
    return self;
}

- (NSUInteger)count {
    
    return self.queue.count;
}

- (void)addObject:(nonnull id<NSObject>)object allowDuplicate:(BOOL)allowDuplicate {
    DDLogVerbose(@"%@ addObject: %@", LOG_TAG, object);

    NSUInteger count = self.queue.count;
    if (count == 0) {
        [self.queue addObject:object];
        return;
    }
    
    // Use a dichotomic search to find the position where the new object is inserted.
    NSUInteger mid = 0;
    NSUInteger low = 0;
    NSUInteger high = count - 1;
    while (low <= high) {
        mid = (low + high) / 2;

        NSComparisonResult result = self.comparator(object, self.queue[mid]);
        
        if (result == NSOrderedSame) {
            // Object already in queue, insert only if we allow duplicate entries.
            if (allowDuplicate) {
                [self.queue insertObject:object atIndex:mid + 1];
            }
            return;

        } else if (result == NSOrderedAscending) {
            if (mid == 0) {
                [self.queue insertObject:object atIndex:mid];
                return;
            }
            high = mid - 1;
        } else {
            low = mid + 1;
        }
    }
    [self.queue insertObject:object atIndex:low];
}

- (void)removeObject:(nonnull id<NSObject>)object {
    DDLogVerbose(@"%@ removeObject", LOG_TAG);

    [self.queue removeObject:object];
}

- (BOOL)containsObject:(nonnull id<NSObject>)object {
    DDLogVerbose(@"%@ containsObject: %@", LOG_TAG, object);

    return [self.queue containsObject:object];
}

- (nullable id<NSObject>)firstObject {
    DDLogVerbose(@"%@ firstObject", LOG_TAG);

    if (self.queue.count == 0) {
        return nil;
    } else {
        return self.queue[0];
    }
}

- (nullable id<NSObject>)peekObject {
    DDLogVerbose(@"%@ peekObject", LOG_TAG);

    if (self.queue.count == 0) {
        return nil;
    } else {
        id<NSObject> result = self.queue[0];
        
        [self.queue removeObjectAtIndex:0];
        return result;
    }
}

- (void)removeAllObjects {
    DDLogVerbose(@"%@ removeAllObjects", LOG_TAG);

    [self.queue removeAllObjects];
}

@end

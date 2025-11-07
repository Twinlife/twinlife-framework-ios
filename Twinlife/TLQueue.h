/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLQueue ()
//

@interface TLQueue : NSObject

@property (readonly, nonnull) NSMutableArray *queue;

/// Create the queue with the comparator object.
- (nonnull instancetype)initWithComparator:(nonnull NSComparator)comparator;

/// Get the number of elements in the queue.
- (NSUInteger)count;

/// Add the object in the queue at the position defined by the queue comparator.
- (void)addObject:(nonnull id<NSObject>)object allowDuplicate:(BOOL)allowDuplicate;

/// Remove the object from the queue.
- (void)removeObject:(nonnull id<NSObject>)object;

/// Check if the given object is in the queue.
- (BOOL)containsObject:(nonnull id<NSObject>)object;

/// Get the first object but do not remove it.
- (nullable id<NSObject>)firstObject;

/// Get and remove the first object from the queue.
- (nullable id<NSObject>)peekObject;

/// Remove all objects from the queue.
- (void)removeAllObjects;

@end

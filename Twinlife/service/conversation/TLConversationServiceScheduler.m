/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <stdlib.h>
#import <libkern/OSAtomic.h>

#import <CocoaLumberjack.h>

#import "TLQueue.h"
#import "TLConversationServiceImpl.h"
#import "TLConversationServiceScheduler.h"
#import "TLJobServiceImpl.h"

#import "TLTwinlifeImpl.h"
#import "TLConversationServiceIQ.h"
#import "TLConversationServiceProvider.h"
#import "TLGroupConversationImpl.h"
#import "TLPushFileOperation.h"
#import "TLPushObjectOperation.h"
#import "TLPushTwincodeOperation.h"
#import "TLPushGeolocationOperation.h"
#import "TLGroupOperation.h"
#import "TLConversationConnection.h"

#if 0
// static const int ddLogLevel = DDLogLevelVerbose;
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

// Limit the number of P2P conversation that can be opened at a time.
// If we are running in foreground, a higher limit is used.
static const int MAX_ACTIVE_CONVERSATIONS = 12;
static const int MAX_FOREGROUND_ACTIVE_CONVERSATIONS = 12;
static const int MAX_BACKGROUND_ACTIVE_CONVERSATIONS = 8;
static const int64_t DELAY_AFTER_ONLINE = 500; // ms to wait after we get online to schedule operations
static const int64_t DELAY_BEFORE_SCHEDULE = 500; // ms to wait after scheduling again some operations
static const int64_t MAX_FOREGROUND_IDLE_TIME = 120 * 1000; // ms
static const int64_t MAX_BACKGROUND_IDLE_TIME = 5 * 1000; // ms
static const NSTimeInterval IDLE_FOREGROUND_FIRST_CHECK_DELAY = 10.0; // First check on idle P2P connection after 10s.
static const NSTimeInterval IDLE_BACKGROUND_FIRST_CHECK_DELAY = 1.0; // First check on idle P2P connection after 1s.
static const NSTimeInterval IDLE_FOREGROUND_CHECK_DELAY = 5.0; // Then, other check for idle P2P connection each 5s.
static const NSTimeInterval IDLE_BACKGROUND_CHECK_DELAY = 1.0; // Then, other check for idle P2P connection each 1s.
static const NSTimeInterval RETRY_IMMEDIATELY_DELAY = 0.5; // Time to wait before retrying a P2P connection.
static const double TIME_INFINITY = 1.0e10; // A very long time in ms.
static const int64_t EXPIRATION_DELAY = 14 * 24 * 3600 * 1000; // ms (14 days)

//
// Interface: TLConversationOperationQueue
//

@interface TLConversationOperationQueue : TLQueue

@property (readonly, nonnull) TLDatabaseIdentifier *conversationId;
@property (nullable) TLConversationImpl *conversationImpl;
@property NSDate *deadline;

- (nonnull instancetype) initWithConversation:(nonnull TLConversationImpl *)conversation;

- (nonnull instancetype) initWithConversationId:(nonnull TLDatabaseIdentifier *)conversationId;

- (void)removeOperationsWithList:(nonnull NSMutableArray<NSNumber *> *)list;

@end

//
// Interface: TLConversationServiceScheduler
//

@interface TLConversationServiceScheduler ()<TLJob, TLBackgroundJobObserver>

@property (readonly, nonnull) TLTwinlife *twinlife;
@property (readonly, nonnull) TLJobService *jobService;
@property (readonly, nonnull) TLConversationService *conversationService;
@property (readonly, nonnull) NSMutableArray<TLConversationOperationQueue*> *activeOperations;
@property (readonly, nonnull) NSMutableArray<TLConversationConnection*> *activeConnections;
@property (readonly, nonnull) TLQueue *waitingOperations;
@property (readonly, nonnull) NSMutableDictionary<TLDatabaseIdentifier*, TLConversationOperationQueue*> *conversationId2Operations;
@property (readonly, nonnull) TLConversationServiceProvider *serviceProvider;
@property (readonly, nonnull) dispatch_queue_t executorQueue;
@property (nullable) NSMutableDictionary<TLDatabaseIdentifier*, NSMutableArray<TLConversationServiceOperation *>*> *deferredOperations;
@property (nullable) TLJobId *scheduleJobId;
@property (nullable) NSDate *nextIdleCheckTime;
@property BOOL isReschedulePending;

/// Called when the application goes in background.
- (void)onEnterBackground;

/// Schedule the operations to be executed once we are online.
- (void)scheduleOperations;

- (void)prepareOperationsWithList:(nonnull NSArray<TLConversationOperationQueue *> *)list;

@end

//
// Implementation: TLConversationOperationQueue
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationOperationQueue"

@implementation TLConversationOperationQueue

- (nonnull instancetype) initWithConversation:(nonnull TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ initWithConversation: %@", LOG_TAG, conversation.identifier);

    self = [super initWithComparator:^NSComparisonResult(id<NSObject> obj1, id<NSObject> obj2) {
        TLConversationServiceOperation *operation1 = (TLConversationServiceOperation *)obj1;
        TLConversationServiceOperation *operation2 = (TLConversationServiceOperation *)obj2;
        
        return [operation1 compareWithOperation:operation2];
    }];
    if (self) {
        _conversationId = conversation.identifier;
        _conversationImpl = conversation;
    }
    return self;
}

- (nonnull instancetype) initWithConversationId:(nonnull TLDatabaseIdentifier *)conversationId {
    DDLogVerbose(@"%@ initWithConversationId: %@", LOG_TAG, conversationId);
    
    self = [super initWithComparator:^NSComparisonResult(id<NSObject> obj1, id<NSObject> obj2) {
        TLConversationServiceOperation *operation1 = (TLConversationServiceOperation *)obj1;
        TLConversationServiceOperation *operation2 = (TLConversationServiceOperation *)obj2;
        
        return [operation1 compareWithOperation:operation2];
    }];
    if (self) {
        _conversationId = conversationId;
    }
    return self;
}

- (NSComparisonResult)compareWithOperationQueue:(nonnull TLConversationOperationQueue *)queue {

    // If there is a deadline, sort on it.
    if (self.deadline && queue.deadline) {
        NSComparisonResult result = [self.deadline compare:queue.deadline];
        if (result != NSOrderedSame) {
            return result;
        }
    } else if (queue.deadline) {
        return NSOrderedAscending;
    } else if (self.deadline) {
        return NSOrderedDescending;
    }

    if (self.queue.count == 0) {
        return NSOrderedDescending;
    }
    if (queue.queue.count == 0) {
        return NSOrderedAscending;
    }

    // Look at the first operation.
    TLConversationServiceOperation *operation1 = self.queue[0];
    TLConversationServiceOperation *operation2 = queue.queue[0];
    return operation1.timestamp < operation2.timestamp ? NSOrderedAscending : NSOrderedDescending;
}

- (void)removeOperationsWithList:(nonnull NSMutableArray<NSNumber *> *)list {
    DDLogVerbose(@"%@ removeOperationsWithList: %@", LOG_TAG, list);

    long count = self.queue.count;
    if (count == 0) {
        
        return;
    }

    for (long i = 0; i < count; i++) {
        TLConversationServiceOperation *operation = self.queue[i];

        for (NSNumber *op in list) {
            if (operation.id == op.longLongValue) {
                [list removeObject:op];
                [self.queue removeObjectAtIndex:i];
                i--;
                count--;
                break;
            }
        }
    }
}

@end

//
// Implementation: TLConversationServiceScheduler
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceScheduler"

@implementation TLConversationServiceScheduler

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife conversationService:(nonnull TLConversationService *)conversationService serviceProvider:(nonnull TLConversationServiceProvider *)serviceProvider executorQueue:(nonnull dispatch_queue_t)executorQueue {
    DDLogVerbose(@"%@ initWithTwinlife: %@ conversationService: %@ serviceProvider: %@", LOG_TAG, twinlife, conversationService, serviceProvider);

    self = [super init];
    if (self) {
        _twinlife = twinlife;
        _jobService = [twinlife getJobService];
        _jobService.backgroundJobObserver = self;
        _conversationId2Operations = [[NSMutableDictionary alloc] init];
        _conversationService = conversationService;
        _activeOperations = [[NSMutableArray alloc] initWithCapacity:MAX_ACTIVE_CONVERSATIONS];
        _activeConnections = [[NSMutableArray alloc] initWithCapacity:MAX_ACTIVE_CONVERSATIONS];
        _serviceProvider = serviceProvider;
        _isReschedulePending = NO;
        _waitingOperations = [[TLQueue alloc] initWithComparator:^NSComparisonResult(id<NSObject> obj1, id<NSObject> obj2) {
            TLConversationOperationQueue *queue1 = (TLConversationOperationQueue *)obj1;
            TLConversationOperationQueue *queue2 = (TLConversationOperationQueue *)obj2;
            
            return [queue1 compareWithOperationQueue:queue2];
        }];
        _executorQueue = executorQueue;
    }
    return self;
}

#pragma mark - Initialization methods

- (void)loadOperations {
    DDLogVerbose(@"%@ loadOperations", LOG_TAG);
    
    dispatch_async(self.executorQueue, ^{
        [self loadOperationsInternal];
    });
}

- (void)loadOperationsInternal {
    DDLogVerbose(@"%@ loadOperationsInternal", LOG_TAG);

    NSMutableDictionary<TLDatabaseIdentifier *, NSMutableArray<TLConversationServiceOperation *> *> *operations = [self.serviceProvider loadOperations];
    NSMutableArray<TLConversationServiceOperation *> *expiredOperations = nil;
    NSMutableArray<TLConversationOperationQueue *> *toUpdateList = nil;
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t expireDeadline = now - EXPIRATION_DELAY;
    BOOL hasOperations = NO;
    @synchronized(self) {
        // Step 1: remove the conversations which have no operations
        // (we must use allKeys due to the removeObject being called while we iterate).
        for (TLDatabaseIdentifier *conversationId in [self.conversationId2Operations allKeys]) {
            if (!operations[conversationId]) {
                [self.conversationId2Operations removeObjectForKey:conversationId];
            }
        }

        // Step 2: remove the operations which have been processed and add the new ones.
        for (TLDatabaseIdentifier *conversationId in operations) {
            NSMutableArray<TLConversationServiceOperation *> *list = operations[conversationId];

            TLConversationOperationQueue *lOperations = self.conversationId2Operations[conversationId];
            BOOL created = !lOperations;
            if (created) {
                lOperations = [[TLConversationOperationQueue alloc] initWithConversationId:conversationId];
            } else {
                // Clear everything.
                [lOperations removeAllObjects];
            }

            for (TLConversationServiceOperation *operation in list) {
                
                // If the operation is queued for a very long time, update the associated descriptor and drop it.
                if (operation.timestamp < expireDeadline) {
                    if (!expiredOperations) {
                        expiredOperations = [[NSMutableArray alloc] init];
                    }
                    [expiredOperations addObject:operation];
                    continue;
                }
                
                [lOperations addObject:operation allowDuplicate:NO];
                hasOperations = YES;
            }

            // Collect the waiting operations when all the operation queues are known and initialized (for the comparison).
            if (lOperations.count > 0) {
                if (created) {
                    self.conversationId2Operations[conversationId] = lOperations;
                }
                if (!toUpdateList) {
                    toUpdateList = [[NSMutableArray alloc] init];
                }
                [toUpdateList addObject:lOperations];
            }
        }
    }
    
    DDLogInfo(@"%@ loadOperationsInternal loaded %lu conversations", LOG_TAG, (unsigned long)operations.count);

    // If we have at least one operation, load the conversations so that we know the group and their members.
    if (toUpdateList) {
        [self prepareOperationsWithList:toUpdateList];
    }

    // If we are online, prepare and schedule the operations.
    if (hasOperations && [self.conversationService isTwinlifeOnline]) {
        [self scheduleOperations];
    }

    if (expiredOperations) {
        DDLogInfo(@"%@ loadOperationsInternal found %lu expired operations", LOG_TAG, (unsigned long)expiredOperations.count);

        [self expireWithOperations:expiredOperations];
    }
}

- (void)expireOperationWithDescriptorId:(int64_t)descriptorId {
    DDLogVerbose(@"%@ expireOperationWithDescriptorId: %lld", LOG_TAG, descriptorId);

    TLDescriptor * descriptor = [self.serviceProvider loadDescriptorWithId:descriptorId];

    if (descriptor && descriptor.sentTimestamp == 0) {
        // Mark the descriptor to show that the send operation failed.
        descriptor.sentTimestamp = -1;
        descriptor.receivedTimestamp = -1;
        descriptor.readTimestamp = -1;
        [self.serviceProvider updateDescriptorTimestamps:descriptor];
    }
}

- (void)expireWithOperations:(nonnull NSMutableArray<TLConversationServiceOperation *> *)operations {
    DDLogVerbose(@"%@ expireWithOperations", LOG_TAG);

    for (TLConversationServiceOperation *operation in operations) {
        switch (operation.type) {
            case TLConversationServiceOperationTypePushFile: {
                TLPushFileOperation *fileOperation = (TLPushFileOperation *)operation;
                
                [self expireOperationWithDescriptorId:fileOperation.descriptor];
                break;
            }
            case TLConversationServiceOperationTypePushObject: {
                TLPushObjectOperation *objectOperation = (TLPushObjectOperation *)operation;
                
                [self expireOperationWithDescriptorId:objectOperation.descriptor];
                break;
            }
            case TLConversationServiceOperationTypePushTwincode: {
                TLPushTwincodeOperation *twincodeOperation = (TLPushTwincodeOperation *)operation;
                
                [self expireOperationWithDescriptorId:twincodeOperation.descriptor];
                break;
            }
            case TLConversationServiceOperationTypePushGeolocation: {
                TLPushGeolocationOperation *geolocationOperation = (TLPushGeolocationOperation *)operation;
                
                [self expireOperationWithDescriptorId:geolocationOperation.descriptor];
                break;
            }
            case TLConversationServiceOperationTypeInviteGroup: {
                TLGroupOperation *groupOperation = (TLGroupOperation *)operation;
                
                [self expireOperationWithDescriptorId:groupOperation.descriptor];
                break;
            }
            case TLConversationServiceOperationTypeWithdrawInviteGroup: {
                TLGroupOperation *groupOperation = (TLGroupOperation *)operation;
                
                [self expireOperationWithDescriptorId:groupOperation.descriptor];
                break;
            }

            case TLConversationServiceOperationTypeJoinGroup:
            case TLConversationServiceOperationTypeLeaveGroup:
            case TLConversationServiceOperationTypeUpdateDescriptorTimestamp:
            case TLConversationServiceOperationTypeUpdateGroupMember:
            case TLConversationServiceOperationTypeResetConversation:
            case TLConversationServiceOperationTypePushTransientObject:
            case TLConversationServiceOperationTypeSynchronizeConversation:
            case TLConversationServiceOperationTypePushCommand:
            case TLConversationServiceOperationTypeUpdateAnnotations:
            case TLConversationServiceOperationTypeInvokeJoinGroup:
            case TLConversationServiceOperationTypeInvokeLeaveGroup:
            case TLConversationServiceOperationTypeInvokeAddMember:
            case TLConversationServiceOperationTypeUpdateObject:
                // No descriptor to update.
                break;
        }

        [self.serviceProvider deleteOperationWithOperationId:operation.id];
    }
}

- (void)prepareOperationsWithList:(nonnull NSArray<TLConversationOperationQueue *> *)list {
    DDLogInfo(@"%@ prepareOperationsWithList prepare %lu operation queues", LOG_TAG, (unsigned long)list.count);
    
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    
    // Find the conversation object and prepare it to start scheduling its operations.
    for (TLConversationOperationQueue *operations in list) {
        id<TLConversation> conversation = operations.conversationImpl;
        if (!conversation) {
            conversation = [self.conversationService getConversationWithId:operations.conversationId];
        }
        if (conversation && ![conversation isKindOfClass:[TLGroupConversationImpl class]]) {
            TLConversationImpl *conversationImpl = (TLConversationImpl *)conversation;
            
            operations.conversationImpl = conversationImpl;
            
            // Compute a deadline to execute the operations based on:
            // - the last retry time,
            // - the last delay position that was configured and saved in the database
            int64_t deadline;
            if (conversationImpl.lastRetryTime > 0 && conversationImpl.lastConnectTime <= conversationImpl.lastRetryTime) {
                deadline = conversationImpl.lastRetryTime + conversationImpl.delay + 10 * conversationImpl.delayPos;
            } else {
                deadline = now;
            }
            operations.deadline = [[NSDate alloc] initWithTimeIntervalSince1970:deadline / 1000.0];
            DDLogInfo(@"%@ deadline for %@: %@", LOG_TAG, conversationImpl.databaseId, operations.deadline);
            // Reset the retry delay to make sure we are trying to connect again.
            //[conversationImpl resetDelay];
            
        } else {
            for (TLConversationServiceOperation *operation in operations.queue) {
                [self.serviceProvider deleteOperationWithOperationId:operation.id];
            }
        }
    }

    @synchronized(self) {
        // Step 1: clear the waiting queue because we are adding/removing entries (=> change order).
        [self.waitingOperations removeAllObjects];

        // Find the conversation object and prepare it to start scheduling its operations.
        for (TLConversationOperationQueue *operations in list) {
            if (operations.conversationImpl) {
                [self.waitingOperations addObject:operations allowDuplicate:NO];
            } else {
                [self.conversationId2Operations removeObjectForKey:operations.conversationId];
            }
        }
    }
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@: onTwinlifeOnline", LOG_TAG);

    // Invalidate a possible job that was created in the past.  If it is still enabled, the runJob()
    // could be executed immediately when that job has expired and because we are also online,
    // this would execute `scheduleOperations()` and we could try to start creating outgoing P2P
    // connections before the DELAY_AFTER_ONLINE below (we want to accept first incoming P2P).
    if (self.scheduleJobId) {
        [self.scheduleJobId cancel];
        self.scheduleJobId = nil;
    }

    // A twinlife::conversation::synchronize was asked in the past but it didn't complete.
    // do it immediately because we have the connection to Twinlife server and this may not
    // be the case if the P2P connection reaches the timeout.
    for (TLConversationOperationQueue *operations in self.waitingOperations.queue) {
        TLConversationImpl *conversationImpl = operations.conversationImpl;
        if (conversationImpl && conversationImpl.needSynchronize) {
            [self.conversationService askConversationSynchronizeWithConversation:conversationImpl];
        }
    }

    if ([self.jobService isForeground]) {
        [self scheduleOperations];
    } else {
        // When we are in background and get the connection, there is a great chance that we are
        // awaken due to a push and we can receive an incoming P2P connection.
        // It's best to process them before trying to create outgoing P2P connections.  The goal is
        // to reduce the possible BUSY termination that occurs when the 2 devices open a P2P
        // connection at the same time.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, DELAY_AFTER_ONLINE * NSEC_PER_MSEC), self.executorQueue, ^{
            [self scheduleOperations];
        });
    }
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@: onTwinlifeSuspend", LOG_TAG);

    @synchronized(self) {
        [self.activeOperations removeAllObjects];
        [self.waitingOperations removeAllObjects];
        [self.activeConnections removeAllObjects];
        [self.conversationId2Operations removeAllObjects];
    }
}

#pragma mark - JobService

- (void)onEnterBackground {
    DDLogVerbose(@"%@ onEnterBackground", LOG_TAG);

    BOOL schedule = NO;
    @synchronized (self) {
        if (!self.deferredOperations) {
            return;
        }

        // Move the deferrable operations to their final operation queue.
        for (TLDatabaseIdentifier *conversationId in self.deferredOperations) {
            NSMutableArray<TLConversationServiceOperation *> *deferredList = self.deferredOperations[conversationId];
            id<TLConversation> conversation = [self.conversationService getConversationWithId:conversationId];
            if (!conversation || !deferredList) {
                continue;
            }

            BOOL isActive = [self.activeConnections containsObject:conversation];
            TLConversationOperationQueue *operations = self.conversationId2Operations[conversationId];
            if (!operations) {
                operations = [[TLConversationOperationQueue alloc] initWithConversation:conversation];
                self.conversationId2Operations[conversationId] = operations;

            } else {
                // Temporarily remove the operations from the waiting list because adding an item may re-order the list.
                if (!isActive) {
                    [self.waitingOperations removeObject:operations];
                }
            }
            for (TLConversationServiceOperation *operation in deferredList) {
                [operations addObject:operation allowDuplicate:NO];
            }
            if (!isActive) {
                [self.waitingOperations addObject:operations allowDuplicate:NO];
            }
            schedule = isActive || self.activeOperations.count < MAX_BACKGROUND_ACTIVE_CONVERSATIONS;
        }

        self.deferredOperations = nil;
    }

    if (schedule) {
        [self scheduleOperations];
    }
}

#pragma mark - Scheduler methods

- (int)getActiveConversationsLimit {

    int limit = [self.jobService isForeground] ? MAX_FOREGROUND_ACTIVE_CONVERSATIONS : MAX_BACKGROUND_ACTIVE_CONVERSATIONS;

    DDLogInfo(@"%@ getActiveConversationsLimit=%d", LOG_TAG, limit);

    return limit;
}

- (void)scheduleOperationsWithConversation:(nonnull TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ scheduleOperationsWithConversation: %@", LOG_TAG, conversation.identifier);

    BOOL canExecute;
    int limit = [self getActiveConversationsLimit];
    TLConversationOperationQueue *operations;
    @synchronized(self) {
        operations = self.conversationId2Operations[conversation.identifier];
        
        if (!operations || operations.count == 0) {
            return;
        }
        canExecute = conversation.connection != nil;
        if (!canExecute && [conversation hasPeer] && [self.twinlife isTwinlifeOnline]) {
            canExecute = ((self.activeOperations.count < limit)
                          && (!operations.deadline || [[NSDate date] compare:operations.deadline] != NSOrderedAscending));
        }
    }
    if (canExecute) {
        [self.conversationService executeOperationWithConversation:conversation];
    }
}

- (void)scheduleJobWithDelay:(NSTimeInterval)delay {
    DDLogVerbose(@"%@ scheduleJobWithDelay: %f", LOG_TAG, delay);

    if (self.scheduleJobId) {
        [self.scheduleJobId cancel];
        self.scheduleJobId = nil;
    }
    if (delay != TIME_INFINITY) {
        self.scheduleJobId = [self.jobService scheduleWithJob:self delay:delay priority:TLJobPriorityMessage];
    }
}

- (void)scheduleOperations {
    DDLogVerbose(@"%@ scheduleOperations", LOG_TAG);

    NSTimeInterval nextDelay = TIME_INFINITY;
    NSDate *now = [NSDate date];

    // If the scheduler is disabled, we only have to handle a job for IDLE detection.
    // Likewise if we are disconnected, we must handle P2P close.
    // In these cases, we don't schedule operations.
    if (!self.enable || ![self.twinlife isTwinlifeOnline]) {
        @synchronized(self) {
            self.isReschedulePending = NO;

            if (self.nextIdleCheckTime) {
                nextDelay = [self.nextIdleCheckTime timeIntervalSinceDate:now];
            }
        }
        if (nextDelay != TIME_INFINITY) {
            [self scheduleJobWithDelay:nextDelay];
        }
        return;
    }

    int limit = [self getActiveConversationsLimit];
    int scheduled = 0;
    int active;
    int pending;

    // Look at the pending operations and get the closest deadline.
    NSDate *deadline = nil;
    NSTimeInterval idleDelay = TIME_INFINITY;
    @synchronized(self) {
        self.isReschedulePending = NO;

        active = (int) self.activeOperations.count;
        pending = (int) self.waitingOperations.count;

        if (active > 0) {
            for (TLConversationOperationQueue *operations in self.activeOperations) {
                TLConversationServiceOperation *firstOperation = [operations firstObject];
                if (firstOperation && operations.conversationImpl && [firstOperation canExecuteWithConversation:operations.conversationImpl]) {
                    [self.conversationService executeFirstOperationWithConversation:operations.conversationImpl operation:firstOperation];
                }
            }
        }

        // Run the operations for the conversation if the deadline has passed and the limit is not reached.
        while (active + scheduled < limit && scheduled < pending) {
            TLConversationOperationQueue *operations = (TLConversationOperationQueue *)self.waitingOperations.queue[scheduled];
            if (!operations || !operations.conversationImpl) {
                break;
            }
            if (operations.deadline && [now compare:operations.deadline] == NSOrderedAscending) {
                deadline = operations.deadline;
                break;
            }

            scheduled++;
            [self.conversationService executeOperationWithConversation:operations.conversationImpl];
        }

        if (self.nextIdleCheckTime) {
            idleDelay = [self.nextIdleCheckTime timeIntervalSinceDate:now];
        }
        if (deadline) {
            nextDelay = [deadline timeIntervalSinceDate:now];
        }
        if (idleDelay < nextDelay) {
            nextDelay = idleDelay;
        }
    }

    [self scheduleJobWithDelay:nextDelay];

    DDLogInfo(@"%@ scheduleOperations active=%d scheduled=%d pending=%d limit=%d deadline=%@ nextDelay=%f", LOG_TAG, active, scheduled, pending - scheduled, limit, deadline, nextDelay);
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);
    
    self.scheduleJobId = nil;
    [self processIdleConnections];
    [self scheduleOperations];
}

- (nullable TLConversationServiceOperation *)getOperationWithConversation:(nonnull TLConversationImpl *)conversation requestId:(int64_t)requestId {
    DDLogVerbose(@"%@ getOperationWithConversation: %@ requestId: %lld", LOG_TAG, conversation.identifier, requestId);
    
    @synchronized(self) {
        TLConversationOperationQueue *operations = self.conversationId2Operations[conversation.identifier];
        if (operations) {
            for (TLConversationServiceOperation *operation in operations.queue) {
                if (operation.requestId == requestId) {
                    DDLogInfo(@"%@ getOperationWithConversation: %@ requestId: %lld operationType=%d", LOG_TAG, conversation.identifier, requestId, operation.type);
                    return operation;
                }
            }
        }
    }
    DDLogInfo(@"%@ getOperationWithConversation: %@ requestId: %lld operation not found", LOG_TAG, conversation.identifier, requestId);
    return nil;
}

- (nullable TLConversationServiceOperation *)getFirstOperationWithConversation:(nonnull TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ getFirstOperationWithConversation: %@", LOG_TAG, conversation.identifier);

    TLConversationServiceOperation *operation;
    @synchronized(self) {
        TLConversationOperationQueue *operations = self.conversationId2Operations[conversation.identifier];
        if (!operations || operations.count == 0) {
            return nil;
        }
        operation = operations.queue[0];
    }

    // TBD - add timestamp
    if (operation.requestId != TLConversationServiceOperation.NO_REQUEST_ID) {
        return nil;
    }

    DDLogInfo(@"%@ getFirstOperationWithConversationId: %@ operationType=%d", LOG_TAG, conversation.identifier, operation.type);

    return operation;
}

- (nullable TLConversationServiceOperation *)getFirstActiveOperationWithConversation:(nonnull TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ getFirstActiveOperationWithConversation: %@", LOG_TAG, conversation.identifier);

    TLConversationServiceOperation *operation;
    @synchronized(self) {
        TLConversationOperationQueue *operations = self.conversationId2Operations[conversation.identifier];
        if (!operations || operations.count == 0) {
            return nil;
        }
        operation = operations.queue[0];
    }

    if (operation.requestId == TLConversationServiceOperation.NO_REQUEST_ID) {
        return nil;
    }

    DDLogInfo(@"%@ getFirstActiveOperationWithConversation: %@ operationType=%d", LOG_TAG, conversation.identifier, operation.type);

    return operation;
}

- (nullable TLNotificationContent *)prepareNotificationWithConversation:(nonnull TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ prepareNotificationWithConversation: %@", LOG_TAG, conversation.identifier);
    
    TLPeerConnectionServiceNotificationOperation operation = TLPeerConnectionServiceNotificationOperationNotDefined;
    TLPeerConnectionServiceNotificationPriority priority = TLPeerConnectionServiceNotificationPriorityNotDefined;
    TLNotificationContent* notification = [[TLNotificationContent alloc] initWithPriority:priority operation:operation timeToLive:0];
    
    TLConversationOperationQueue *operations;
    @synchronized(self) {
        operations = self.conversationId2Operations[conversation.identifier];
        if (!operations) {
            DDLogInfo(@"%@ prepareNotificationWithConversation: %@ no operation", LOG_TAG, conversation.identifier);
            return nil;
        }

        // Move the operations from the waiting list to the active list.
        [self.waitingOperations removeObject:operations];
        if (operations.count == 0) {
            DDLogInfo(@"%@ prepareNotificationWithConversation: %@ empty operation list", LOG_TAG, conversation.identifier);

            [self.conversationId2Operations removeObjectForKey:conversation.identifier];
            [self.activeOperations removeObject:operations];
            return nil;
        }

        if (![self.activeOperations containsObject:operations]) {
            operations.deadline = nil;
            [self.activeOperations addObject:operations];
        }

        for (TLConversationServiceOperation *operation in operations.queue) {
            switch (operation.type) {
                case TLConversationServiceOperationTypePushObject:
                    notification.operation = TLPeerConnectionServiceNotificationOperationPushMessage;
                    notification.priority = TLPeerConnectionServiceNotificationPriorityHigh;
                    break;
                        
                case TLConversationServiceOperationTypePushFile: {
                    notification.operation = TLPeerConnectionServiceNotificationOperationPushFile;
                    notification.priority = TLPeerConnectionServiceNotificationPriorityHigh;
                    TLPushFileOperation *pushFileOperation = (TLPushFileOperation *)operation;
                    TLFileDescriptor *fileDescriptor = pushFileOperation.fileDescriptor;
                    if (!fileDescriptor) {
                        TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithId:pushFileOperation.descriptor];
                        if (descriptor) {
                            switch ([descriptor getType]) {
                                case TLDescriptorTypeImageDescriptor:
                                    notification.operation = TLPeerConnectionServiceNotificationOperationPushImage;
                                    break;
                                        
                                case TLDescriptorTypeAudioDescriptor:
                                    notification.operation = TLPeerConnectionServiceNotificationOperationPushAudio;
                                    break;
                                        
                                case TLDescriptorTypeVideoDescriptor:
                                    notification.operation = TLPeerConnectionServiceNotificationOperationPushVideo;
                                    break;
                                        
                                case TLDescriptorTypeNamedFileDescriptor:
                                    notification.operation = TLPeerConnectionServiceNotificationOperationPushFile;
                                    break;
                                        
                                default:
                                    break;
                            }
                        }
                    }
                    break;
                }
                        
                default:
                    break;
            }
            if (notification.operation != TLPeerConnectionServiceNotificationOperationNotDefined) {
                break;
            }
        }
    }
    if (notification.operation == TLPeerConnectionServiceNotificationOperationNotDefined) {
        notification.priority = TLPeerConnectionServiceNotificationPriorityLow;
    }

    DDLogInfo(@"%@ prepareNotificationWithConversation: %@ operation.count=%d", LOG_TAG, conversation.identifier, (int)operations.count);
    return notification;
}

- (nullable TLConversationServiceOperation *)startOperationsWithConnection:(nonnull TLConversationConnection *)connection state:(TLConversationState)state {
    DDLogVerbose(@"%@ startOperationsWithConnection: %@ state: %d", LOG_TAG, connection.conversation.uuid, state);

    BOOL needScheduleUpdate = NO;
    TLConversationImpl *conversationImpl = connection.conversation;
    TLDatabaseIdentifier *conversationId = conversationImpl.identifier;
    TLConversationServiceOperation *operation = nil;
    @synchronized(self) {
        TLConversationOperationQueue *operations = self.conversationId2Operations[conversationId];

        // Operations for the conversation are now active: move them from waiting to active list.
        if (operations && ![self.activeOperations containsObject:operations]) {
            if (![self.activeOperations containsObject:operations]) {
                [self.activeOperations addObject:operations];
            }
            [self.waitingOperations removeObject:operations];
            operations.deadline = nil;
        }

        // Keep track of opened conversations even if they have no operations.
        if (state == TLConversationStateOpen) {
            if (self.deferredOperations) {
                NSMutableArray<TLConversationServiceOperation *> *deferredList = [self.deferredOperations objectForKey:conversationId];
                if (deferredList) {
                    // We have some deferred operations, move them to the active list of operations.
                    [self.deferredOperations removeObjectForKey:conversationId];
                    if (self.deferredOperations.count == 0) {
                        self.deferredOperations = nil;
                    }
                    if (!operations) {
                        operations = [[TLConversationOperationQueue alloc] initWithConversation:conversationImpl];
                        self.conversationId2Operations[conversationId] = operations;
                    }
                    for (TLConversationServiceOperation *deferredOperation in deferredList) {
                        [operations addObject:deferredOperation allowDuplicate:NO];
                    }
                }
            }
            if (![self.activeConnections containsObject:connection]) {
                [self.activeConnections addObject:connection];
            }
            [connection touch];

            // Get first operation
            if (operations && operations.count > 0) {
                operation = operations.queue[0];

                if (operation.requestId != TLConversationServiceOperation.NO_REQUEST_ID) {
                    operation = nil;
                }
            }
        }

        // P2P connection is opened, setup the IDLE timer for the first opened connection.
        if (state == TLConversationStateOpen && !self.nextIdleCheckTime) {
            BOOL isForeground = [self.jobService isForeground];
            self.nextIdleCheckTime = [[NSDate alloc] initWithTimeIntervalSinceNow:isForeground ? IDLE_FOREGROUND_FIRST_CHECK_DELAY : IDLE_BACKGROUND_FIRST_CHECK_DELAY];
            if (!self.isReschedulePending) {
                needScheduleUpdate = YES;
                self.isReschedulePending = YES;
            }
        }
    }
    if (needScheduleUpdate) {
        DDLogVerbose(@"%@ startIdleTimer for: %@", LOG_TAG, conversationImpl.uuid);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, DELAY_BEFORE_SCHEDULE * NSEC_PER_MSEC), self.executorQueue, ^{
            [self scheduleOperations];
        });
    }
    if (state == TLConversationStateOpen) {
        [conversationImpl resetDelay];
    }
    return operation;
}

- (BOOL)closeWithConnection:(nonnull TLConversationConnection *)connection retryImmediately:(BOOL)retryImmediately {
    DDLogVerbose(@"%@ closeWithConnection: %@ next delay: %lld retryImmediately: %d", LOG_TAG, connection.conversation.identifier, connection.conversation.delay, retryImmediately);
    
    BOOL synchronizePeerNotification = NO;
    BOOL needReschedule = NO;
    TLConversationOperationQueue *operations;
    TLConversationImpl *conversation = connection.conversation;
    @synchronized(self) {
        [self.activeConnections removeObject:connection];

        operations = self.conversationId2Operations[conversation.identifier];
        if (operations) {
            [self.activeOperations removeObject:operations];
            [self.waitingOperations removeObject:operations];

            for (TLConversationServiceOperation *operation in operations.queue) {
                [operation updateWithRequestId:TLConversationServiceOperation.NO_REQUEST_ID];
            }
            if (operations.count > 0) {
                TLConversationServiceOperation *operation = operations.queue[0];
                synchronizePeerNotification = !retryImmediately && operation.type != TLConversationServiceOperationTypeSynchronizeConversation;
                NSTimeInterval delay = retryImmediately ? RETRY_IMMEDIATELY_DELAY : conversation.delay / 1000;

                // Put back the operations in the waiting queue with a new deadline.
                operations.deadline = [[NSDate alloc] initWithTimeIntervalSinceNow:delay];
                [self.waitingOperations addObject:operations allowDuplicate:NO];
            } else {
                [self.conversationId2Operations removeObjectForKey:conversation.identifier];
                operations = nil;
            }
        }

        // Check if we must trigger the scheduler for other pending operations.
        if (self.enable && !self.isReschedulePending && self.waitingOperations.count > 0) {
            self.isReschedulePending = YES;
            needReschedule = YES;
        }
    }
    DDLogInfo(@"%@ closeWithConversation: %@ pending operations: %d", LOG_TAG, conversation.identifier, operations ? (int)operations.count : 0);

    if (needReschedule) {
        DDLogInfo(@"%@ closeWithConversation: %@ start scheduler in 1s", LOG_TAG, conversation.identifier);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, DELAY_BEFORE_SCHEDULE * NSEC_PER_MSEC), self.executorQueue, ^{
            [self scheduleOperations];
        });
    }

    return synchronizePeerNotification;
}

- (void)processIdleConnections {
    DDLogVerbose(@"%@ processIdleConnections", LOG_TAG);
    
    // Use a longer idle time if we are in foreground.
    BOOL isForeground = [self.jobService isForeground];
    int64_t idleDelay = isForeground ? MAX_FOREGROUND_IDLE_TIME : MAX_BACKGROUND_IDLE_TIME;
    
    // Upon completion, holds a list of P2P connections that must be closed.
    NSMutableArray<TLConversationConnection *> *toClose = nil;
    BOOL hasActive = NO;
    @synchronized(self) {
        // Look at active conversations to check if the conversation is idle.
        for (TLConversationConnection *connection in self.activeConnections) {

            // If there are pending operations, give move time for the idle delay and data transfer.
            TLConversationOperationQueue *operations = self.conversationId2Operations[connection.conversation.identifier];
            int64_t checkDelay = !connection.isTransferingFile && (!operations || operations.count == 0) ? idleDelay : 2 * idleDelay;

            // Give 5s more if the peer has some pending operations.
            int deviceState = connection.peerDeviceState;
            if ((deviceState & DEVICE_STATE_HAS_OPERATIONS) != 0) {
                checkDelay += MAX_BACKGROUND_IDLE_TIME;
            }

            if ([connection idleTime] > checkDelay) {
                if (!toClose) {
                    toClose = [[NSMutableArray alloc] init];
                }
                [toClose addObject:connection];
            } else {
                hasActive = YES;
            }
        }

        // Check in 5 seconds if the situation has changed (foreground and idle state).
        if (hasActive) {
            self.nextIdleCheckTime = [[NSDate alloc] initWithTimeIntervalSinceNow:isForeground ? IDLE_FOREGROUND_CHECK_DELAY : IDLE_BACKGROUND_CHECK_DELAY];
        } else {
            self.nextIdleCheckTime = nil;
        }
    }
    
    // Close the P2P conversation which are idle.
    if (toClose) {
        DDLogInfo(@"%@ processIdleConnections closing %d P2P conversation after %lld ms", LOG_TAG, (int)toClose.count, idleDelay);

        for (TLConversationConnection *connection in toClose) {
            [self.conversationService closeWithConnection:connection terminateReason:TLPeerConnectionServiceTerminateReasonSuccess];
        }
    }
    
    if (!hasActive) {
        DDLogInfo(@"%@ processIdleConnections stopping because there is no active operations", LOG_TAG);
    }
}

#pragma mark - Operation methods

- (void)addOperations:(nonnull NSMapTable<TLConversationImpl *, NSObject *> *)operations {
    DDLogVerbose(@"%@ addOperations: %@", LOG_TAG, operations);

    for (TLConversationImpl *conversation in operations) {
        NSObject *item = [operations objectForKey:conversation];
        if ([item isKindOfClass:[TLConversationServiceOperation class]]) {
            [self addOperation:(TLConversationServiceOperation *)item conversation:conversation delay:0.0];
        } else {
            NSArray<TLConversationServiceOperation *> *list = (NSArray *)item;
            for (TLConversationServiceOperation *operation in list) {
                [self addOperation:operation conversation:conversation delay:0.0];
            }
        }
    }
}

- (void)addOperation:(nonnull TLConversationServiceOperation *)operation conversation:(nonnull TLConversationImpl*)conversation delay:(NSTimeInterval)delay {
    DDLogVerbose(@"%@ addOperation: %@ conversation: %@ delay: %f", LOG_TAG, operation, conversation.identifier, delay);
    
    BOOL schedule = NO;
    BOOL canExecute = NO;
    TLConversationOperationQueue *operations;
    TLDatabaseIdentifier *identifier = [conversation identifier];
    NSDate *now = [NSDate date];
    @synchronized(self) {
        BOOL isActive;
        operations = self.conversationId2Operations[identifier];
        if (!operations) {
            operations = [[TLConversationOperationQueue alloc] initWithConversation:conversation];
            self.conversationId2Operations[conversation.identifier] = operations;
            
            // If we are connected, we can proceed with execution of this first operation.
            canExecute = [operation canExecuteWithConversation:conversation];
            isActive = NO;
            
        } else {
            isActive = [self.waitingOperations containsObject:operations];
            if (isActive) {
                // We can execute if we are connected and this is a first operation.
                canExecute = operations.count == 0 && [operation canExecuteWithConversation:conversation];
                
            } else {
                canExecute = NO;
                
                // Temporarily remove the operations from the waiting list because adding an item may re-order the list.
                [self.waitingOperations removeObject:operations];
            }
        }

        // When a delay is defined, we don't want to trigger an execution of the operations for that conversation immediately,
        // and we have to wait that delay before trying to connect.  This is used when a SYNCHRONIZE operation is added when we
        // received a conversation::synchronize invocation.  We may also receive after that invocation an incoming P2P
        // for the same conversation and if we try to execute the SYNCHRONIZE, we will create an outgoing P2P before
        // trying to accept the incoming P2P: it will be rejected with BUSY.  There is no way to be aware whether such
        // incoming P2P is pending or not and the small delay is here to avoid that.
        if (delay > 0 && [now compare:operations.deadline] <= 0) {
            operations.deadline = [NSDate dateWithTimeInterval:delay sinceDate:now];
        }
        [operations addObject:operation allowDuplicate:NO];
        if (!isActive) {
            [self.waitingOperations addObject:operations allowDuplicate:NO];
        }
        schedule = isActive || self.activeOperations.count < MAX_FOREGROUND_ACTIVE_CONVERSATIONS;
    }
    if (canExecute) {
        [self.conversationService executeFirstOperationWithConversation:conversation operation:operation];

    } else if (schedule) {
        DDLogInfo(@"%@ addOperation: %d in conversation: %@ count: %lu", LOG_TAG, operation.type, conversation.identifier, (unsigned long)operations.count);

        [self scheduleOperationsWithConversation:conversation];
    }
}

- (void)addDeferrableOperation:(nonnull TLConversationServiceOperation *)operation conversation:(nonnull TLConversationImpl*)conversation {
    DDLogVerbose(@"%@ addDeferrableOperation: %@ conversation: %@", LOG_TAG, operation, conversation.identifier);
    
    // If the conversation is opened, add the operation immediately.
    if ([conversation isOpened]) {
        [self addOperation:operation conversation:conversation delay:0.0];
        return;
    }

    TLDatabaseIdentifier *identifier = conversation.identifier;
    @synchronized(self) {
        if (!self.deferredOperations) {
            self.deferredOperations = [[NSMutableDictionary alloc] init];
        }

        NSMutableArray<TLConversationServiceOperation *> *operations = self.deferredOperations[identifier];
        if (!operations) {
            operations = [[NSMutableArray alloc] init];
            [self.deferredOperations setObject:operations forKey:identifier];
        }
        [operations addObject:operation];
    }
}

- (void)removeOperation:(nonnull TLConversationServiceOperation *)operation {
    DDLogVerbose(@"%@ removeOperation: %@", LOG_TAG, operation);

    [self.serviceProvider deleteOperationWithOperationId:operation.id];

    TLDatabaseIdentifier *conversationId = operation.conversationId;
    TLConversationOperationQueue *operations;
    @synchronized(self) {
        operations = self.conversationId2Operations[conversationId];
        if (operations) {
            // We must remove the list of operations from the waiting queue when we modify it.
            BOOL removed = [self.waitingOperations containsObject:operations];
            [operations removeObject:operation];

            // Remove the list of operations when it becomes empty and it is in the waiting queue.
            if (operations.count == 0 && ![self.activeOperations containsObject:operations]) {
                [self.conversationId2Operations removeObjectForKey:conversationId];
            } else if (removed) {
                [self.waitingOperations addObject:operations allowDuplicate:NO];
            }
        }
    }
}

- (void)finishOperation:(nullable TLConversationServiceOperation *)operation connection:(nonnull TLConversationConnection*)connection {
    DDLogVerbose(@"%@ finishOperation: %@", LOG_TAG, operation);
    
    if (operation) {
        [self.serviceProvider deleteOperationWithOperationId:operation.id];
    }
    
    TLConversationImpl *conversation = connection.conversation;
    TLDatabaseIdentifier *conversationId = conversation.identifier;
    TLConversationServiceOperation *nextOperation = nil;
    BOOL canExecute;
    @synchronized(self) {
        TLConversationOperationQueue *operations = self.conversationId2Operations[conversationId];
        if (operations) {
            // We must remove the list of operations from the waiting queue when we modify it.
            BOOL removed = [self.waitingOperations containsObject:operations];
            [self.waitingOperations removeObject:operations];
            if (operation) {
                [operations removeObject:operation];
            }
            if (operations.count == 0) {

                // Remove the list of operations when it becomes empty and it is in the waiting queue.
                if (![self.activeOperations containsObject:operations]) {
                    [self.conversationId2Operations removeObjectForKey:conversationId];
                }
                operations = nil;
            } else {
                nextOperation = operations.queue[0];
                if (nextOperation && removed) {
                    [self.waitingOperations addObject:operations allowDuplicate:NO];
                }
            }
        }
        canExecute = nextOperation && [nextOperation canExecuteWithConversation:conversation];
    }
    if (canExecute) {
        [self.conversationService executeNextOperationWithConnection:connection operation:nextOperation];

    } else {
        int deviceState = connection.peerDeviceState;

        // The device state is not valid: we use the default idle detection mechanism.
        if ((deviceState & DEVICE_STATE_VALID) == 0) {
            return;
        }

        // The peer has some operations: keep the P2P connection opened.
        if ((deviceState & (DEVICE_STATE_HAS_OPERATIONS|DEVICE_STATE_SYNCHRONIZE_KEYS)) != 0) {
            return;
        }

        // We and the peer are in foreground: keep the P2P connection opened.
        if ((deviceState & DEVICE_STATE_FOREGROUND) != 0 && [self.jobService isForeground]) {
            return;
        }

        // We can terminate the P2P since there is no operation on both sides.
        [self.conversationService closeWithConnection:connection terminateReason:TLPeerConnectionServiceTerminateReasonSuccess];
    }
}

- (void)finishInvokeOperation:(nullable TLConversationServiceOperation *)operation conversation:(nonnull TLConversationImpl*)conversation {
    
    if (operation) {
        [self.serviceProvider deleteOperationWithOperationId:operation.id];
    }
    
    TLDatabaseIdentifier *conversationId = conversation.identifier;
    TLConversationOperationQueue *operations;
    TLConversationServiceOperation *nextOperation = nil;
    @synchronized(self) {
        operations = self.conversationId2Operations[conversationId];
        if (operations) {
            // We must remove the list of operations from the waiting queue when we modify it.
            BOOL removed = [self.waitingOperations containsObject:operations];
            [self.waitingOperations removeObject:operations];
            if (operation) {
                [operations removeObject:operation];
            }
            if (operations.count == 0) {

                // Remove the list of operations when it becomes empty and it is in the waiting queue.
                if (![self.activeOperations containsObject:operations]) {
                    [self.conversationId2Operations removeObjectForKey:conversationId];
                }
                operations = nil;
            } else {
                nextOperation = operations.queue[0];
                if (nextOperation && removed) {
                    [self.waitingOperations addObject:operations allowDuplicate:NO];
                }
            }
        }
    }
    if (nextOperation && [nextOperation canExecuteWithConversation:conversation]) {
        [self.conversationService executeFirstOperationWithConversation:conversation operation:nextOperation];
    } else if (operations) {
        [self.conversationService executeOperationWithConversation:conversation];
    }
}

- (BOOL)hasOperationsWithConversation:(nonnull TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ hasOperationsWithConversation: %@", LOG_TAG, conversation.identifier);

    @synchronized(self) {
        TLConversationOperationQueue *operations = self.conversationId2Operations[conversation.identifier];

        return operations != nil && operations.count > 0;
    }
}

- (void)removeOperationsWithConversation:(nonnull TLConversationImpl *)conversation deletedOperations:(nullable NSMutableArray<NSNumber *> *)deletedOperations {
    DDLogVerbose(@"%@ removeOperationsWithConversation: %@", LOG_TAG, conversation.identifier);
    
    @synchronized(self) {
        TLConversationOperationQueue *operations = self.conversationId2Operations[conversation.identifier];
        if (operations) {
            if (deletedOperations) {
                [operations removeOperationsWithList:deletedOperations];
                if (operations.count == 0) {
                    [self.conversationId2Operations removeObjectForKey:conversation.identifier];
                    [self.waitingOperations removeObject:operations];
                }
            } else {
                [self.conversationId2Operations removeObjectForKey:conversation.identifier];
                [self.waitingOperations removeObject:operations];
            }
        }
    }
}

- (void)removeAllOperations {
    DDLogInfo(@"%@ removeAllOperations", LOG_TAG);

    @synchronized(self) {
        [self.activeOperations removeAllObjects];
        [self.waitingOperations removeAllObjects];
        [self.conversationId2Operations removeAllObjects];

        if (self.scheduleJobId) {
            [self.scheduleJobId cancel];
            self.scheduleJobId = nil;
        }
    }
}

@end

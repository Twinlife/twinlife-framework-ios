/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationImpl.h"
#import "TLConversationConnection.h"

//
// Interface: TLConversationScheduler ()
//

@class TLGroupConversationImpl;
@class TLConversationServiceProvider;
@class TLConversationServiceOperation;
@class TLConversationService;
@class TLTwinlife;
@class TLNotificationContent;

/**
 * Scheduler for running the conversation operations.
 *
 * 1. Initialization
 * loadOperations() is called during startup to get the pending operations from the database.
 * prepareOperationsBeforeSchedule() is then called once we are connected to the Twinlife server.
 * It retrieves the conversation objects and prepares to schedule the operations.  It also handles
 * the askConversationSynchronizeWithConversation() during the Twinlife re-connection phase.
 * scheduleOperations() is then called to decide which conversation operations to execute.
 *
 * 2. P2P connection
 * Before starting an outgoing P2P connection, the prepareNotificationWithConversation() method
 * builds the notification object that indicates what operations are queued.  The list of active
 * operations is updated.
 *
 * When a P2P connection is started, the startOperationsWithConversation() must be called to
 * tell the scheduler there are some active P2P connection and operations.  If the P2P connection
 * is opened, the scheduler will let the conversation service execute the operations (if any).
 * The list of conversations with an opened P2P connection is updated.
 *
 * When a P2P connection is closed (successfully, with error, with timeout, ...), the scheduler
 * must also be notified through the closeWithConversation() method.  It is then able to schedule
 * a new P2P connection if necessary.  The list of opened conversations is updated, the active
 * operations is also updated.
 *
 * While the P2P connection is opened, the getFirstOperationWithConversationId() method is used
 * to get the first operation to execute.  The getOperationWithConversation() is then used when
 * the result IQ is processed and the operation is removed with removeOperation().
 *
 * While the list of conversations with opened P2P connection is not empty, a job is scheduled
 * every 5 second to look at idle P2P connection and close them.
 *
 * 3. Notification Service Extension or Share Extension
 * The notification service extension can be started and it can handle some pending operations.
 * That process can run for a long time but it is connected to the OpenFire server only for the
 * duration to handle the incoming message. It can handle operations for the incoming P2P
 * conversation.
 *
 * The Share Extension does not connect to the OpenFire server but it can create descriptors and
 * operations.
 *
 * Due to these extensions, when the application is restarted, we must reload the operations in case
 * some have been removed and some have been added.  This is handled by loadOperations which
 * can be called several times during the life time of the application OR of the extension!.
 */
@interface TLConversationServiceScheduler : NSObject

/// When the scheduler is enabled it schedules operations, otherwise it prepares to handle operations but remains passive in their execution.
/// We have to be careful that we still have to run jobs to handle the IDLE connection detection in order to close them.
@property BOOL enable;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife conversationService:(nonnull TLConversationService *)conversationService serviceProvider:(nonnull TLConversationServiceProvider *)serviceProvider executorQueue:(nonnull dispatch_queue_t)executorQueue;

/// Load or reload the operations from the database during the startup or resume.
- (void)loadOperations;

/// Notify we are online and schedule the operations if we have some operations.
- (void)onTwinlifeOnline;

- (void)onTwinlifeSuspend;

/// Schedule the operations associated with the conversation.
- (void)scheduleOperationsWithConversation:(nonnull TLConversationImpl *)conversation;

/// Notify the scheduler that a connection is started or opened for the given conversation.
- (nullable TLConversationServiceOperation *)startOperationsWithConnection:(nonnull TLConversationConnection *)connection state:(TLConversationState)state;

/// Notify the scheduler that the connection for the conversation has closed.
/// Returns true if a synchronize peer notification is required.
- (BOOL)closeWithConnection:(nonnull TLConversationConnection *)connection retryImmediately:(BOOL)retryImmediately;

/// Add a list of operations associated with specific conversations and schedule their execution.
- (void)addOperations:(nonnull NSMapTable<TLConversationImpl *, NSObject *> *)operations;

/// Add the operation for the conversation and schedule its execution.
- (void)addOperation:(nonnull TLConversationServiceOperation *)operation conversation:(nonnull TLConversationImpl*)conversation delay:(NSTimeInterval)delay;

/// Add the operation in the deferred queue and take it into account when we go in background or the conversation is opened.
- (void)addDeferrableOperation:(nonnull TLConversationServiceOperation *)operation conversation:(nonnull TLConversationImpl*)conversation;

/// Remove the operation.
- (void)removeOperation:(nonnull TLConversationServiceOperation *)operation;

/// Remove the operation and schedule the next execution if necessary for the associated conversation.
- (void)finishOperation:(nullable TLConversationServiceOperation *)operation connection:(nonnull TLConversationConnection*)connection;

- (void)finishInvokeOperation:(nullable TLConversationServiceOperation *)operation conversation:(nonnull TLConversationImpl*)conversation;

/// Returns YES if the conversation has pending operations.
- (BOOL)hasOperationsWithConversation:(nonnull TLConversationImpl *)conversation;

/// Remove all operations associated with the conversation.  When a map of descriptors indexed by twincodes is passed,
/// it indicates a set of descriptors that have been removed and we must remove all operations that are using such past descriptor.
- (void)removeOperationsWithConversation:(nonnull TLConversationImpl *)conversation deletedOperations:(nullable NSMutableArray<NSNumber *> *)deletedOperations;

/// Remove all operations from all conversations (called when we are doing a sign out).
- (void)removeAllOperations;

/// Before opening the P2P connection, get the notification according to the pending operations.
- (nullable TLNotificationContent *)prepareNotificationWithConversation:(nonnull TLConversationImpl *)conversation;

/// Get the first pending operation for the conversation.
- (nullable TLConversationServiceOperation *)getFirstOperationWithConversation:(nonnull TLConversationImpl *)conversation;

/// Get the first active pending operation for the conversation.
- (nullable TLConversationServiceOperation *)getFirstActiveOperationWithConversation:(nonnull TLConversationImpl *)conversation;

/// Get the operation with the given request ID.
- (nullable TLConversationServiceOperation *)getOperationWithConversation:(nonnull TLConversationImpl *)conversation requestId:(int64_t)requestId;

@end

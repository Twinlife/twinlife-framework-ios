/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

@protocol TLApplication;

typedef enum {
    TLJobPriorityMessage,
    TLJobPriorityUpdate,
    TLJobPriorityReport
} TLJobPriority;

typedef enum {
    TLWakeupKindAlarm,
    TLWakeupKindPush,
    TLWakeupKindFetch
} TLWakeupKind;

//
// TLJobId
//

@interface TLJobId : NSObject

/// Cancel the scheduled job.  If the job is running, the operation has no effect.
- (void)cancel;

@end

//
// TLJob
//

/// The protocol that must be implemented to schedule a job handler.
@protocol TLJob

/// Operation called by the job service when it decides the conditions are met to execute the job.
- (void)runJob;

@end

//
// TLNetworkLock
//

@interface TLNetworkLock : NSObject

- (void)releaseLock;

@end

//
// TLJobService
//

/// The job service registers and schedules execution of TLJob operations sometimes in the future
/// depending on some execution constraints.  The job service tries to execute the job when the
/// application is running in the foreground.  When a job is scheduled, it returns a TLJobId that
/// can be used to cancel the scheduled job.
@interface TLJobService : NSObject

/// Returns true if we are running in foreground.
- (BOOL)isForeground;

/// Returns true if we are idle and there is no network lock taken.
- (BOOL)isIdle;

/// Returns true if we can re-connect to the Openfire server or make P2P connection.
/// Returns false if we are shutting down or about to shutdown soon.
- (BOOL)canReconnect;

/// Schedule a job to be executed sometimes if the constraints are permitted.  The job priority is TLJobPriorityUpdate and the job
/// is executed once we are connected to Twinme server and we are running in the foreground.
/// A unique job id is returned to be able to cancel the job.
- (nonnull TLJobId *)scheduleWithJob:(nonnull id<TLJob>)job;

/// Schedule a job to be executed sometimes in the future after the given delay and when the constraints are permitted.
/// There is no guarantee that the job will be executed in the exact delay.
/// A unique job id is returned to be able to cancel the job.
- (nonnull TLJobId *)scheduleWithJob:(nonnull id<TLJob>)job delay:(NSTimeInterval)delay priority:(TLJobPriority)priority;
- (nonnull TLJobId *)scheduleWithJob:(nonnull id<TLJob>)job deadline:(nonnull NSDate*)deadline priority:(TLJobPriority)priority;

/// Notify the job scheduler that a wakeup was made.  It can be from the alarm, a push notification, a background fetch.
/// The application is optional to allow the notification service extension to use this.
/// The completionHandler will be called when the background processing time has ellapsed.
- (void)didWakeupWithApplication:(nullable id<TLApplication>)application kind:(TLWakeupKind)kind fetchCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler;

/// Report the number of active VoIP calls which are in progress. The Job scheduler keeps the connection opened while we are in foreground
/// or we have some VoIP call in progress. As soon as we are in background and there is no VoIP call, the Twinlife service is shutdown to
/// disconnect from the server and suspend the services.  When a completion handler is passed, it is called when Twinlife service is fully suspended,
/// or, almost immediately if there are other calls in progress or we are in foreground. Such completion handler is a safe place to execute
/// the CallKit handler reportCallWithUUID to terminate the call.
- (void)reportActiveVoIPWithCallCount:(long)count fetchCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler;

/// Allocate a network lock to try keeping the service alive.
/// When the network lock is not needed anymore, its `release` operation must be called.
- (nonnull TLNetworkLock *)allocateNetworkLock;

@end

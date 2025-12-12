/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLQueue.h"
#import "TLJobService.h"
#import "TLTwinlifeImpl.h"

@class TLDeviceInfo;

typedef enum {
    TLApplicationStateForeground,
    TLApplicationStateBackground,
    TLApplicationStateWakeupAlarm,
    TLApplicationStateWakeupPush,
    TLApplicationStateSuspending,
    TLApplicationStateSuspended
} TLApplicationState;

//
// Protocol: TLBackgroundJobObserver
//

@protocol TLBackgroundJobObserver <NSObject>

/// Called when the application goes in background.
- (void)onEnterBackground;

/// Note the onEnterForeground is not provided because not used.

@end

//
// TLJobId
//

@interface TLJobId ()

@property (readonly, nonnull) TLJobService *jobService;
@property (readonly, nonnull) id<TLJob> job;
@property (readonly, nullable) NSDate *deadline;
@property (readonly) TLJobPriority priority;

- (nonnull instancetype)initWithJobService:(nonnull TLJobService *)jobService job:(nonnull id<TLJob>)job deadline:(nullable NSDate*)deadline priority:(TLJobPriority)priority;

- (NSComparisonResult)compareWithJobId:(nonnull TLJobId *)job;

@end

//
// TLJobService
//

@interface TLJobService ()<TLJob>

@property (nullable) id<TLBackgroundJobObserver> backgroundJobObserver;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife;

- (void)registerBackgroundTasks;

- (TLApplicationState)applicationState;

- (BOOL)isVoIPActive;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onEnterForegroundWithApplication:(nullable id<TLApplication>)application;

- (void)onEnterBackgroundWithApplication:(nullable id<TLApplication>)application;

- (void)releaseNetworkLock;

- (void)suspend;

- (void)suspendWithCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler;

/// Final step to handle the suspension called from twinlifeSuspended() after the database has been closed.
/// Returns YES if we suspended correctly and NO if the state indicates we must restart because a Push was
/// received during suspension.
- (BOOL)onTwinlifeSuspended;

- (nonnull TLDeviceInfo *)getDeviceInfo;


@end

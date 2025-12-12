/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import <BackgroundTasks/BackgroundTasks.h>

#import "TLJobServiceImpl.h"
#import "TLBaseService.h"
#import "TLDeviceInfo.h"

#if 0
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define JOB_UPDATE_DELAY          10.000 // s
#define BACKGROUND_RELEASE_TIMER   1.0 // s
#define BACKGROUND_RESTORE_DELAY   4.0 // s
#define SHUTDOWN_TIMEOUT          24.0 // s Shutdown the connection, database 24s after we enter in background.
#define MIN_CONNECTION_TIME        4.0 // s Minimum connection time on the Openfire server before allowing an early suspend
#define PRE_SUSPEND_DELAY          4.0 // s
#define TRY_DISCONNECT_REPEAT_TIME 1.0 // s Repeat each 1 s the tryDisconnectTimer
#define SUSPEND_DELAY              0.5 // s Delay to wait for P2P sessions to be closed during shutdown (500ms).
#define DISCONNECT_DELAY           0.4 // s Delay after calling disconnect to really suspend (400ms).
#define RESUME_DELAY               3.0 // s Delay to avoid scheduling jobs during suspension (see setScheduleTimerWithJob).
#define EMERGENCY_SUSPEND_DELAY   (SUSPEND_DELAY + DISCONNECT_DELAY + 0.1) // Should not exceed 1s

//
// Application switch from Foreground to Background:
// +------------+---------------------------------------------------------+
// | Foreground |  Background                                             | Suspended
// +------------+---------------------------------------------------------+
//                 SHUTDOWN_TIMEOUT    SUSPEND_DELAY       DISCONNECT_DELAY
//               <------ 24s ------->^<---- 0.5s ------->^<--- 0.4s ------>  < 30 s (iOS max)
//                 |<- 4s ->         |                   |                |
//              MIN_CONNECTION_TIME  |                   |                |
//                onTwinlifeOnline() |                   |                |
//                           <- 4s ->|                   |                |
//                 PRE_SUSPEND_DELAY |                   |                |
//                                   onTwinlifeSuspend() |                endBackgroundTask()
//                                                       disconnect()
//
// Application wakeup by push:
// +------------+---------------------------------------------------------+
// | Suspended  |  Background                                             | Suspended
// +------------+---------------------------------------------------------+
//            min=BACKGROUND_RESTORE_DELAY+BACKGROUND_RELEASE_TIMER
//            max=SHUTDOWN_TIMEOUT       SUSPEND_DELAY    DISCONNECT_DELAY
//               <--- 5s .. 24s ---->|<----- 0.5s -------><--- 0.4s ------>  < 30 s (iOS max)
//
// 2025-05-14: suspend delay changed back from 1.0 to 0.5 and disconnect delay changed from 0.5 to 0.4
//             to reduce the EMERGENCY_SUSPEND_DELAY to arround 1.0s as Quinn “The Eskimo!” recommends
//             not exceeding 1s for the execution of the expiration handler.
//
// 2025-02-17: suspend delay changed from 0.5 to 1.0 and disconnect delay change from 0.1 to 0.5
//             rationale: we have enough time for the suspend and can give more delay to finish work
//             When the expiration handler is called, we seem to have between 2 to 4 second.

//
// Interface: TLShutdownJob
//
@interface TLShutdownJob : NSObject <TLJob>

@property (nullable, readonly) id<TLApplication> application;
@property (nonnull, readonly) TLJobService *jobService;
@property (weak, readonly) TLJobId *shutdownJobId;
@property (readonly) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nullable, readonly) void (^fetchCompletionHandler) (TLBaseServiceErrorCode status);

- (nonnull instancetype)initWithJobService:(nonnull TLJobService *)jobService application:(nullable id<TLApplication>)application fetchCompletionHandler:(void (^)(TLBaseServiceErrorCode status))fetchCompletionHandler;

@end

//
// TLJobService
//

@interface TLJobService ()<TLJob>

@property (readonly, nonnull) TLTwinlife *twinlife;
@property (readonly, nonnull) TLQueue *jobList;
@property (readonly, nonnull) dispatch_source_t scheduleTimer;
@property (readonly, nonnull) dispatch_source_t backgroundTimer;
@property (readonly, nonnull) dispatch_source_t disconnectTimer;
@property (readonly, nonnull) dispatch_source_t suspendTimer;
@property (readonly, nullable) dispatch_source_t wakeupTimer;
@property (readonly, nullable) dispatch_source_t tryDisconnectTimer;

@property TLApplicationState state;
@property BOOL online;
@property BOOL allowNotifications;

/// Performance counters and timestamps
@property atomic_int pushCount;
@property int networkLockCount;
@property atomic_int alarmCount;
@property long callCount;
@property int64_t pushTime;
@property int64_t backgroundTime;
@property int64_t activeTime;
@property int64_t shutdownDeadlineTime;
@property atomic_ullong totalBackgroundTime;
@property atomic_ullong totalForegroundTime;
@property int idleCounter;

/// Application jobs
@property (nonnull) NSMutableArray<TLJobId *> *updateJobList;
@property (nullable) id<TLApplication> application;
@property (nullable) TLShutdownJob *shutdownJob;
@property (nullable) TLShutdownJob *suspendJob;
@property (nullable) TLJobId *updateJobId;
@property (nullable) TLJobId *scheduledJobId;

/// Timer activation management.
@property BOOL suspendTimerActive;
@property BOOL wakeupTimerActive;
@property BOOL scheduleTimerActive;
@property BOOL backgroundTimerActive;
@property BOOL disconnectTimerActive;
@property BOOL tryDisconnectTimerActive;

- (void)cancelWithJobId:(nonnull TLJobId *)jobId;

/// Try to disconnect if we are in background and there is no work for us.
- (void)tryDisconnectTimerHandler;

/// Executed when we must immediately suspend because some iOS expiration handler is being called.
- (void)emergencySuspendWithJob:(nullable TLShutdownJob *)shutdownJob;

@end

//
// TLJobId
//

#undef LOG_TAG
#define LOG_TAG @"TLJobId"

@implementation TLJobId

- (nonnull instancetype)initWithJobService:(nonnull TLJobService *)jobService job:(nonnull id<TLJob>)job deadline:(nullable NSDate*)deadline priority:(TLJobPriority)priority {
    DDLogVerbose(@"%@ initWithJobService: %@ job: %@ deadline: %@ priority: %d", LOG_TAG, jobService, job, deadline, priority);

    self = [super init];
    if (self) {
        _job = job;
        _jobService = jobService;
        _deadline = deadline;
        _priority = priority;
    }
    return self;
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    [self.jobService cancelWithJobId:self];
}

- (NSComparisonResult)compareWithJobId:(nonnull TLJobId *)job {

    // If there is a deadline, sort on it.
    if (self.deadline && job.deadline) {
        return [self.deadline compare:job.deadline];

    } else if (job.deadline) {
        return NSOrderedAscending;

    } else if (self.deadline) {
        return NSOrderedDescending;

    } else {
        return NSOrderedSame;
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLJobId"];
    [string appendFormat:@" deadline: %@", self.deadline];
    [string appendFormat:@" priority: %d", self.priority];
    [string appendFormat:@" job: %@\n", self.job];
    return string;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLNetworkLock"

@interface TLNetworkLock ()

@property (readonly, nonnull) TLJobService *jobService;
@property BOOL isReleased;

- (nonnull instancetype)initWithJobService:(nonnull TLJobService *)jobService;

@end

//
// TLNetworkLock
//

@implementation TLNetworkLock

- (nonnull instancetype)initWithJobService:(nonnull TLJobService *)jobService {
    DDLogVerbose(@"%@ initWithJobService: %@", LOG_TAG, jobService);

    self = [super init];
    if (self) {
        _jobService = jobService;
        _isReleased = NO;
    }
    return self;
}

- (void)releaseLock {
    DDLogVerbose(@"%@ releaseLock", LOG_TAG);

    @synchronized (self) {
        if (!self.isReleased) {
            self.isReleased = YES;
            [self.jobService releaseNetworkLock];
        }
    }
}

@end

//
// Implementation: TLShutdownJob
//

#undef LOG_TAG
#define LOG_TAG @"TLShutdownJob"

@implementation TLShutdownJob

- (nonnull instancetype)initWithJobService:(nonnull TLJobService *)jobService application:(nullable id<TLApplication>)application fetchCompletionHandler:(void (^)(TLBaseServiceErrorCode status))fetchCompletionHandler {
    DDLogVerbose(@"%@ initWithJobService: %@ application: %@", LOG_TAG, jobService, application);

    self = [super init];
    if (self) {
        _jobService = jobService;
        _application = application;
        _fetchCompletionHandler = fetchCompletionHandler;
        if (application) {
            _backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler: ^{
                if (@available(iOS 13.0, *)) {
                    DDLogError(@"%@ background task expiration %ld called, remaining: %f", LOG_TAG, self.backgroundTaskIdentifier, [self.application backgroundTimeRemaining]);
                } else {
                    DDLogError(@"%@ background task expiration %ld called", LOG_TAG, self.backgroundTaskIdentifier);
                }
                [self.jobService emergencySuspendWithJob:self];
            }];
            DDLogInfo(@"%@ begin background task %ld", LOG_TAG, _backgroundTaskIdentifier);
        } else {
            _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }

        _shutdownJobId = [jobService scheduleWithJob:self delay:SHUTDOWN_TIMEOUT priority:TLJobPriorityMessage];
    }

    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);

    [self shutdown];
}

- (void)shutdown {
    DDLogVerbose(@"%@ shutdown", LOG_TAG);

    [self.jobService suspend];
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    __strong TLJobId *jobId = self.shutdownJobId;
    if (jobId) {
        [jobId cancel];
    }

    [self terminate];
}

- (void)terminate {
    DDLogInfo(@"%@ terminate task %ld", LOG_TAG, self.backgroundTaskIdentifier);

    if (self.application && self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        // After execution of these handlers, the system will suspend us may be immediately.
        [self.application endBackgroundTask:self.backgroundTaskIdentifier];

        if (self.fetchCompletionHandler) {
            self.fetchCompletionHandler(TLBaseServiceErrorCodeSuccess);
        }
    } else if (self.fetchCompletionHandler) {
        self.fetchCompletionHandler(TLBaseServiceErrorCodeSuccess);
    }
}

@end

//
// TLJobServiceImpl
//

#undef LOG_TAG
#define LOG_TAG @"TLJobService"

@implementation TLJobService

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);

    self = [super init];
    if (self) {
        _twinlife = twinlife;
        _state = TLApplicationStateBackground;
        _backgroundTime = [[NSDate date] timeIntervalSince1970] * 1000;
        _updateJobList = [[NSMutableArray alloc] init];
        _jobList = [[TLQueue alloc] initWithComparator:^NSComparisonResult(id<NSObject> obj1, id<NSObject> obj2) {
            TLJobId *job1 = (TLJobId *)obj1;
            TLJobId *job2 = (TLJobId *)obj2;
            
            return [job1 compareWithJobId:job2];
        }];

        _backgroundTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.twinlife.twinlifeQueue);
        dispatch_source_set_event_handler(_backgroundTimer, ^{
            [self stopBackgroundJobTimerHandler];
        });
        
        _scheduleTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.twinlife.twinlifeQueue);
        dispatch_source_set_event_handler(_scheduleTimer, ^{
            [self scheduleTimerHandler];
        });
        
        _disconnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.twinlife.twinlifeQueue);
        dispatch_source_set_event_handler(_disconnectTimer, ^{
            [self disconnectTimerHandler];
        });
        
        _suspendTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.twinlife.twinlifeQueue);
        dispatch_source_set_event_handler(_suspendTimer, ^{
            [self suspendTimerHandler];
        });
        
        _tryDisconnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.twinlife.twinlifeQueue);
        dispatch_source_set_event_handler(_tryDisconnectTimer, ^{
            [self tryDisconnectTimerHandler];
        });

        // The wakeupTimer is only used on iOS 12, on iOS 13 we use the background task.
        if (@available(iOS 13.0, *)) {
            _wakeupTimer = nil;
        } else {
            _wakeupTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.twinlife.twinlifeQueue);
            dispatch_source_set_event_handler(_wakeupTimer, ^{
                [self wakeupTimerHandler];
            });
        }
    }

    return self;
}

- (void)registerBackgroundTasks {
    DDLogError(@"%@ registerBackgroundTasks", LOG_TAG);

    NSAssert(NSThread.isMainThread, @"Not on main thread");

    // Register the scheduler task (it must be called only once!!!).
    if (@available(iOS 13.0, *)) {
        [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:SCHEDULER_TASK_NAME usingQueue:dispatch_get_main_queue() launchHandler:^(BGTask *task) {
            [self handleSchedulerTask:(BGAppRefreshTask *)task];
        }];
    }
}

- (TLApplicationState)applicationState {
    DDLogVerbose(@"%@ applicationState", LOG_TAG);

    @synchronized (self) {
        return self.state;
    }
}

- (BOOL)isVoIPActive {
    DDLogVerbose(@"%@ isVoIPActive", LOG_TAG);

    @synchronized (self) {
        return self.callCount > 0;
    }
}

- (BOOL)isForeground {
    DDLogVerbose(@"%@ isForeground", LOG_TAG);

    @synchronized (self) {
        return self.state == TLApplicationStateForeground;
    }
}

- (BOOL)isIdle {
    DDLogVerbose(@"%@ isIdle", LOG_TAG);

    @synchronized (self) {
        return self.networkLockCount == 0;
    }
}

- (BOOL)canReconnect {
    DDLogVerbose(@"%@ canReconnect", LOG_TAG);

    @synchronized (self) {
        switch (self.state) {
            case TLApplicationStateForeground:
                // In foreground, we can re-connect at any time.
                return YES;

            case TLApplicationStateBackground:
            case TLApplicationStateWakeupPush:
            case TLApplicationStateWakeupAlarm:
                // If we have active calls or P2P, we can re-connect at any time.
                if (self.callCount > 0) {
                    return YES;
                }
                if (self.networkLockCount > 0) {
                    return YES;
                }

                // We can do connection if the expiration deadline is not too soon.
                int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
                return now < self.shutdownDeadlineTime - PRE_SUSPEND_DELAY * MSEC_PER_SEC;

            default:
                // Suspension is in progress.
                return NO;
        }
    }
    return NO;
}

- (TLDeviceInfo *)getDeviceInfo {
    DDLogVerbose(@"%@ getDeviceInfo", LOG_TAG);

    int64_t foregroundTime;
    int64_t backgroundTime;
    @synchronized (self) {
        foregroundTime = self.totalForegroundTime;
        backgroundTime = self.totalBackgroundTime;

        // Take into account current mode and last time we enter in it.
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        if (self.state != TLApplicationStateForeground) {
            backgroundTime += now - self.backgroundTime;
            self.backgroundTime = now;
        } else if (self.activeTime) {
            foregroundTime += now - self.activeTime;
            self.activeTime = now;
        }
    }
    int pushCount = self.pushCount;
    int alarmCount = self.alarmCount;
    int networkLockCount = self.networkLockCount;
    TLDeviceInfo *deviceInfo = [[TLDeviceInfo alloc] initWithForegroundTime:foregroundTime backgroundTime:backgroundTime pushCount:pushCount alarmCount:alarmCount networkLockCount:networkLockCount allowNotifications:self.allowNotifications];
    
    return deviceInfo;
}

- (nonnull TLJobId *)scheduleWithJob:(nonnull id<TLJob>)job {
    DDLogVerbose(@"%@ scheduleWithJob: %@", LOG_TAG, job);

    TLJobId *jobId = [[TLJobId alloc] initWithJobService:self job:job deadline:nil priority:TLJobPriorityUpdate];
    @synchronized (self) {
        [self.updateJobList addObject:jobId];
        if (self.online && self.state == TLApplicationStateForeground && !self.updateJobId) {
            [self scheduleJobs];
        }
    }
    return jobId;
}

- (nonnull TLJobId *)scheduleWithJob:(nonnull id<TLJob>)job delay:(NSTimeInterval)delay priority:(TLJobPriority)priority {
    DDLogVerbose(@"%@ scheduleWithJob: %@ delay: %f priority: %d", LOG_TAG, job, delay, priority);

    NSDate *deadline = [[NSDate alloc] initWithTimeIntervalSinceNow:delay];
    return [self scheduleWithJob:job deadline:deadline priority:priority];
}

- (nonnull TLJobId *)scheduleWithJob:(nonnull id<TLJob>)job deadline:(nonnull NSDate*)deadline priority:(TLJobPriority)priority {
    DDLogVerbose(@"%@ scheduleWithJob: %@ deadline: %@ priority: %d", LOG_TAG, job, deadline, priority);

    TLJobId *jobId = [[TLJobId alloc] initWithJobService:self job:job deadline:deadline priority:priority];
    @synchronized (self) {
        [self.jobList addObject:jobId allowDuplicate:YES];
        [self scheduleJobs];
    }
    DDLogVerbose(@"%@ scheduleWithJob: %@ jobId: %@", LOG_TAG, job, jobId);
    return jobId;
}

- (nonnull TLNetworkLock *)allocateNetworkLock {
    DDLogVerbose(@"%@ allocateNetworkLock", LOG_TAG);

    @synchronized (self) {
        self.networkLockCount++;

        // Clear the idle counter: some P2P is being requested and the ConversationScheduler
        // could still have some pending jobs.
        self.idleCounter = 0;
    }
    return [[TLNetworkLock alloc] initWithJobService:self];
}

- (void)releaseNetworkLock {
    DDLogVerbose(@"%@ releaseNetworkLock", LOG_TAG);

    @synchronized (self) {
        self.networkLockCount--;

        // If we are doing background push processing, stop the background job in 1 second.
        if (self.networkLockCount == 0 && (self.state == TLApplicationStateWakeupPush || self.state == TLApplicationStateWakeupAlarm)) {
            int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
            if (self.pushTime + BACKGROUND_RESTORE_DELAY * 1000 < now) {
                dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(BACKGROUND_RELEASE_TIMER * NSEC_PER_SEC));
                dispatch_source_set_timer(self.backgroundTimer, tt, DISPATCH_TIME_FOREVER, 0);
                if (!self.backgroundTimerActive) {
                    dispatch_resume(self.backgroundTimer);
                    self.backgroundTimerActive = YES;
                }
            }
        }
    }
}

- (void)didWakeupWithApplication:(nullable id<TLApplication>)application kind:(TLWakeupKind)kind fetchCompletionHandler:(void (^)(TLBaseServiceErrorCode status))completionHandler {
    DDLogInfo(@"%@ didWakeupWithApplication kind: %d state: %d twinlifeStatus: %d", LOG_TAG, kind, self.state, [self.twinlife status]);

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    TLApplicationState state;
    @synchronized (self) {
        self.application = application;
        self.pushCount = self.pushCount + 1;
        self.pushTime = now;
        if (kind == TLWakeupKindPush) {
            // The APNS push was received, we can consider that notifications are allowed.
            self.allowNotifications = YES;
        } else if (application) {
            // Get the status from the application if we know it.
            self.allowNotifications = [application allowNotifications];
        } else {
            // Do not change allowNotifications
        }

        // We can receive a Push while we are in foreground and we must keep the Foreground state.
        // A Push can be received while we are suspending, in that case we must proceed with suspension
        // but change the state to WakeupAlarm or WakeupPush.  The disconnectTimer and suspendTimer
        // must be kept because if we started the suspension, we must continue until we a disconnected
        // and we must reconnect (if we keep connected, some incoming events from the server will be
        // ignored, by reconnecting, we will handle the new incoming events correctly).
        state = self.state;
        if (state != TLApplicationStateForeground) {
            self.state = kind == TLWakeupKindPush ? TLApplicationStateWakeupPush : TLApplicationStateWakeupAlarm;
        }
        if (self.backgroundTimerActive) {
            dispatch_suspend(self.backgroundTimer);
            self.backgroundTimerActive = NO;
        }
        if (self.wakeupTimerActive) {
            dispatch_suspend(self.wakeupTimer);
            self.wakeupTimerActive = NO;
        }
        if (self.suspendJob) {
            [self.suspendJob cancel];
            self.suspendJob = nil;
        }
        if (self.shutdownJob) {
            [self.shutdownJob cancel];
        }

        self.shutdownJob = [[TLShutdownJob alloc] initWithJobService:self application:application fetchCompletionHandler:completionHandler];
        self.shutdownDeadlineTime = now + SHUTDOWN_TIMEOUT * MSEC_PER_SEC;
    }

    // Trigger connection unless we are suspending.
    if (state != TLApplicationStateSuspending) {
        [self.twinlife connect];
    }
}

- (void)reportActiveVoIPWithCallCount:(long)count fetchCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler {
    DDLogInfo(@"%@ reportActiveVoIPWithCallCount: %ld shutdownJob: %@", LOG_TAG, count, self.shutdownJob);

    @synchronized (self) {
        self.callCount = count;
        if (count != 0 || self.state == TLApplicationStateForeground) {
            // Execute the completion handler from the twinlife queue.
            if (completionHandler) {
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    completionHandler(TLBaseServiceErrorCodeSuccess);
                });
            }
            return;
        }

        if (completionHandler) {
            if (self.shutdownJob) {
                [self.shutdownJob cancel];
            }
            self.shutdownJob = [[TLShutdownJob alloc] initWithJobService:self application:nil fetchCompletionHandler:completionHandler];
        }
    }

    [self suspend];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    @synchronized (self) {
        self.online = YES;

        // If we are in background or in a push, schedule the tryDisconnect timer in 4s
        // to check if we still need the connection and if not do the shutdown earlier.
        if (self.state != TLApplicationStateForeground) {
            dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MIN_CONNECTION_TIME * NSEC_PER_SEC));
            dispatch_source_set_timer(self.tryDisconnectTimer, tt, DISPATCH_TIME_FOREVER, 0);
            if (!self.tryDisconnectTimerActive) {
                dispatch_resume(self.tryDisconnectTimer);
                self.tryDisconnectTimerActive = YES;
            }
            self.idleCounter = 0;
        }

        [self scheduleJobs];
    }
}

- (void)onTwinlifeOffline {
    DDLogVerbose(@"%@ onTwinlifeOffline", LOG_TAG);

    @synchronized (self) {
        self.online = NO;
        // If the tryDisconnect timer is active, cancel its execution.
        if (self.tryDisconnectTimerActive) {
            dispatch_suspend(self.tryDisconnectTimer);
            self.tryDisconnectTimerActive = NO;
        }
        [self cancelJobs];
    }
}

- (void)onEnterForegroundWithApplication:(nullable id<TLApplication>)application {
    DDLogInfo(@"%@ onEnterForegroundWithApplication", LOG_TAG);

    int64_t activeTime = [[NSDate date] timeIntervalSince1970] * 1000;
    TLApplicationState state;
    @synchronized (self) {
        state = self.state;
        self.state = TLApplicationStateForeground;
        self.activeTime = activeTime;
        self.application = application;
        if (application) {
            self.allowNotifications = [application allowNotifications];
        }

        if (self.backgroundTimerActive) {
            dispatch_suspend(self.backgroundTimer);
            self.backgroundTimerActive = NO;
        }
        if (self.wakeupTimerActive) {
            dispatch_suspend(self.wakeupTimer);
            self.wakeupTimerActive = NO;
        }
        // If the tryDisconnect timer is active, cancel its execution.
        if (self.tryDisconnectTimerActive) {
            dispatch_suspend(self.tryDisconnectTimer);
            self.tryDisconnectTimerActive = NO;
        }
        if (self.suspendJob) {
            [self.suspendJob cancel];
            self.suspendJob = nil;
        }
        if (self.shutdownJob) {
            [self.shutdownJob cancel];
            self.shutdownJob = nil;
        }
    }

    int64_t t = activeTime - self.backgroundTime;
    atomic_fetch_add(&_totalBackgroundTime, t);
    if (state != TLApplicationStateSuspending) {
        [self.twinlife connect];
        
        // Schedule the jobs after twinlifeResume so that the database is now re-opened for the jobs.
        [self scheduleJobs];
    }
}

- (void)onEnterBackgroundWithApplication:(nullable id<TLApplication>)application {
    DDLogInfo(@"%@ onEnterBackgroundWithApplication", LOG_TAG);

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    @synchronized (self) {
        self.state = TLApplicationStateBackground;
        self.application = application;
        self.backgroundTime = now;

        if (self.shutdownJob) {
            [self.shutdownJob cancel];
        }

        // Setup the shutdown job only if there is no active audio/video call.
        if (self.callCount == 0) {
            self.shutdownJob = [[TLShutdownJob alloc] initWithJobService:self application:application fetchCompletionHandler:nil];
            self.shutdownDeadlineTime = now + SHUTDOWN_TIMEOUT * MSEC_PER_SEC;
        } else {
            self.shutdownJob = nil;
        }

        if (self.online && self.shutdownJob) {
            dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MIN_CONNECTION_TIME * NSEC_PER_SEC));
            dispatch_source_set_timer(self.tryDisconnectTimer, tt, DISPATCH_TIME_FOREVER, 0);
            if (!self.tryDisconnectTimerActive) {
                dispatch_resume(self.tryDisconnectTimer);
                self.tryDisconnectTimerActive = YES;
            }
            self.idleCounter = 0;
        }

        [self cancelJobs];
    }

    if (self.activeTime != 0) {
        int64_t t = now - self.activeTime;
        atomic_fetch_add(&_totalForegroundTime, t);
    }

    // Notify the background job observer we entered background (for now we only need one observer: the conversation scheduler).
    if (self.backgroundJobObserver) {
        [self.backgroundJobObserver onEnterBackground];
    }
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);

    NSMutableArray<TLJobId *> *updateList;
    @synchronized (self) {
        self.updateJobId = nil;
        if (!self.online || self.state != TLApplicationStateForeground) {
            return;
        }

        updateList = self.updateJobList;
        self.updateJobList = [[NSMutableArray alloc] init];
    }

    for (TLJobId *jobId in updateList) {
        dispatch_async([self.twinlife twinlifeQueue], ^{
            [jobId.job runJob];
        });
    }
}

- (void)suspendWithCompletionHandler:(nullable void (^)(TLBaseServiceErrorCode status))completionHandler {
    DDLogInfo(@"%@ suspendWithCompletionHandler", LOG_TAG);

    @synchronized (self) {
        if (self.state == TLApplicationStateForeground) {
            self.state = TLApplicationStateBackground;
        }
        if (self.shutdownJob) {
            [self.shutdownJob terminate];
        }
        self.shutdownJob = [[TLShutdownJob alloc] initWithJobService:self application:nil fetchCompletionHandler:completionHandler];
    }
    [self suspend];
}

- (void)suspend {
    DDLogInfo(@"%@ suspend", LOG_TAG);

    // On iOS 12.0, the backgroundTimeRemaining must be executed only from the main UI thread.
    NSTimeInterval remain;
    if (@available(iOS 13.0, *)) {
        remain = self.application ? [self.application backgroundTimeRemaining] : 0.0;
    } else {
        remain = 0.0;
    }
    @synchronized (self) {
        // It is possible being called a second time by beginBackgroundTaskWithExpirationHandler.
        // We can ignore this call if we are disconnecting.
        // For a VoIP call, it happens that reportActiveVoIPWithCallCount() is called a last time
        // due to a CallKit call if we are already suspended, we have nothing to do.
        if (self.disconnectTimerActive || self.suspendTimerActive || self.state == TLApplicationStateSuspended) {
            return;
        }

        // Invalidate the background timer set by release network lock.
        if (self.backgroundTimerActive) {
            dispatch_suspend(self.backgroundTimer);
            self.backgroundTimerActive = NO;
        }

        // If there is a shutdown job, remove it from the job list but don't call cancel:
        // we want to handle this shutdown job as a normal shutdown but we are calling it earlier than expected.
        if (self.shutdownJob) {
            [self.jobList removeObject:self.shutdownJob.shutdownJobId];
        }

        // We don't want to suspend if there is a VoIP call or we are now in foreground.
        if (self.callCount > 0 || self.state == TLApplicationStateForeground) {
            if (self.shutdownJob) {
                [self.shutdownJob terminate];
                self.shutdownJob = nil;
            }
            return;
        }

        // Move the shutdown job as suspend job.  Its execution will be handled either
        // by onTwinlifeSuspended() or by the suspendTimerHandler().  It is not scheduled.
        self.suspendJob = self.shutdownJob;
        self.shutdownJob = nil;
        self.state = TLApplicationStateSuspending;

        // If the tryDisconnect timer is active, cancel its execution.
        if (self.tryDisconnectTimerActive) {
            dispatch_suspend(self.tryDisconnectTimer);
            self.tryDisconnectTimerActive = NO;
        }

        // Cancel the pending jobs.
        [self cancelJobs];

        // Suspend step #1: setup a timer to close the websocket connection in 500ms (or 10ms for ShareExtension).
        int64_t suspendDelay = self.twinlife.serverConnection ? (int64_t)(SUSPEND_DELAY * NSEC_PER_SEC) : (int64_t) (0.010 * NSEC_PER_SEC);
        DDLogError(@"%@ schedule disconnect timer in %lld (remain %f)", LOG_TAG, suspendDelay, remain);
        dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, suspendDelay);
        dispatch_source_set_timer(self.disconnectTimer, tt, DISPATCH_TIME_FOREVER, 0);
        dispatch_resume(self.disconnectTimer);
        self.disconnectTimerActive = YES;
    }

    // Suspend step #2: let every service prepare for the suspend.
    // Most service will do minimal work but the PeerConnectionService has to terminate any opened P2P connection.
    // We must then keep the connection to Twinlife server open so that the P2P terminate are completed.
    [self.twinlife twinlifeSuspend];
}

/// Final step to handle the suspension called from twinlifeSuspended() after the database has been closed.
/// Returns YES if we suspended correctly and NO if the state indicates we must restart because a Push was
/// received during suspension.
- (BOOL)onTwinlifeSuspended {
    DDLogInfo(@"%@ onTwinlifeSuspended state: %d twinlifeStatus: %d", LOG_TAG, self.state, [self.twinlife status]);

    TLShutdownJob *suspendJob;
    NSTimeInterval delay = 0;
    TLApplicationState state;
    @synchronized (self) {
        if (self.disconnectTimerActive) {
            dispatch_suspend(self.disconnectTimer);
            self.disconnectTimerActive = NO;
        }
        if (self.suspendTimerActive) {
            dispatch_suspend(self.suspendTimer);
            self.suspendTimerActive = NO;
        }

        suspendJob = self.suspendJob;
        if (suspendJob) {
            self.suspendJob = nil;
            // Compute a delay to wakeup the application.
            // There is no guarantee iOS will wakeup after that.
            TLJobId *nextJobId = [self.jobList firstObject];
            if (nextJobId && nextJobId.deadline) {
                delay = [nextJobId.deadline timeIntervalSinceNow];
                if (delay < 120.0) {
                    delay = 120.0;
                }
            }
        }

        state = self.state;
        if (state == TLApplicationStateSuspending) {
            self.state = TLApplicationStateSuspended;
        }
    }
    if (suspendJob) {
        // On iOS 13, also use the background refresh task.
        if (@available(iOS 13.0, *)) {
            if (delay > 0) {
                NSError *error = NULL;
                BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:SCHEDULER_TASK_NAME];
                request.earliestBeginDate = [[NSDate alloc] initWithTimeIntervalSinceNow:delay];
                [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
                DDLogError(@"%@ onTwinlifeSuspended task scheduled in %f or at %@ error: %@", LOG_TAG, delay, request.earliestBeginDate, error);

            } else {
                [[BGTaskScheduler sharedScheduler] cancelTaskRequestWithIdentifier:SCHEDULER_TASK_NAME];
            }

            // Terminate the job, after calling this and returning the iOS will suspend the application.
            [suspendJob terminate];

        } else if (self.application && delay > 0) {

            // Schedule a wakeup timer.  There is no guarantee it will wakeup and in many cases
            // it is executed first (ie, before any other callback).  Set a tolerance of 2mn since
            // we don't really care about the delay (it gives more opportunity to the system to optimize, see doc).
            dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
            dispatch_source_set_timer(self.wakeupTimer, tt, DISPATCH_TIME_FOREVER, 120 * NSEC_PER_SEC);
            if (!self.wakeupTimerActive) {
                DDLogError(@"%@ onTwinlifeSuspended set wakeup in %f", LOG_TAG, delay);
                dispatch_resume(self.wakeupTimer);
                self.wakeupTimerActive = YES;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogError(@"%@ setMinimumBackgroundFetchInterval: %f", LOG_TAG, delay);
                [self.application setMinimumBackgroundFetchInterval:delay];

                // Terminate the job, after calling this and returning the iOS will suspend the application.
                [suspendJob terminate];
            });
        } else {
            
            [suspendJob terminate];
        }
    } else if (state != TLApplicationStateSuspending) {
       DDLogError(@"%@ re-connect after temporary suspend", LOG_TAG);
       [self.twinlife connect];
    }

    // Important note: when we return, it is possible that we are back from suspension.
    // We must return YES if we completed the suspension and we must not look at the self.state
    // because it could have been changed due to a wakeup.
    return state == TLApplicationStateSuspending;
}

#pragma mark - Timer handlers and bgTasks

- (void)handleSchedulerTask:(nonnull BGAppRefreshTask *)bgTask API_AVAILABLE(ios(13.0)) {
    DDLogError(@"%@ handleSchedulerTask", LOG_TAG);

    // Setup the expiration handler and suspend.
    [bgTask setExpirationHandler:^() {
        DDLogError(@"%@ handleSchedulerTask: expiration handler called", LOG_TAG);
        [self emergencySuspendWithJob:nil];
    }];

    self.alarmCount++;

    // Prepare and setup the shutdown job to terminate the background task.
    [self didWakeupWithApplication:self.application kind:TLWakeupKindAlarm fetchCompletionHandler:^(TLBaseServiceErrorCode errorCode) {
        DDLogError(@"%@ handleSchedulerTask: bg task completed %@", LOG_TAG, bgTask);

        // The current thread is running from the twinlifeQueue.  Execute the setTaskCompletedWithSuccess
        // from the main UI thread to avoid a possible deadlock if the main UI thread is blocked by
        // executing the twinlifeResume() which needs a synchronous execution from twinlifeQueue.
        dispatch_async(dispatch_get_main_queue(), ^{
            [bgTask setTaskCompletedWithSuccess:YES];
        });
    }];
}

- (void)wakeupTimerHandler {
    DDLogVerbose(@"%@ wakeupTimerHandler (iOS 12)", LOG_TAG);

    // This timer handler is called when we are back from suspension on iOS 12 only.
    // In most cases, a didReceiveIncomingPushWithApplication or onEnterForeground call
    // will proceed quickly and we don't really need to do something: the timer will be canceled.
    @synchronized (self) {
        if (!self.wakeupTimerActive) {
            return;
        }

        dispatch_suspend(self.wakeupTimer);
        self.wakeupTimerActive = NO;

        if (self.state != TLApplicationStateSuspending && self.state == TLApplicationStateSuspended) {
            return;
        }
        self.alarmCount++;
    }

    // Trigger connection.
    [self.twinlife connect];
}

- (void)tryDisconnectTimerHandler {
    DDLogVerbose(@"%@ tryDisconnectTimerHandler", LOG_TAG);
    
    // Check if we can suspend earlier than the deadline:
    // - there must be no active P2P connection (nobody holds the network lock),
    // - there must be no VoIP call,
    // The timer is activated only when we are in background and the first time we are
    // online, it is initialize to 4s (MIN_CONNECTION_TIME) to give enough time to connect
    // to the server handle incoming requests and have the PeerConnectionService that acquire
    // the network lock.  Then, we check each second until we are suspended.
    @synchronized (self) {
        TLShutdownJob *shutdownJob = self.shutdownJob;
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        if (shutdownJob && self.networkLockCount == 0 && self.callCount == 0 && self.idleCounter > 1) {
            DDLogInfo(@"%@ immediate suspend because there is no activity (%lld ms before deadline)", LOG_TAG, self.shutdownDeadlineTime - now);
            if (self.tryDisconnectTimerActive) {
                dispatch_suspend(self.tryDisconnectTimer);
                self.tryDisconnectTimerActive = NO;
            }

            dispatch_async([self.twinlife twinlifeQueue], ^{
                // Make sure it is still the same shutdown job (otherwise it was canceled).
                if (self.shutdownJob == shutdownJob) {
                    [self suspend];
                }
            });

        } else if (self.callCount == 0) {
            DDLogInfo(@"%@ try disconnect refused (%lld ms before deadline, idle counter: %d)", LOG_TAG, self.shutdownDeadlineTime - now, self.idleCounter);

            dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TRY_DISCONNECT_REPEAT_TIME * NSEC_PER_SEC));
            dispatch_source_set_timer(self.tryDisconnectTimer, tt, DISPATCH_TIME_FOREVER, 0);
            if (!self.tryDisconnectTimerActive) {
                dispatch_resume(self.tryDisconnectTimer);
                self.tryDisconnectTimerActive = YES;
            }
            self.idleCounter++;
        } else {
            DDLogInfo(@"%@ a call is in progress disabling the disconnect timer", LOG_TAG);

            if (self.tryDisconnectTimerActive) {
                dispatch_suspend(self.tryDisconnectTimer);
                self.tryDisconnectTimerActive = NO;
            }
        }
    }
}

- (void)disconnectTimerHandler {
    DDLogInfo(@"%@ disconnectTimerHandler", LOG_TAG);

    // Suspend step #3: disconnect from the Twinlife server.
    @synchronized (self) {
        if (self.backgroundTimerActive) {
            dispatch_suspend(self.backgroundTimer);
            self.backgroundTimerActive = NO;
        }
        if (self.suspendTimerActive) {
            dispatch_suspend(self.suspendTimer);
            self.suspendTimerActive = NO;
        }
        if (self.disconnectTimerActive) {
            dispatch_suspend(self.disconnectTimer);
            self.disconnectTimerActive  = NO;
        }

        // Suspend step #4: give small amount of time to disconnect and schedule a call to endBackgroundTask
        // to terminate the background task.  When terminate is called, the main thread will be suspended.
        if (self.suspendJob) {
            dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DISCONNECT_DELAY * NSEC_PER_SEC));
            dispatch_source_set_timer(self.suspendTimer, tt, DISPATCH_TIME_FOREVER, 0);
            dispatch_resume(self.suspendTimer);
            self.suspendTimerActive = YES;
        }
    }

    // Suspend step #3: do the disconnect.
    [self.twinlife disconnect];

    // Suspend step #5: the onDisconnect will be called on Twinlife or the suspendTimer will fire
    // and we will execute onTwinlifeSuspended to finish the suspension.
}

- (void)suspendTimerHandler {
    DDLogInfo(@"%@ suspendTimerHandler", LOG_TAG);

    @synchronized (self) {
        if (self.suspendTimerActive) {
            dispatch_suspend(self.suspendTimer);
            self.suspendTimerActive = NO;
        }
    }

    if (![self.twinlife twinlifeSuspended]) {
        DDLogInfo(@"%@ suspension was aborted, reconnecting", LOG_TAG);

        // Having a suspendJob at this step should not occur.
        // It is either executed from onTwinlifeSuspend() or terminated if suspension is aborted.
        TLShutdownJob *suspendJob;
        @synchronized (self) {
            suspendJob = self.suspendJob;
            self.suspendJob = nil;
        }
        if (suspendJob) {
            [suspendJob terminate];
        }
        [self.twinlife connect];
    }
}

- (void)scheduleTimerHandler {
    DDLogVerbose(@"%@ scheduleTimerHandler", LOG_TAG);

    @synchronized (self) {
        // Don't execute a job if we are suspending.
        BOOL isSuspending = self.state == TLApplicationStateSuspending;
        TLJobId *nextJobId = nil;

        NSDate *now = [[NSDate alloc] initWithTimeIntervalSinceNow:0.0];
        while (1) {
            TLJobId *job = [self.jobList firstObject];
            if (!job) {
                break;
            }

            if ([job.deadline compare:now] > NSOrderedSame || isSuspending) {
                nextJobId = job;
                break;
            }

            dispatch_async([self.twinlife twinlifeQueue], ^{
                DDLogVerbose(@"%@ runJob job: %@ now: %@ delta: %f", LOG_TAG, job, now, [job.deadline timeIntervalSinceDate:now]);
                [job.job runJob];
            });
            [self.jobList peekObject];
        }

        [self setScheduleTimerWithJob:nextJobId];
    }
}

- (void)stopBackgroundJobTimerHandler {
    DDLogVerbose(@"%@ stopBackgroundJobTimerHandler", LOG_TAG);

    @synchronized (self) {
        if (self.backgroundTimerActive) {
            dispatch_suspend(self.backgroundTimer);
            self.backgroundTimerActive = NO;
        }

        // If we are in foreground, we are done.
        if (self.state == TLApplicationStateForeground) {
            return;
        }

        // If there is a shutdown job, remove it from the job list but don't call cancel:
        // we want to handle this shutdown job as a normal shutdown but we are calling it earlier than expected.
        if (self.shutdownJob) {
            [self.jobList removeObject:self.shutdownJob.shutdownJobId];
        }

        // Cancel the pending jobs.
        [self cancelJobs];
    }

    // Disconnecting improves the re-connection and wakeup process but we must not disconnect
    // while we have a VoIP call in progress (this is checked by suspend).
    [self suspend];
}

#pragma mark - Private methods

- (void)cancelWithJobId:(nonnull TLJobId *)jobId {
    DDLogVerbose(@"%@ cancelWithJobId: %@", LOG_TAG, jobId);

    @synchronized (self) {
        if (jobId.priority == TLJobPriorityUpdate) {
            [self.updateJobList removeObject:jobId];
        } else {
            [self.jobList removeObject:jobId];
        }
        if (self.jobList.count == 0 && self.scheduleTimerActive) {
            dispatch_suspend(self.scheduleTimer);
            self.scheduleTimerActive = NO;
        } else if (self.scheduledJobId == jobId) {
            [self setScheduleTimerWithJob:[self.jobList firstObject]];
        }
    }
}

- (void)emergencySuspendWithJob:(nullable TLShutdownJob *)shutdownJob {
    DDLogWarn(@"%@ emergencySuspendWithJob: %@", LOG_TAG, shutdownJob);

    [self suspend];

    // The background task expiration handler should never be called: we try to stop
    // before the expiration delay.  When it is called, we must not return before the
    // background task handler has been called otherwise iOS will report a fault/crash
    // in the application.  We cannot block the main UI thread for too long either
    // and trying to synchronize and wait for the complete shutdown appears complex and risky.
    // Instead, block the current thread for 1.0 second which should be enough.
    [NSThread sleepForTimeInterval:EMERGENCY_SUSPEND_DELAY];
}

- (void)scheduleJobs {
    DDLogVerbose(@"%@ scheduleJobs", LOG_TAG);

    @synchronized (self) {
        // Setup the job to execute foreground updates: it is scheduled only when we are connected.
        if (self.online && self.state == TLApplicationStateForeground && !self.updateJobId) {
            self.updateJobId = [[TLJobId alloc] initWithJobService:self job:self deadline:[[NSDate alloc] initWithTimeIntervalSinceNow:JOB_UPDATE_DELAY] priority:TLJobPriorityUpdate];
            [self.jobList addObject:self.updateJobId allowDuplicate:YES];
        }

        TLJobId *nextJobId = [self.jobList firstObject];
        if (nextJobId == self.scheduledJobId && ((nextJobId && self.scheduleTimerActive) || (!nextJobId && !self.scheduleTimerActive))) {
            return;
        }
        [self setScheduleTimerWithJob:nextJobId];
    }
}

- (void)cancelJobs {
    DDLogVerbose(@"%@ cancelJobs", LOG_TAG);

    @synchronized (self) {
        if (self.updateJobId) {
            [self.jobList removeObject:self.updateJobId];
            self.updateJobId = nil;
        }
        TLJobId *nextJobId = [self.jobList firstObject];
        if (nextJobId == self.scheduledJobId) {
            return;
        }

        if (self.scheduleTimerActive) {
            dispatch_suspend(self.scheduleTimer);
            self.scheduleTimerActive = NO;
        }
    }

    [self scheduleJobs];
}

- (void)setScheduleTimerWithJob:(nullable TLJobId *)nextJobId {
    DDLogVerbose(@"%@ setScheduleTimerWithJob", LOG_TAG);

    @synchronized (self) {
        self.scheduledJobId = nextJobId;

        if (!nextJobId || !nextJobId.deadline) {
            if (self.scheduleTimerActive) {
                dispatch_suspend(self.scheduleTimer);
                self.scheduleTimerActive = NO;
            }
            return;
        }

        NSTimeInterval delay = [nextJobId.deadline timeIntervalSinceNow];

        DDLogInfo(@"%@ scheduleTimer in %f for job %@", LOG_TAG, delay, nextJobId);

        int64_t leeway;

        // Avoid scheduling a job while we are suspending because it may execute while we are in middle of suspension.
        // Setup to run it after suspension, it will be executed when we resume.
        if (self.state == TLApplicationStateSuspending && delay <= DISCONNECT_DELAY + SUSPEND_DELAY + RESUME_DELAY) {
            delay = DISCONNECT_DELAY + SUSPEND_DELAY + RESUME_DELAY;
            leeway = 0;
        } else if (delay < 0) {
            delay = 0.0;
            leeway = 0;
        } else if (delay <= 120) {
            leeway = 0;
        } else {
            // For high delay, we can accomodate for a low accuracy.
            leeway = 120 * NSEC_PER_SEC;
        }

        dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
        dispatch_source_set_timer(self.scheduleTimer, tt, DISPATCH_TIME_FOREVER, leeway);
        if (!self.scheduleTimerActive) {
            dispatch_resume(self.scheduleTimer);
            self.scheduleTimerActive = YES;
        }
    }
}

@end

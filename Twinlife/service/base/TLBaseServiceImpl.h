/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#include <stdatomic.h>
#import <WebRTC/RTCMacros.h>

#import "TLBaseService.h"
#import "TLTwinlifeImpl.h"
#import "TLJobService.h"

@class RTC_OBJC_TYPE(RTCHostname);

// TBD duplicate information
static NSString * _Nonnull SERVICE_NAMES[] = {
    @"account.twinlife",
    @"connectivity.twinlife",
    @"conversation.twinlife",
    @"management.twinlife",
    @"notification.twinlife",
    @"peer-connection.twinlife",
    @"repository.twinlife",
    @"factory.twincode.twinlife",
    @"inbound.twincode.twinlife",
    @"outbound.twincode.twinlife",
    @"image.twinlife",
    @"callservice.twinlife"
};

#define TL_BASE_SERVICE_IMPL_MAX_FRAME_SIZE 921600 // HD=1280x720
#define TL_BASE_SERVICE_IMPL_MAX_FRAME_RATE 30

@interface TLRequestInfo : NSObject

@property (readonly) int64_t requestId;
@property (readonly) BOOL isBinary;

- (nonnull instancetype)initWithRequestId:(int64_t)requestId isBinary:(BOOL)isBinary;

@end

//
// Interface: TLBaseServiceImplConfiguration ()
//

@interface TLBaseServiceImplConfiguration : NSObject

@property int maxSentFrameSize;
@property int maxSentFrameRate;
@property int maxReceivedFrameSize;
@property int maxReceivedFrameRate;
@property (nonnull) NSArray<TLTurnServer *> *turnServers;
@property (nonnull) NSArray<RTC_OBJC_TYPE(RTCHostname) *> *hostnames;
@property (nullable) NSString *features;
@property (nullable) NSUUID *environmentId;

- (nonnull instancetype)init;

- (BOOL)isUpdatedConfiguration:(nonnull TLBaseServiceImplConfiguration *)configuration;

@end

//
// Interface: TLBaseService ()
//

@class FMDatabaseQueue;
@class TLAttributeNameValue;
@class TLDataInputStream;
@class TLServerConnection;

@interface TLBaseService ()<TLJob>

@property (nonnull) TLTwinlife *twinlife;

@property (nonnull) TLBaseServiceConfiguration *serviceConfiguration;

@property (getter=isConfigured) BOOL configured;
@property (getter=isServiceOn) BOOL serviceOn;
@property BOOL signIn;
@property BOOL online;

@property (nonnull) NSSet<id<TLBaseServiceDelegate>> *delegates;
@property (nullable) TLServerConnection *serverStream;

@property atomic_int databaseFullCount;
@property atomic_int databaseErrorCount;
@property uint64_t lastDatabaseErrorTime;

@property atomic_int sendCount;
@property atomic_int sendErrorCount;
@property atomic_int sendDisconnectedCount;
@property atomic_int sendTimeoutCount;
@property (readonly, nonnull) TLJobService *jobService;
@property (nullable) TLJobId *scheduleJobId;
@property (nullable) NSDate *nextDeadline;
@property (nonnull) NSMutableSet<TLRequestInfo *> *pendingRequestIdList;

- (void)timeoutWithRequestIds:(nonnull NSSet<TLRequestInfo *> *)requestIds;

+ (nullable TLAttributeNameValue *)deserializeWithDataInputStream:(nonnull TLDataInputStream *)dataInputStream;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife;

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration;

- (BOOL)activate:(nonnull TLServerConnection *)stream;

- (void)onCreate;

- (void)onConfigure;

- (void)onUpdateConfigurationWithConfiguration:(nonnull TLBaseServiceImplConfiguration *)configuration;

- (void)onDestroy;

- (void)onConnect;

- (void)onDisconnect;

- (void)onSignIn;

- (void)onSignInErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onSignOut;

- (void)onTwinlifeReady;

- (void)onTwinlifeSuspend;

- (void)onTwinlifeResume;

- (void)onTwinlifeOnline;

- (void)onErrorWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (nonnull TLServiceStats *)getDatabaseStatsWithServiceStats:(nonnull TLServiceStats *)stats;

@end

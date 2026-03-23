/*
 *  Copyright (c) 2014-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAccountService.h"
#import "TLBackupInfo.h"

@class TLAuthChallengeIQ;
@class TLOnAuthChallengeIQ;
@class TLRestoreChallengeIQ;

typedef void(^ConsumerBlock)(TLBaseServiceErrorCode errorCode, id _Nullable result);

@interface TLAccountPendingRequest : NSObject

@property (readonly) int requestKind;

- (nonnull instancetype)initWithRequestKind:(int)requestKind;
@end

@interface TLConsumerAccountPendingRequest : TLAccountPendingRequest

@property (readonly, nonatomic, nonnull) ConsumerBlock consumer;

- (nonnull instancetype)initWithRequestKind:(int)requestKind consumer:(nonnull ConsumerBlock)consumer;

@end


@interface TLAuthChallengePendingRequest : TLAccountPendingRequest

@property (readonly, nonatomic, nonnull) TLAuthChallengeIQ *authChallengeIQ;

- (nonnull instancetype)initWithAuthChallengeIQ:(nonnull TLAuthChallengeIQ *)authChallengeIQ;

@end

@interface TLAuthRequestPendingRequest : TLAccountPendingRequest

@property (readonly, nonatomic, nonnull) TLAuthChallengeIQ *authChallengeIQ;
@property (readonly, nonatomic, nonnull) TLOnAuthChallengeIQ *onAuthChallengeIQ;
@property (readonly, nonatomic, nonnull) NSData *serverKey;
@property (readonly, nonatomic) int64_t authRequestTime;

- (nonnull instancetype)initWithAuthChallengeIQ:(nonnull TLAuthChallengeIQ *)authChallengeIQ onAuthChallengeIQ:(nonnull TLOnAuthChallengeIQ *)onAuthChallengeIQ serverKey:(nonnull NSData *)serverKey authRequestTime:(int64_t)authRequestTime;

@end

@interface TLChangePasswordPendingRequest : TLAccountPendingRequest

@property (readonly, nonatomic, nonnull) NSString *devicePassword;

- (nonnull instancetype)initWithDevicePassword:(nonnull NSString *)devicePassword;

@end

@interface TLGenerateBackupPasswordPendingRequest : TLConsumerAccountPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer;

@end

@interface TLGetAllBackupsPendingRequest : TLConsumerAccountPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer;

@end

@interface TLDeleteBackupsPendingRequest : TLConsumerAccountPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer;

@end

@interface TLTerminateRestorePendingRequest : TLConsumerAccountPendingRequest

- (nonnull instancetype)initWithConsumer:(nonnull ConsumerBlock)consumer;

@end

@interface TLRestoreChallengePendingRequest : TLConsumerAccountPendingRequest

@property (readonly, nonatomic, nonnull)NSString *accountPassword;
@property (readonly, nonatomic, nonnull)TLRestoreChallengeIQ *restoreChallengeIQ;

- (nonnull instancetype)initWithAccountPassword:(nonnull NSString *)accountPassword restoreChallengeIQ:(nonnull TLRestoreChallengeIQ *)restoreChallengeIQ consumer:(nonnull ConsumerBlock)consumer;

@end

@interface TLRestoreRequestPendingRequest : TLConsumerAccountPendingRequest

@property (readonly, nonatomic, nonnull)TLRestoreChallengeIQ *restoreChallengeIQ;
@property (readonly, nonatomic, nonnull)TLOnAuthChallengeIQ *onRestoreChallengeIQ;
@property (readonly, nonatomic, nonnull)NSData *serverKey;


- (nonnull instancetype)initWithRestoreChallengePendingRequest:(nonnull TLRestoreChallengePendingRequest *)restoreChallengePendingRequest onRestoreChallengeIQ:(nonnull TLOnAuthChallengeIQ *)onRestoreChallengeIQ serverKey:(nonnull NSData *)serverKey;

@end

//
// Interface: TLAccountService ()
//

@class TLAccountServiceSecuredConfiguration;

@interface TLAccountService ()

@property (nullable) TLAccountServiceSecuredConfiguration *securedConfiguration;
// Used to login with the restored account during a restore. Null otherwise.
@property (nullable) TLAccountServiceSecuredConfiguration *restoreSecuredConfiguration;
@property (readonly, nonnull) NSMutableSet *allowedFeatures;

- (void)configure:(nonnull TLBaseServiceConfiguration*)baseServiceConfiguration applicationId:(nonnull NSUUID *)applicationId serviceId:(nonnull NSUUID *)serviceId;

/// Get the environment id that was configured for the device by the server.
- (nullable NSUUID *)environmentId;

- (nullable NSString *)user;

/// Check if the account was disabled.
- (BOOL)isAccountDisabled;

- (void)generateBackupKeyWithBackupId:(nonnull NSUUID *)backupId password:(nonnull NSData *)password salt:(nonnull NSData *)salt forRestore:(BOOL)forRestore withBlock:(nonnull void (^)(TLBaseServiceErrorCode status, NSData * _Nullable serverDerivedKey, NSUUID * _Nullable lastBackupId, int64_t lastBackupTimestamp))block;
- (void)setRestoreAccountConfigurationWithAccountConfiguration:(nullable TLAccountServiceSecuredConfiguration *)accountConfiguration;

- (void)getAllBackupsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode status, NSArray<TLBackupInfo *> * _Nullable backups))block;
- (void)deleteBackupsWithBlock:(nonnull void (^)(TLBaseServiceErrorCode status))block;
@end

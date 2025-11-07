/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBaseService.h"
#import "TLTwincode.h"
#import "TLDatabase.h"
#import "TLTwincodeURI.h"
#import "TLInvitationCode.h"

@class TLImageId;
@class TLTwincodeInbound;

#define TL_LONG_REFRESH_PERIOD (24 * 3600 * 1000) // 1 day (ms)
#define TL_REFRESH_PERIOD      (3600 * 1000)      // 1 hour (ms)
#define TL_NO_REFRESH_PERIOD   0

//
// Interface: TLTwincodeOutbound
//

@interface TLTwincodeOutbound : TLTwincode <TLDatabaseObject>

- (nullable NSString *)name;

- (nullable NSString *)twincodeDescription;

- (nullable NSString *)capabilities;

- (nullable TLImageId *)avatarId;

/// YES if the twincode is known, otherwise the attributes must be fetched from the server by calling getTwincodeWithTwincodeId.
- (BOOL)isKnown;

/// Whether the twincode attributes are signed by a public key.
- (BOOL)isSigned;

/// Whether SDPs are encrypted when sending/receiving (secret keys are known).
- (BOOL)isEncrypted;

/// Whether the twincode public key is trusted.
- (BOOL)isTrusted;

/// Whether the twincode attributes and the signature are verified and match.
- (BOOL)isVerified;

/// Whether the twincode was certified as part of the contact certification process.
- (BOOL)isCertified;

/// Whether the twincode public key is trusted and how.
- (TLTrustMethod)trustMethod;

@end

//
// Interface: TLTwincodeOutboundServiceConfiguration
//

@interface TLTwincodeOutboundServiceConfiguration : TLBaseServiceConfiguration

@property BOOL enableTwincodeRefresh;

@end

//
// Protocol: TLTwincodeOutboundServiceDelegate
//

@protocol TLTwincodeOutboundServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onRefreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound*)twincodeOutbound previousAttributes:(nonnull NSArray<TLAttributeNameValue *> *)previousAttributes;

@end

#define TLInvokeTwincodeUrgent       0x01 // Invoke the twincode and try to wakeup the peer immediately.
#define TLInvokeTwincodeWakeup       0x02 // Invoke the twincode with a persistent wakeup.

// Create a secret to send in the secureInvokeTwincode() unless it already exists for the twincode pair.
// This option allows to have a secureInvokeTwincode() that is idempotent: we can repeat it several times
// and the peer will always perform the same operation.  This is important for a contact creation but also
// for the group join invocation.  It is possible that such secureInvokeTwincode are executed several times
// due to retries or interruptions.  This implies TLInvokeTwincodeSendSecret.
#define TLInvokeTwincodeCreateSecret 0x04

// Create a new secret to send in the secureInvokeTwincode().  This implies TLInvokeTwincodeSendSecret.
#define TLInvokeTwincodeCreateNewSecret 0x08

// Send the current secret in the secureInvokeTwincode().
#define TLInvokeTwincodeSendSecret      0x10

//
// Interface: TLTwincodeOutboundService
//

@class TLAttributeNameValue;

@interface TLTwincodeOutboundService : TLBaseService

+ (nonnull NSString *)VERSION;

- (void)getTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeOutboundId refreshPeriod:(int64_t)refreshPeriod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block;

/// Get the twincode signed by the public key and verify the attribute signatures when we get it from the server.
/// This operation is not cached and requires a round-trip to the server.
- (void)getSignedTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block;

- (void)getSignedTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey trustMethod:(TLTrustMethod)trustMethod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block;

/// Refresh the twincode by getting the attributes from the server, checking that the twincode is still valid
/// and identify the attributes that have been modified.
- (void)refreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLAttributeNameValue *> *_Nullable previousAttributes))block;

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block;

/// Invoke an action on the outbound twincode with a set of attributes.  Call back the completion
/// handler with the invocation id or an error code.  The invoke action is received by the peer
/// on the inbound twincode and managed by the TwincodeInboundService.
- (void)invokeTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound options:(int)options action:(nonnull NSString *)action attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable invocationId))block;

- (void)secureInvokeTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)cipherTwincode senderTwincode:(nonnull TLTwincodeOutbound *)senderTwincode receiverTwincode:(nonnull TLTwincodeOutbound *)receiverTwincode options:(int)options action:(nonnull NSString *)action attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable invocationId))block;

/// Get the peer identification string to initiate a WebRTC call and indicate our outbound receiving side.
- (nonnull NSString *)getPeerId:(nonnull NSUUID *)peerTwincodeOutboundId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId;

- (void)evictTwincode:(nonnull NSUUID *)twincodeOutboundId;

- (void)evictWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (void)createURIWithTwincodeKind:(TLTwincodeURIKind)kind twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block;

- (void)parseUriWithUri:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block;

/// Create a private key for the twincode inbound and twincode outbound.
/// Note: we force to specify a twincode inbound to enforce the availability of the inbound
/// and link with the outbound twincode.
- (void)createPrivateKeyWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block;

/// Associate the two twincodes so that the secret used to encrypt our SDPs is specific to the peer twincode.
/// The secret was associated with `previousPeerTwincodeOutbound` and we want to associate it with another twincode.
/// The secret was sent through a `secureInvokeTwincode()` to a first twincode (a profile or a Contact conversation)
/// and we will communicate by using another twincode that we have received after (the contact peer or the group member
/// that invited us).
- (void)associateTwincodes:(nonnull TLTwincodeOutbound *)twincodeOutbound previousPeerTwincode:(nullable TLTwincodeOutbound *)previousPeerTwincode peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode;

/// Mark the two twincode relation as certified by the given trust process.
- (void)setCertifiedWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode trustMethod:(TLTrustMethod)trustMethod;

/// Invitation codes

- (void)createInvitationCodeWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound validityPeriod:(int)validityPeriod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvitationCode *_Nullable invitationCode))block;

- (void)getInvitationCodeWithCode:(nonnull NSString *)code withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound, NSString *_Nullable publicKey))block;

@end

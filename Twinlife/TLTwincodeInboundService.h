/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"
#import "TLTwincode.h"
#import "TLDatabase.h"

@class TLTwincodeOutbound;
@protocol TLRepositoryObject;

//
// Interface: TLTwincodeInbound
//

@interface TLTwincodeInbound : TLTwincode <TLDatabaseObject>

- (nullable NSString *)capabilities;

- (nonnull TLTwincodeOutbound *)twincodeOutbound;

- (nullable NSUUID *)twincodeFactoryId;

@end

//
// Interface: TLTwincodeInvocation
//

/**
 * The twincode invocation contains information when we receive a peer's invocation that was made with
 * the `invokeTwincode` or `secureInvokeTwincode` operation.  It contains a first part provided and
 * filled by the invoker twincode and a second part filled locally when the invocation content was
 * encrypted and is decrypted and verified.
 */
@interface TLTwincodeInvocation : NSObject

@property (readonly, nonnull) NSUUID *invocationId;
@property (readonly, nonnull) id<TLRepositoryObject> subject;
@property (readonly, nonnull) NSString *action;
@property (readonly, nullable) NSMutableArray<TLAttributeNameValue *> *attributes;

@property (readonly, nullable) NSUUID *peerTwincodeId;
@property (readonly, nullable) NSData *secretKey;
@property (readonly, nullable) NSString *publicKey;
@property (readonly) int keyIndex;
@property (readonly) TLTrustMethod trustMethod;

@end

//
// Interface: TLTwincodeInboundServiceConfiguration
//

@interface TLTwincodeInboundServiceConfiguration:TLBaseServiceConfiguration

@end

typedef TLBaseServiceErrorCode (^TLTwincodeInvocationListener) (TLTwincodeInvocation * _Nonnull invocation);

//
// Interface: TLTwincodeInboundService
//

@interface TLTwincodeInboundService:TLBaseService

+ (nonnull NSString *)VERSION;

/// Add a listener for the given twincode invocation action.
- (void)addListenerWithAction:(nonnull NSString *)action listener:(nonnull TLTwincodeInvocationListener)listener;

- (void)getTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeInboundId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeinbound))block;

- (void)bindTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeInbound))block;

- (void)unbindTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeInbound))block;

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeInbound *_Nullable twincodeInbound))block;

- (void)acknowledgeInvocationWithInvocationId:(nonnull NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

/// Trigger the incoming peer connections as well as the pending invocations.  When a filters is defined, only the pending invocations with the action
/// names defined in the list will be triggered.
- (void)triggerPendingInvocationsWithFilters:(nullable NSArray<NSString *> *)filters withBlock:(nonnull void (^)(void))block;

/// Wait until all pending invocations for the given twincode inbound Id have been processed and execute the code block.
/// If there is no pending invocation for the twincode, the code block is executed immediately.
- (void)waitInvocationsForTwincode:(nonnull NSUUID *)twincodeId withBlock:(nonnull void (^) (void))block;

/// Check if we have some pending invocations being processed.
- (BOOL)hasPendingInvocations;

@end

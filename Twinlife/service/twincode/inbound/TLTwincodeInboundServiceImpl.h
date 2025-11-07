/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwincodeInboundService.h"
#import "TLBaseServiceImpl.h"
#import "TLTwincodeImpl.h"
#import "TLTwincodeInboundServiceProvider.h"

//
// Interface: TLGetInboundTwincodePendingRequest ()
//

typedef void (^TLInboundTwincodeConsumer) (TLBaseServiceErrorCode status, TLTwincodeInbound * _Nullable twincodeInbound);

@interface TLGetInboundTwincodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (readonly, nonnull) TLInboundTwincodeConsumer complete;

-(nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound complete:(nonnull TLInboundTwincodeConsumer)complete;

@end

//
// Interface: TLBindUnbindTwincodePendingRequest ()
//

@interface TLBindUnbindTwincodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) TLTwincodeInbound *twincode;
@property (readonly, nonnull) TLInboundTwincodeConsumer complete;

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeInbound *)twincode complete:(nonnull TLInboundTwincodeConsumer)complete;

@end

//
// Interface: TLUpdateInboundTwincodePendingRequest ()
//

@interface TLUpdateInboundTwincodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) TLTwincodeInbound *twincode;
@property (readonly, nonnull) NSArray<TLAttributeNameValue *> *attributes;
@property (readonly, nonnull) TLInboundTwincodeConsumer complete;

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeInbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes complete:(nonnull TLInboundTwincodeConsumer)complete;

@end

//
// Interface: TLTriggerInvocationsPendingRequest ()
//
typedef void (^TLTriggerInvocationConsumer) (void);

@interface TLTriggerInvocationsPendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) TLTriggerInvocationConsumer complete;

-(nonnull instancetype)initWithComplete:(nonnull TLTriggerInvocationConsumer)complete;

@end

//
// Interface: TLTwincodeInbound ()
//

@interface TLTwincodeInbound ()

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property (nullable) NSUUID *factoryId;
@property (nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (nullable) NSString *capabilities;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId factoryId:(nullable NSUUID *)factoryId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound capabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate ;

- (void)importWithAttributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (void)updateWithCapabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate;

- (nullable NSData *)serialize;

@end

//
// Interface: TLTwincodeInvocation
//

@interface TLTwincodeInvocation ()

- (nonnull instancetype) initWithInvocationId:(nonnull NSUUID *)invocationId subject:(nonnull id<TLRepositoryObject>)subject action:(nonnull NSString *)action attributes:(nullable NSMutableArray<TLAttributeNameValue *> *)attributes peerTwincodeId:(nullable NSUUID *)peerTwincodeId keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey publicKey:(nullable NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod;

@end

//
// Interface: TLTwincodeInboundService ()
//

@interface TLTwincodeInboundService ()

+ (void)initialize;

@end

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

#import "TLTwincodeOutboundService.h"
#import "TLBaseServiceImpl.h"
#import "TLTwincodeImpl.h"
#import "TLJobService.h"

#define FLAG_NEED_FETCH 0x01  // When set, we must get the twincode attributes from the server.
#define FLAG_SIGNED     0x02
#define FLAG_TRUSTED    0x04
#define FLAG_VERIFIED   0x08
#define FLAG_ENCRYPT    0x10
#define FLAG_CERTIFIED  0x20
#define FLAG_OWNER      0x100

#define TRUST_METHOD_SHIFT 8

// Twincodes created with the factory are signed, trusted and we are OWNER.
#define TWINCODE_CREATE_FLAGS (FLAG_SIGNED|FLAG_TRUSTED|FLAG_OWNER)

//
// Interface: TLTwincodeOutbound ()
//

@class TLImageId;

@interface TLTwincodeOutbound ()

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property (nullable) NSString *name;
@property (nullable) NSString *twincodeDescription;
@property (nullable) NSString *capabilities;
@property (nullable) TLImageId *avatarId;
@property int flags;

+ (int)toFlagsWithTrustMethod:(TLTrustMethod)trustMethod;

+ (TLTrustMethod)toTrustMethodWithFlags:(int)flags;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId name:(nullable NSString *)name description:(nullable NSString *)description avatarId:(nullable TLImageId *)avatarId capabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate flags:(int)flags;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes flags:(int)flags modificationDate:(int64_t)modificationDate;

- (void)updateWithName:(nullable NSString*)name description:(nullable NSString *)description avatarId:(nullable TLImageId *)avatarId capabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate flags:(int)flags;

- (void)importWithAttributes:(nonnull NSArray<TLAttributeNameValue *> *)update previousAttributes:(nullable NSMutableArray<TLAttributeNameValue *> *)previousAttributes modificationDate:(int64_t)modificationDate;

- (nonnull NSMutableArray<TLAttributeNameValue *> *)getAttributes:(nullable NSArray<TLAttributeNameValue *> *)attributes deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames;

- (nullable NSData *)serialize;

- (void)needFetch;

/// Whether the twincode was created by this application.
- (BOOL)isOwner;

@end

typedef void (^TLTwincodeConsumer) (TLBaseServiceErrorCode status, TLTwincodeOutbound * _Nullable twincodeOutbound);

//
// Interface: TLGetTwincodePendingRequest ()
//

@interface TLGetTwincodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nullable) NSString *publicKey;
@property (readonly, nullable) NSData *secretKey;
@property (readonly) int64_t refreshPeriod;
@property (readonly) TLTrustMethod trustMethod;
@property (readonly) int keyIndex;
@property (readonly, nonnull) TLTwincodeConsumer complete;

-(nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId refreshPeriod:(int64_t)refreshPeriod publicKey:(nullable NSString *)publicKey keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey trustMethod:(TLTrustMethod)trustMethod complete:(nonnull TLTwincodeConsumer)complete;

@end

typedef void (^TLTwincodeRefreshConsumer) (TLBaseServiceErrorCode status, NSMutableArray<TLAttributeNameValue *> * _Nullable updatedAttributes);

//
// Interface: TLRefreshTwincodePendingRequest ()
//

@interface TLRefreshTwincodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (readonly) int64_t refreshPeriod;
@property (readonly, nonnull) TLTwincodeRefreshConsumer complete;

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode complete:(nonnull TLTwincodeRefreshConsumer)complete;

@end

//
// Interface: TLUpdateTwincodePendingRequest ()
//

@interface TLUpdateTwincodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) TLTwincodeOutbound *twincode;
@property (readonly, nonnull) NSArray<TLAttributeNameValue *> *attributes;
@property (readonly) BOOL isSigned;
@property (readonly, nonnull) TLTwincodeConsumer complete;

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes isSigned:(BOOL)isSigned complete:(nonnull TLTwincodeConsumer)complete;

@end

//
// Interface: TLInvokeTwincodePendingRequest ()
//

typedef void (^TLInvokeTwincodeComplete) (TLBaseServiceErrorCode status, NSUUID * _Nullable invocationId);

@interface TLInvokeTwincodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) TLTwincodeOutbound *twincode;
@property (readonly, nonnull) TLInvokeTwincodeComplete complete;

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode complete:(nonnull TLInvokeTwincodeComplete)complete;

@end

//
// Interface: TLRefreshTwincodesPendingRequest ()
//

@interface TLRefreshTwincodesPendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) NSMutableDictionary<NSUUID *, NSNumber *> *refreshList;

-(nonnull instancetype)initWithRefreshList:(nonnull NSMutableDictionary<NSUUID *, NSNumber *> *)refreshList;

@end

//
// Interface: TLCreateInvitationCodePendingRequest ()
//
typedef void (^TLCreateInvitationCodeConsumer) (TLBaseServiceErrorCode status, TLInvitationCode * _Nullable invitationCode);

@interface TLCreateInvitationCodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (readonly, nonnull) TLCreateInvitationCodeConsumer consumer;

-(nonnull instancetype)initWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound consumer:(nonnull TLCreateInvitationCodeConsumer)consumer;

@end

//
// Interface: TLGetInvitationCodePendingRequest ()
//
typedef void (^TLGetInvitationCodeConsumer) (TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound, NSString *_Nullable publicKey);

@interface TLGetInvitationCodePendingRequest : TLTwincodePendingRequest

@property (readonly, nonnull) NSString *code;
@property (readonly, nonnull) TLGetInvitationCodeConsumer consumer;

-(nonnull instancetype)initWithCode:(nonnull NSString *)code consumer:(nonnull TLGetInvitationCodeConsumer)consumer;

@end


//
// Interface: TLTwincodeOutboundService ()
//

@interface TLTwincodeOutboundService ()

@property (readonly, nonnull) NSString *serviceJid;

@end

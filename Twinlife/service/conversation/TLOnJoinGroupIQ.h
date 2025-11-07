/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLDescriptorId;

//
// Interface: TLOnJoinGroupMemberInfo
//

@interface TLOnJoinGroupMemberInfo : NSObject

@property (readonly, nonnull) NSUUID *memberTwincodeId;
@property (readonly, nullable) NSString *publicKey;
@property (readonly) int64_t permissions;

- (nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId publicKey:(nullable NSString *)publicKey permissions:(int64_t)permissions;

@end

//
// Interface: TLOnJoinGroupIQSerializer
//

@interface TLOnJoinGroupIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnJoinGroupIQ
//

@interface TLOnJoinGroupIQ : TLBinaryPacketIQ

@property (readonly) int deviceState;
@property (readonly, nullable) NSUUID *inviterTwincodeId;
@property (readonly) int64_t inviterPermissions;
@property (readonly, nullable) NSString *publicKey;
@property (readonly, nullable) NSData *secretKey;
@property (readonly) int64_t permissions;
@property (readonly, nullable) NSString *inviterSalt;
@property (readonly, nullable) NSString *inviterSignature;
@property (readonly, nullable) NSArray<TLOnJoinGroupMemberInfo *> *members;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState inviterTwincodeId:(nullable NSUUID *)inviterTwincodeId inviterPermissions:(int64_t)inviterPermissions publicKey:(nullable NSString *)publicKey secretKey:(nullable NSData *)secretKey permissions:(int64_t)permissions inviterSalt:(nullable NSString *)inviterSalt inviterSignature:(nullable NSString *)inviterSignature members:(nullable NSArray<TLOnJoinGroupMemberInfo *> *)members;

@end

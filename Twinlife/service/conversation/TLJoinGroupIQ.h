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
// Interface: TLJoinGroupIQSerializer
//

@interface TLJoinGroupIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLJoinGroupIQ
//

@interface TLJoinGroupIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLDescriptorId *invitationDescriptorId;
@property (readonly, nonnull) NSUUID *groupTwincodeId;
@property (readonly, nullable) NSUUID *memberTwincodeId;
@property (readonly, nullable) NSString *publicKey;
@property (readonly, nullable) NSData *secretKey;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId invitationDescriptorId:(nonnull TLDescriptorId *)invitationDescriptorId groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId publicKey:(nullable NSString *)publicKey secretKey:(nullable NSData *)secretKey;

@end

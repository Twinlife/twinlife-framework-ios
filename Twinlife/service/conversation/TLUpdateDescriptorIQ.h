/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLDescriptorId;

//
// Interface: TLUpdateDescriptorIQSerializer
//

@interface TLUpdateDescriptorIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateDescriptorIQ
//

@interface TLUpdateDescriptorIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLDescriptorId *descriptorId;
@property (readonly) int64_t updatedTimestamp;
@property (readonly, nullable) NSString *message;
@property (readonly, nullable) NSNumber *flagCopyAllowed;
@property (readonly, nullable) NSNumber *expiredTimeout;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId updatedTimestamp:(int64_t)updatedTimestamp message:(nullable NSString *)message copyAllowed:(nullable NSNumber *)copyAllowed expiredTimeout:(nullable NSNumber *)expiredTimeout;

@end

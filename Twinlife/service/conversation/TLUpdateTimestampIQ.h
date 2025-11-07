/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"
#import "TLUpdateDescriptorTimestampOperation.h"

//
// Interface: TLUpdateTimestampIQSerializer
//

@interface TLUpdateTimestampIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateTimestampIQ
//

@interface TLUpdateTimestampIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLDescriptorId *descriptorId;
@property (readonly) TLUpdateDescriptorTimestampType timestampType;
@property (readonly) int64_t timestamp;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId timestampType:(TLUpdateDescriptorTimestampType)timestampType timestamp:(int64_t)timestamp;

@end

//
// Interface: TLOnUpdateTimestampIQ
//

@interface TLOnUpdateTimestampIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

@end

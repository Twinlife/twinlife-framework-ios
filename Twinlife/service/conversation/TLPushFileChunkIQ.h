/*
 *  Copyright (c) 2021-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLDescriptorId;

//
// Interface: TLPushFileChunkIQSerializer
//

@interface TLPushFileChunkIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPushFileChunkIQ
//

@interface TLPushFileChunkIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLDescriptorId *descriptorId;
@property (readonly) int64_t timestamp;
@property (readonly) int64_t chunkStart;
@property (readonly) int32_t startPos;
@property (readonly) int32_t length;
@property (readonly, nullable) NSData *chunk;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp chunkStart:(int64_t)chunkStart startPos:(int32_t)startPos chunk:(nullable NSData *)chunk length:(int32_t)length;

@end

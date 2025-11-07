/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnPushFileChunkIQSerializer
//

@interface TLOnPushFileChunkIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnPushFileChunkIQ
//

@interface TLOnPushFileChunkIQ : TLBinaryPacketIQ

@property (readonly) int deviceState;
@property (readonly) int64_t receivedTimestamp;
@property (readonly) int64_t senderTimestamp;
@property (readonly) int64_t nextChunkStart;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState receivedTimestamp:(int64_t)receivedTimestamp senderTimestamp:(int64_t)senderTimestamp nextChunkStart:(int64_t)nextChunkStart;

@end

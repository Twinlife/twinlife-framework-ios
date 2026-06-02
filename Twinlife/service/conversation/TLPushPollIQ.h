/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLPollDescriptor;

//
// Interface: TLPushPollIQSerializer
//

@interface TLPushPollIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPushPollIQ
//

@interface TLPushPollIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLPollDescriptor *pollDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId pollDescriptor:(nonnull TLPollDescriptor *)pollDescriptor;

@end

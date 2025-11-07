/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLObjectDescriptor;

//
// Interface: TLPushObjectIQSerializer
//

@interface TLPushObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPushObjectIQ
//

@interface TLPushObjectIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLObjectDescriptor *objectDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_5;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_5;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId objectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor;

@end

/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLContactShareDescriptor;

//
// Interface: TLPushContactShareIQSerializer
//

@interface TLPushContactShareIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPushContactShareIQ
//

@interface TLPushContactShareIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLContactShareDescriptor *contactShareDescriptor;
@property (readonly, nonnull) NSData *avatar;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId contactShareDescriptor:(nonnull TLContactShareDescriptor *)contactShareDescriptor avatar:(nonnull NSData *)avatar;

@end

/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"
#import "TLTransientObjectDescriptorImpl.h"

//
// Interface: TLPushTransientIQSerializer
//

@interface TLPushTransientIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPushTransientIQ
//

@interface TLPushTransientIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLTransientObjectDescriptor *descriptor;
@property (readonly) int flags;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_3;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_3;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId transientObjectDescriptor:(nonnull TLTransientObjectDescriptor *)transientObjectDescriptor flags:(int)flags;

@end

//
// Interface: TLPushCommandIQ
//

@interface TLPushCommandIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

@end

//
// Interface: TLOnPushCommandIQ
//

@interface TLOnPushCommandIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

@end

/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLDescriptorId;
@class TLDescriptorAnnotation;

typedef enum {
    TLUpdateAnnotationsUpdateTypeSet,
    TLUpdateAnnotationsUpdateTypeAdd,
    TLUpdateAnnotationsUpdateTypeRemove
} TLUpdateAnnotationsUpdateType;

//
// Interface: TLUpdateAnnotationsIQSerializer
//

@interface TLUpdateAnnotationsIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateAnnotationsIQ
//

@interface TLUpdateAnnotationsIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLDescriptorId *descriptorId;
@property (readonly) TLUpdateAnnotationsUpdateType updateType;
@property (readonly, nonnull) NSMutableDictionary<NSUUID *, NSMutableArray<TLDescriptorAnnotation *> *> *annotations;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId updateType:(TLUpdateAnnotationsUpdateType)updateType annotations:(nonnull NSMutableDictionary<NSUUID *, NSMutableArray<TLDescriptorAnnotation *> *> *)annotations;

@end

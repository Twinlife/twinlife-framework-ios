/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLUpdateObjectIQSerializer
//

@interface TLUpdateObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateObjectIQ
//

@interface TLUpdateObjectIQ : TLBinaryPacketIQ

@property (readonly) int updateOptions;
@property (readonly, nonnull) NSUUID *objectId;
@property (readonly, nonnull) NSUUID *objectSchemaId;
@property (readonly) int objectSchemaVersion;
@property (readonly, nullable) NSUUID *objectKey;
@property (readonly, nonnull) NSString *objectData;
@property (readonly, nullable) NSArray<NSString *> *exclusiveContents;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId updateOptions:(int)updateOptions objectId:(nonnull NSUUID *)objectId objectSchemaId:(nonnull NSUUID *)objectSchemaId objectSchemaVersion:(int)objectSchemaVersion objectKey:(nullable NSUUID *)objectKey objectData:(nonnull NSString *)objectData exclusiveContents:(nullable NSArray<NSString *> *)exclusiveContents;

@end

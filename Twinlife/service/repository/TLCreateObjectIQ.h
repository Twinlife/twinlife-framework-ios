/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

#define CREATE_OBJECT_PRIVATE   0x01 // Object is private
#define CREATE_OBJECT_PUBLIC    0x02 // Object is public
#define CREATE_OBJECT_EXCLUSIVE 0x04 // Object has no owner, first one who gets it becomes owner
#define CREATE_OBJECT_IMMUTABLE 0x08 // Object is immutable

//
// Interface: TLCreateObjectIQSerializer
//

@interface TLCreateObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateObjectIQ
//

@interface TLCreateObjectIQ : TLBinaryPacketIQ

@property (readonly) int createOptions;
@property (readonly, nonnull) NSUUID *objectSchemaId;
@property (readonly) int objectSchemaVersion;
@property (readonly, nullable) NSUUID *objectKey;
@property (readonly, nonnull) NSString *objectData;
@property (readonly, nullable) NSArray<NSString *> *exclusiveContents;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId createOptions:(int)createOptions objectSchemaId:(nonnull NSUUID *)objectSchemaId objectSchemaVersion:(int)objectSchemaVersion objectKey:(nullable NSUUID *)objectKey objectData:(nonnull NSString *)objectData exclusiveContents:(nullable NSArray<NSString *> *)exclusiveContents;

@end

/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnGetObjectIQSerializer
//

@interface TLOnGetObjectIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnGetObjectIQ
//

@interface TLOnGetObjectIQ : TLBinaryPacketIQ

@property (readonly) int64_t creationDate;
@property (readonly) int64_t modificationDate;
@property (readonly, nonnull) NSUUID *objectSchemaId;
@property (readonly) int objectSchemaVersion;
@property (readonly) int objectFlags;
@property (readonly, nullable) NSUUID *objectKey;
@property (readonly, nonnull) NSString *objectData;
@property (readonly, nullable) NSArray<NSString *> *exclusiveContents;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId creationDate:(int64_t)creationDate modificationDate:(int64_t)modificationDate objectSchemaId:(nonnull NSUUID *)objectSchemaId objectSchemaVersion:(int)objectSchemaVersion objectFlags:(int)objectFlags objectKey:(nullable NSUUID *)objectKey objectData:(nonnull NSString *)objectData exclusiveContents:(nullable NSArray<NSString *> *)exclusiveContents;

@end

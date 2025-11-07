/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnGetObjectIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Get object response IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"5fdf06d0-513f-4858-b416-73721f2ce309",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnGetObjectIQ",
 *  "namespace":"org.twinlife.schemas.repository",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"creationDate", "type": "long"}
 *     {"name":"modificationDate", "type": "long"}
 *     {"name":"objectSchemaId", "type": "uuid"}
 *     {"name":"objectSchemaVersion", "type": "int"}
 *     {"name":"objectFlags", "type": "int"}
 *     {"name":"objectKey", "type": [null, "uuid"]}
 *     {"name":"data", "type": "string"}
 *     {"name":"exclusiveContents", [
 *      {"name":"name", "type": "string"}
 *     ]}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnGetObjectIQSerializer
//

@implementation TLOnGetObjectIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnGetObjectIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t creationDate = [decoder readLong];
    int64_t modificationDate = [decoder readLong];
    NSUUID *objectSchemaId = [decoder readUUID];
    int objectSchemaVersion = [decoder readInt];
    int objectFlags = [decoder readInt];
    NSUUID *objectKey = [decoder readOptionalUUID];
    NSString *objectData = [decoder readString];
    int count = [decoder readInt];
    NSMutableArray<NSString *> *exclusiveContents = nil;
    if (count > 0) {
        exclusiveContents = [[NSMutableArray alloc] initWithCapacity:count];
        while (count > 0) {
            count--;
            [exclusiveContents addObject:[decoder readString]];
        }
    }

    return [[TLOnGetObjectIQ alloc] initWithSerializer:self requestId:iq.requestId creationDate:creationDate modificationDate:modificationDate objectSchemaId:objectSchemaId objectSchemaVersion:objectSchemaVersion objectFlags:objectFlags objectKey:objectKey objectData:objectData exclusiveContents:exclusiveContents];
}

@end

//
// Implementation: TLOnGetObjectIQ
//

@implementation TLOnGetObjectIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId creationDate:(int64_t)creationDate modificationDate:(int64_t)modificationDate objectSchemaId:(nonnull NSUUID *)objectSchemaId objectSchemaVersion:(int)objectSchemaVersion objectFlags:(int)objectFlags objectKey:(nullable NSUUID *)objectKey objectData:(nonnull NSString *)objectData exclusiveContents:(nullable NSArray<NSString *> *)exclusiveContents {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _creationDate = creationDate;
        _modificationDate = modificationDate;
        _objectFlags = objectFlags;
        _objectSchemaId = objectSchemaId;
        _objectSchemaVersion = objectSchemaVersion;
        _objectKey = objectKey;
        _objectData = objectData;
        _exclusiveContents = exclusiveContents;
    }
    return self;
}

@end

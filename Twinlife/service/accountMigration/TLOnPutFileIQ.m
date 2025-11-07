/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnPutFileIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * File put response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"e74fea73-abc7-42ca-ad37-b636f6c4df2b",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPutFileIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"fileId", "type":"int"}
 *     {"name":"offset", "type":"long"},
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLOnPutFileIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLOnPutFileIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLOnPutFileIQ *onPutFileIQ = (TLOnPutFileIQ *)object;

    [encoder writeInt:onPutFileIQ.fileId];
    [encoder writeLong:onPutFileIQ.offset];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int fileId = [decoder readInt];
    long offset = [decoder readLong];
    
    return [[TLOnPutFileIQ alloc] initWithSerializer:self iq:iq fileId:fileId offset:offset];
}

@end

@implementation TLOnPutFileIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq fileId:(int)fileId offset:(long)offset {
    self = [super initWithSerializer:serializer iq:iq];
   
    if (self) {
        _fileId = fileId;
        _offset = offset;
    }
    
    return self;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" fileId: %d offset: %ld", self.fileId, self.offset];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLOnPutFileIQ "];
    [self appendTo:description];
    return description;
}

@end

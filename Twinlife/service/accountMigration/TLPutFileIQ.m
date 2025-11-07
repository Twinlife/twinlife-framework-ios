/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPutFileIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * File upload IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"ccc791c2-3a5c-4d83-ab06-48137a4ad262",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PutFileIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"fileId", "type":"int"},
 *     {"name":"offset", "type":"long"},
 *     {"name":"data", [null, "type":"bytes"]},
 *     {"name":"sha256", [null, "type":"bytes"]}
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLPutFileIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLPutFileIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPutFileIQ *putFileIQ = (TLPutFileIQ *)object;
    
    [encoder writeInt:putFileIQ.fileId];
    [encoder writeLong:putFileIQ.offset];
    if (putFileIQ.fileData) {
        [encoder writeEnum:1];
        [encoder writeDataWithData:putFileIQ.fileData start:putFileIQ.dataOffset length:putFileIQ.size];
    } else {
        [encoder writeEnum:0];
    }
    [encoder writeOptionalData:putFileIQ.sha256];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int fileId = [decoder readInt];
    long offset = [decoder readLong];
    NSData *fileData = nil;
    
    if ([decoder readEnum] == 1) {
        fileData = [decoder readData];
    }
    
    NSData *sha256 = [decoder readOptionalData];
    
    return [[TLPutFileIQ alloc] initWithSerializer:self iq:iq fileId:fileId offset:offset fileData:fileData sha256:sha256];
}

@end

@implementation TLPutFileIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId fileId:(int)fileId dataOffset:(int)dataOffset offset:(int64_t)offset size:(int)size fileData:(nullable NSData *)fileData sha256:(nullable NSData *)sha256 {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _fileId = fileId;
        _dataOffset = dataOffset;
        _offset = offset;
        _size = size;
        _fileData = fileData;
        _sha256 = sha256;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq fileId:(int)fileId offset:(long)offset fileData:(nullable NSData *)fileData sha256:(nullable NSData *)sha256 {
    
    self = [super initWithSerializer:serializer iq:iq];

    if (self) {
        _fileId = fileId;
        _dataOffset = 0;
        _offset = offset;
        _size = fileData ? (int) fileData.length : 0;
        _fileData = fileData;
        _sha256 = sha256;
    }
    
    return self;
}

- (long)bufferSize {
    return super.bufferSize + self.size;
}

- (nonnull NSNumber *)fileIndex {
    return [[NSNumber alloc] initWithInt:self.fileId];
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" fileId: %d offset: %lld size: %d", self.fileId, self.offset, self.size];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLPutFileIQ "];
    [self appendTo:description];
    return description;
}

@end

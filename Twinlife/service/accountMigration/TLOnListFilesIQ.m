/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnListFilesIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

#define MAX_SIZE_PER_FILE 16;

/**
 * List files IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"e74fea73-abc7-42ca-ad37-b636f6c4df2b",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ListFilesIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"count", "type":"int"},
 *     [{"name":"fileId", "type":"int"},
 *      {"name":"offset", "type":"long"}]
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLOnListFilesIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLOnListFilesIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLOnListFilesIQ *onListFilesIQ = (TLOnListFilesIQ *)object;
    
    [encoder writeInt:(int32_t)onListFilesIQ.files.count];
    for (TLFileState *file in onListFilesIQ.files) {
        [encoder writeInt:file.fileId];
        [encoder writeLong:file.offset];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSMutableArray<TLFileState *> *files = [[NSMutableArray alloc] init];
    
    int count = [decoder readInt];
    while (count > 0) {
        int fileId = [decoder readInt];
        long offset = [decoder readLong];
        
        [files addObject:[[TLFileState alloc] initWithFileId:fileId offset:offset]];
        count --;
    }
    
    return [[TLOnListFilesIQ alloc] initWithSerializer:self iq:iq files:files];
}

@end

@implementation TLOnListFilesIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId files:(NSArray *)files {
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _files = files;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq files:(NSArray *)files {
    self = [super initWithSerializer:serializer iq:iq];
   
    if (self) {
        _files = files;
    }
    
    return self;
}

- (long)bufferSize {
    return super.bufferSize + self.files.count * MAX_SIZE_PER_FILE;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" files.count: %ld", self.files.count];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLOnListFilesIQ "];
    [self appendTo:description];
    return description;
}

@end

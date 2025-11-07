/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLListFilesIQ.h"
#import "TLFileInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

#define MAX_SIZE_PER_FILE 256;

/**
 * List files IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"5964dbf0-5620-4c78-963b-c6e08665fc33",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ListFilesIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"count", "type":"int"},
 *     [{"name":"path", "type":"string"},
 *      {"name":"fileId", "type":"int"},
 *      {"name":"size", "type":"long"},
 *      {"name":"timestamp", "type":"long"}]
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLListFilesIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLListFilesIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLListFilesIQ *listFilesIQ = (TLListFilesIQ *)object;
    
    [encoder writeInt:(int32_t)listFilesIQ.files.count];
    for (TLFileInfo *file in listFilesIQ.files) {
        [encoder writeString:file.path];
        [encoder writeInt:file.fileId];
        [encoder writeLong:file.size];
        [encoder writeLong:file.date];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSMutableArray<TLFileInfo *> *files = [[NSMutableArray alloc] init];
    
    int count = [decoder readInt];
    while (count > 0) {
        NSString *path = [decoder readString];
        int fileId = [decoder readInt];
        long size = [decoder readLong];
        long date = [decoder readLong];
        
        [files addObject:[[TLFileInfo alloc] initWithFileId:fileId path:path size:size date:date]];
        count --;
    }
    
    return [[TLListFilesIQ alloc] initWithSerializer:self iq:iq files:files];
}

@end

@implementation TLListFilesIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId files:(NSArray<TLFileInfo *> *)files {
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _files = files;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq files:(NSArray<TLFileInfo *> *)files {
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
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLListFilesIQ "];
    [self appendTo:description];
    return description;
}

@end

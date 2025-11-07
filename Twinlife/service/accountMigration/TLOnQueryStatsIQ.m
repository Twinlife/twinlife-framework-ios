/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnQueryStatsIQ.h"
#import "TLFileInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Query stats response IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"0906f883-6adf-4d90-9252-9ab401fbe531",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnQueryStatsIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"directoryCount", "type":"long"},
 *     {"name":"fileCount", "type":"long"},
 *     {"name":"maxFileSize", "type":"long"},
 *     {"name":"totalFileSize", "type":"long"},
 *     {"name":"databaseFileSize", "type":"long"},
 *     {"name":"localDatabaseSpace", "type":"long"},
 *     {"name":"localFilesystemSpace", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLOnQueryStatsIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLOnQueryStatsIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLOnQueryStatsIQ *onQueryStatsIQ = (TLOnQueryStatsIQ *)object;
    
    [encoder writeLong:onQueryStatsIQ.queryInfo.directoryCount];
    [encoder writeLong:onQueryStatsIQ.queryInfo.fileCount];
    [encoder writeLong:onQueryStatsIQ.queryInfo.maxFileSize];
    [encoder writeLong:onQueryStatsIQ.queryInfo.totalFileSize];
    [encoder writeLong:onQueryStatsIQ.queryInfo.databaseFileSize];
    [encoder writeLong:onQueryStatsIQ.queryInfo.localFileAvailableSize];
    [encoder writeLong:onQueryStatsIQ.queryInfo.localDatabaseAvailableSize];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    long directoryCount = [decoder readLong];
    long fileCount = [decoder readLong];
    long maxFileSize = [decoder readLong];
    long totalFileSize = [decoder readLong];
    long databaseFileSize = [decoder readLong];
    long localFileAvailableSpace = [decoder readLong];
    long localDatabaseAvailableSpace = [decoder readLong];
    
    TLQueryInfo *queryInfo = [[TLQueryInfo alloc] initWithDirectoryCount:directoryCount fileCount:fileCount maxFileSize:maxFileSize totalFileSize:totalFileSize databaseFileSize:databaseFileSize localFileAvailableSize:localDatabaseAvailableSpace localDatabaseAvailableSize:localFileAvailableSpace];
    
    return [[TLOnQueryStatsIQ alloc] initWithSerializer:self iq:iq queryInfo:queryInfo];
}

@end

@implementation TLOnQueryStatsIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq queryInfo:(nonnull TLQueryInfo *)queryInfo {
    self = [super initWithSerializer:serializer iq:iq];
   
    if (self) {
        _queryInfo = queryInfo;
    }
    
    return self;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" %@", self.queryInfo];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLOnQueryStatsIQ "];
    [self appendTo:description];
    return description;
}

@end

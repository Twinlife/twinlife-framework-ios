/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLQueryStatsIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Query stats IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"4b201b06-7952-43a4-8157-96b9aeffa667",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"QueryStatsIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"maxFileSize", "type":"long"},
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLQueryStatsIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLQueryStatsIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLQueryStatsIQ *queryStatsIQ = (TLQueryStatsIQ *)object;
    
    [encoder writeLong:queryStatsIQ.maxFileSize];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    long maxFileSize = [decoder readLong];
    
    return [[TLQueryStatsIQ alloc] initWithSerializer:self iq:iq maxFileSize:maxFileSize];
}

@end

@implementation TLQueryStatsIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId maxFileSize:(long)maxFileSize {
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _maxFileSize = maxFileSize;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq maxFileSize:(long)maxFileSize {
    self = [super initWithSerializer:serializer iq:iq];
   
    if (self) {
        _maxFileSize = maxFileSize;
    }
    
    return self;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" maxFileSize: %ld", self.maxFileSize];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLQueryStatsIQ "];
    [self appendTo:description];
    return description;
}

@end

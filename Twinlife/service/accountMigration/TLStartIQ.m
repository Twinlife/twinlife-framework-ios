/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLStartIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Start migration IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"8a26fefe-6bd5-45e2-9098-3d736d8a1c4e",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"StartIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"maxFileSize", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLStartIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLStartIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLStartIQ *startIQ = (TLStartIQ *)object;
    
    [encoder writeLong:startIQ.maxFileSize];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    long maxFileSize = [decoder readLong];
    
    return [[TLStartIQ alloc] initWithSerializer:self iq:iq maxFileSize:maxFileSize];
}

@end

@implementation TLStartIQ

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
    [string appendFormat:@" %ld", self.maxFileSize];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLStartIQ "];
    [self appendTo:description];
    return description;
}

@end

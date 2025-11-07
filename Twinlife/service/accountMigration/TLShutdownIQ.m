/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLShutdownIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Shutdown IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"05c90756-d56c-4e2f-92bf-36b2d3f31b76",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ShutdownIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"close", "type":"boolean"}
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLShutdownIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLShutdownIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLShutdownIQ *shutdownIQ = (TLShutdownIQ *)object;
    
    [encoder writeBoolean:shutdownIQ.close];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    BOOL close = [decoder readBoolean];
    
    return [[TLShutdownIQ alloc] initWithSerializer:self requestId:iq.requestId close:close];
}

@end

@implementation TLShutdownIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId close:(BOOL)close {
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _close = close;
    }
    
    return self;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" close: %d", self.close];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLShutdownIQ "];
    [self appendTo:description];
    return description;
}

@end

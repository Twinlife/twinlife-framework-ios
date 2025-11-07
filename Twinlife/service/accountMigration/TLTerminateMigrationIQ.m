/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTerminateMigrationIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Terminate migration IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"a35089f8-326f-4f25-b160-e0f9f2c9795c",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TerminateMigrationIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"commit", "type":"boolean"},
 *     {"name":"done", "type":"boolean"},
 *  ]
 * }
 *
 * </pre>
 */

@implementation TLTerminateMigrationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLTerminateMigrationIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLTerminateMigrationIQ *terminateMigrationIQ = (TLTerminateMigrationIQ *)object;
    
    [encoder writeBoolean:terminateMigrationIQ.commit];
    [encoder writeBoolean:terminateMigrationIQ.done];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    BOOL commit = [decoder readBoolean];
    BOOL done = [decoder readBoolean];
    
    return [[TLTerminateMigrationIQ alloc] initWithSerializer:self requestId:iq.requestId commit:commit done:done];
}

@end

@implementation TLTerminateMigrationIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId commit:(BOOL)commit done:(BOOL)done {
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _commit = commit;
        _done = done;
    }
    
    return self;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" commit: %d done: %d", self.commit, self.done];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLTerminateMigrationIQ "];
    [self appendTo:description];
    return description;
}

@end

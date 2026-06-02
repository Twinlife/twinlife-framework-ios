/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSecureRosterIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Base IQ for secure roster operation. This IQ is used as is to:
 * - List members of a secure roster (schemaId "8da99a60-25e5-49f6-acc9-93c28c1d3314"),
 * - Delete a secure roster (schemaId "1ddcdf5c-c810-4b04-bbdb-4b9f14d41483")
 *
 * Schema version 1
 *  Date: 2026/03/25
 * <pre>
 * {
 *  "schemaId":"8da99a60-25e5-49f6-acc9-93c28c1d3314",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SecureRosterIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"rosterId", "type":"uuid"},
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLSecureRosterIQSerializer
//

@implementation TLSecureRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSecureRosterIQ class]];
}

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion class:(nonnull Class) clazz {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:clazz];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSecureRosterIQ *secureRosterIQ = (TLSecureRosterIQ *)object;
    [encoder writeUUID:secureRosterIQ.rosterId];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSUUID *rosterId = [decoder readUUID];

    return [[TLSecureRosterIQ alloc] initWithSerializer:self requestId:iq.requestId rosterId:rosterId];
}

@end

//
// Implementation: TLSecureRosterIQ
//

@implementation TLSecureRosterIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _rosterId = rosterId;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" rosterId=%@", self.rosterId];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLSecureRosterIQ:"];
    [self appendTo:string];
    return string;
}

@end

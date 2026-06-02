/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCreateRosterIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create a secure roster request IQ.
 *
 * Schema version 1
 *  Date: 2026/03/25
 * <pre>
 * {
 *  "schemaId":"74a4430b-9910-4fad-bba3-85c92dc99c9e",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CreateSecureRosterIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"createOptions", "type":"int"},
 *     {"name":"rosterSchemaId", "type":"uuid"},
 *     {"name":"publicKeyId", "type":"uuid"},
 *     {"name":"publicKey", "type":"bytes"},
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLCreateRosterIQSerializer
//

@implementation TLCreateRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCreateRosterIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCreateRosterIQ *createRosterIQ = (TLCreateRosterIQ *)object;
    [encoder writeInt:createRosterIQ.createOptions];
    [encoder writeUUID:createRosterIQ.rosterSchemaId];
    [encoder writeUUID:createRosterIQ.publicKeyId];
    [encoder writeData:createRosterIQ.publicKey];
}

- (NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCreateRosterIQ
//

@implementation TLCreateRosterIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId createOptions:(int)createOptions rosterSchemaId:(nonnull NSUUID *)rosterSchemaId publicKeyId:(nonnull NSUUID *)publicKeyId publicKey:(nonnull NSData *)publicKey {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _createOptions = createOptions;
        _rosterSchemaId = rosterSchemaId;
        _publicKeyId = publicKeyId;
        _publicKey = publicKey;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" rosterSchemaId=%@ createOptions=%d publicKeyId=%@", self.rosterSchemaId, self.createOptions, self.publicKeyId];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLCreateRosterIQ:"];
    [self appendTo:string];
    return string;
}

@end

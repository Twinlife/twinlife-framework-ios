/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLGetInvitationCodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Get invitation code IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"95335487-91fa-4cdc-939b-e047a068e94d",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"GetInvitationCodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"code", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */


//
// Implementation: TLGetInvitationCodeIQSerializer
//

@implementation TLGetInvitationCodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLGetInvitationCodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLGetInvitationCodeIQ *getInvitationCodeIQ = (TLGetInvitationCodeIQ *)object;
    [encoder writeString:getInvitationCodeIQ.code];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLGetInvitationCodeIQ
//

@implementation TLGetInvitationCodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId code:(nonnull NSString *)code {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _code = code;
    }
    return self;
}

@end

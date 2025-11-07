/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnCreateInvitationCodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Create invitation code response IQ.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"93cf2a0c-82cb-43ea-98c6-43563807fadf",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnCreateInvitationCodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"id", "type":"uuid"}
 *     {"name":"creationDate", "type":"long"}
 *     {"name":"validityPeriod", "type":"int"}
 *     {"name":"code", "type":"string"}
 *     {"name":"twincodeId", "type":"uuid"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnCreateInvitationCodeIQSerializer
//

@implementation TLOnCreateInvitationCodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnCreateInvitationCodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSUUID *codeId = [decoder readUUID];
    int64_t creationDate = [decoder readLong];
    int validityPeriod = [decoder readInt];
    NSString *code = [decoder readString];
    NSUUID *twincodeId = [decoder readUUID];
    
    return [[TLOnCreateInvitationCodeIQ alloc] initWithSerializer:self requestId:iq.requestId codeId:codeId creationDate:creationDate validityPeriod:validityPeriod code:code twincodeId:twincodeId];
}

@end

//
// Implementation: TLOnCreateInvitationCodeIQ
//

@implementation TLOnCreateInvitationCodeIQ


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId codeId:(nonnull NSUUID *)codeId creationDate:(int64_t)creationDate validityPeriod:(int)validityPeriod code:(nullable NSString *)code twincodeId:(nonnull NSUUID *)twincodeId {
    
    self = [super initWithSerializer:serializer requestId:requestId];

    if (self) {
        _codeId = codeId;
        _creationDate = creationDate;
        _validityPeriod = validityPeriod;
        _code = code;
        _twincodeId = twincodeId;
    }
    
    return self;
}

@end

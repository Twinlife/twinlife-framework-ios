/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Update twincode IQ.
 * <p>
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"8efcb2a1-6607-4b06-964c-ec65ed459ffc",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"UpdateTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeId", "type":"uuid"},
 *     {"name":"attributes", [
 *      {"name":"name", "type": "string"}
 *      {"name":"type", ["long", "string", "uuid"]}
 *      {"name":"value", "type": ["long", "string", "uuid"]}
 *     ]}
 *     {"name":"deleteAttributes", [
 *       {"name":"name", "type": "string"}
 *     ]},
 *     {"name": "signature": [null, "type":"bytes"]}
 *   ]
 * }
 * </pre>
 * Schema version 1 (REMOVED 2024-02-02 after 22.x)
 */

//
// Implementation: TLUpdateTwincodeIQSerializer
//

@implementation TLUpdateTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateTwincodeIQ *updateTwincodeIQ = (TLUpdateTwincodeIQ *)object;
    [encoder writeUUID:updateTwincodeIQ.twincodeId];
    [self serializeWithEncoder:encoder attributes:updateTwincodeIQ.attributes];
    if (!updateTwincodeIQ.deleteAttributeNames) {
        [encoder writeInt:0];
    } else {
        [encoder writeInt:(int)updateTwincodeIQ.deleteAttributeNames.count];
        for (NSUUID *twincodeId in updateTwincodeIQ.deleteAttributeNames) {
            [encoder writeUUID:twincodeId];
        }
    }
    [encoder writeOptionalData:updateTwincodeIQ.signature];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLUpdateTwincodeIQ
//

@implementation TLUpdateTwincodeIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames signature:(nullable NSData *)signature {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _twincodeId = twincodeId;
        _attributes = attributes;
        _deleteAttributeNames = deleteAttributeNames;
        _signature = signature;
    }
    return self;
}

@end

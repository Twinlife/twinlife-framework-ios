/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnGetAllTwincodesIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLTwincodeInfo.h"

/**
 * Contains all the currently active twincodes owned by the account, grouped by schemaId.
 * Used by the app to synchronize twincodeOutbounds during a backup restore.
 * <p>
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"ca422038-7ae9-4dd3-829d-f8107b817f9a",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnGetAllTwincodesIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeIds", [
 *         {"name":"schemaId", "type": "uuid", [
 *          "name": "twincodeOutboundId", "type": "uuid",
 *          "name": "twincodeFactoryId", "type": "uuid",
 *          "name": "twincodeInboundId", "type": "uuid"
 *          ]}
 *      ]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnGetInvitationCodeIQSerializer
//

@implementation TLOnGetAllTwincodesIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnGetAllTwincodesIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    NSMutableDictionary<NSUUID *, NSArray<TLTwincodeInfo *> *> * twincodeIdsBySchema = [NSMutableDictionary dictionary];
    
    int nbSchemas = [decoder readInt];
    
    for (int i=0; i < nbSchemas; i++) {
        NSMutableArray<TLTwincodeInfo *> *twincodeInfos = [NSMutableArray array];
        
        NSUUID *schemaId = [decoder readUUID];
        int nbTwincodeIds = [decoder readInt];
        for (int j = 0; j < nbTwincodeIds; j++) {
            NSUUID *twincodeFactoryId = [decoder readUUID];
            NSUUID *twincodeOutboundId = [decoder readUUID];
            NSUUID *twincodeInboundId = [decoder readUUID];
            
            [twincodeInfos addObject:[[TLTwincodeInfo alloc] initWithTwincodeFactoryId:twincodeFactoryId twincodeOutboundId:twincodeOutboundId twincodeInboundId:twincodeInboundId]];
        }
        twincodeIdsBySchema[schemaId] = twincodeInfos;
    }
    
    return [[TLOnGetAllTwincodesIQ alloc] initWithSerializer:self iq:iq twincodeIdsBySchema:twincodeIdsBySchema];
}

@end

//
// Implementation: TLOnGetAllTwincodesIQ
//

@implementation TLOnGetAllTwincodesIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq twincodeIdsBySchema:(nonnull NSDictionary<NSUUID *,NSArray<TLTwincodeInfo *> *> *)twincodeIdsBySchema {
    
    self = [super initWithSerializer:serializer iq:iq];

    if (self) {
        _twincodeIdsBySchema = twincodeIdsBySchema;
    }
    
    return self;
}

@end

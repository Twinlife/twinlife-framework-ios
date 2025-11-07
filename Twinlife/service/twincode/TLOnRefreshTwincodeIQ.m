/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnRefreshTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Refresh twincode response IQ.
 * <p>
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"2dc1c0bc-f4a1-4904-ac55-680ce11e43f8",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnRefreshTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"refreshTimestamp", "type":"long"},
 *     {"name":"deleteTwincodes", [
 *      {"name":"twincode", "type": "uuid"}
 *     ]},
 *     {"name":"updateTwincodes", [
 *      {"name":"twincode", "type": "uuid"}
 *      {"name":"attributeCount", "type":"int"},
 *      {"name":"attributes", [
 *        {"name":"name", "type": "string"}
 *        {"name":"type", ["long", "string", "uuid"]}
 *        {"name":"value", "type": ["long", "string", "uuid"]}
 *      ]}
 *      {"name": "signature": [null, "type":"bytes"]}
 *    ]}
 * }
 * </pre>
 * Schema version 1 (REMOVED 2024-02-02 after 22.x)
 */

//
// Implementation: TLRefreshTwincodeInfo
//

@implementation TLRefreshTwincodeInfo

- (nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nullable NSData *)signature {
    
    self = [super init];
    if (self) {
        _twincodeOutboundId = twincodeId;
        _attributes = attributes;
        _signature = signature;
    }
    return self;
}

@end

//
// Implementation: TLOnRefreshTwincodeIQSerializer
//

@implementation TLOnRefreshTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnRefreshTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t timestamp = [decoder readLong];
    int deleteCount = [decoder readInt];
    NSMutableArray<NSUUID *> *deleteTwincodeList = nil;
    if (deleteCount > 0) {
        deleteTwincodeList = [[NSMutableArray alloc] initWithCapacity:deleteCount];
        while (deleteCount > 0) {
            [deleteTwincodeList addObject:[decoder readUUID]];
            deleteCount--;
        }
    }
    int updateCount = [decoder readInt];
    NSMutableArray<TLRefreshTwincodeInfo *> *updateTwincodeList;
    if (updateCount > 0) {
        updateTwincodeList = [[NSMutableArray alloc] initWithCapacity:updateCount];
        while (updateCount > 0) {
            NSUUID *twincodeId = [decoder readUUID];
            NSArray<TLAttributeNameValue *> *attributes = [self deserializeWithDecoder:decoder];
            NSData *signature = [decoder readOptionalData];
            [updateTwincodeList addObject:[[TLRefreshTwincodeInfo alloc] initWithTwincodeId:twincodeId attributes:attributes signature:signature]];
            updateCount--;
        }
    }

    return [[TLOnRefreshTwincodeIQ alloc] initWithSerializer:self iq:iq timestamp:timestamp updateTwincodeList:updateTwincodeList deleteTwincodeList:deleteTwincodeList];
}

@end

//
// Implementation: TLOnRefreshTwincodeIQ
//

@implementation TLOnRefreshTwincodeIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq timestamp:(int64_t)timestamp updateTwincodeList:(nullable NSMutableArray<TLRefreshTwincodeInfo *> *)updateTwincodeList deleteTwincodeList:(nullable NSArray<NSUUID *> *)deleteTwincodeList {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _timestamp = timestamp;
        _updateTwincodeList = updateTwincodeList;
        _deleteTwincodeList = deleteTwincodeList;
    }
    return self;
}

@end

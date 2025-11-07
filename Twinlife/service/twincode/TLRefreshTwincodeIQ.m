/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLRefreshTwincodeIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Refresh twincode IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"e8028e21-e657-4240-b71a-21ea1367ebf2",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"RefreshTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.image",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"timestamp", "type":"long"},
 *     {"name":"twincodes", [
 *      {"name":"twincode", "type": "uuid"}
 *     ]}
 *   ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLRefreshTwincodeIQSerializer
//

@implementation TLRefreshTwincodeIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLRefreshTwincodeIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLRefreshTwincodeIQ *refreshTwincodeIQ = (TLRefreshTwincodeIQ *)object;
    [encoder writeLong:refreshTwincodeIQ.timestamp];
    [encoder writeInt:(int)refreshTwincodeIQ.twincodeList.count];
    for (NSUUID *twincodeId in refreshTwincodeIQ.twincodeList) {
        [encoder writeUUID:twincodeId];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLRefreshTwincodeIQ
//

@implementation TLRefreshTwincodeIQ

- (instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId timestamp:(int64_t)timestamp twincodeList:(nonnull NSDictionary<NSUUID *, NSNumber *> *)twincodeList {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _timestamp = timestamp;
        _twincodeList = twincodeList;
    }
    return self;
}

@end

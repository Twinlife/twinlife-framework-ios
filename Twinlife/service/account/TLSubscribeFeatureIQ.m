/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSubscribeFeatureIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Subscribe Feature Request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"eb420020-e55a-44b0-9e9e-9922ec055407",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SubscribeFeatureIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"merchantId", "type":"enum"},
 *     {"name":"purchaseProductId", "type":"string"},
 *     {"name":"purchaseToken", "type":"string"},
 *     {"name":"purchaseOrderId", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSubscribeFeatureIQSerializer
//

@implementation TLSubscribeFeatureIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSubscribeFeatureIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSubscribeFeatureIQ *subscribeFeatureIQ = (TLSubscribeFeatureIQ *)object;
    switch (subscribeFeatureIQ.merchantId) {
        case TLMerchantIdentificationTypeApple:
            [encoder writeEnum:1];
            break;

        case TLMerchantIdentificationTypeExternal:
            [encoder writeEnum:2];
            break;

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
    [encoder writeString:subscribeFeatureIQ.purchaseProductId];
    [encoder writeString:subscribeFeatureIQ.purchaseToken];
    [encoder writeString:subscribeFeatureIQ.purchaseOrderId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLSubscribeFeatureIQ
//

@implementation TLSubscribeFeatureIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  merchantId:(TLMerchantIdentificationType)merchantId purchaseProductId:(nonnull NSString *)purchaseProductId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _merchantId = merchantId;
        _purchaseProductId = purchaseProductId;
        _purchaseToken = purchaseToken;
        _purchaseOrderId = purchaseOrderId;
    }
    return self;
}

@end

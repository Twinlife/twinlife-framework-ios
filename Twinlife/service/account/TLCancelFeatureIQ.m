/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCancelFeatureIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Cancel Feature Request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"0B20EF35-A5D9-45F2-9B97-C6B3D15983FA",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CancelFeatureIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"merchantId", "type":"enum"},
 *     {"name":"purchaseToken", "type":"string"},
 *     {"name":"purchaseOrderId", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLCancelFeatureIQSerializer
//

@implementation TLCancelFeatureIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLCancelFeatureIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCancelFeatureIQ *subscribeFeatureIQ = (TLCancelFeatureIQ *)object;
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
    [encoder writeString:subscribeFeatureIQ.purchaseToken];
    [encoder writeString:subscribeFeatureIQ.purchaseOrderId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLCancelFeatureIQ
//

@implementation TLCancelFeatureIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  merchantId:(TLMerchantIdentificationType)merchantId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _merchantId = merchantId;
        _purchaseToken = purchaseToken;
        _purchaseOrderId = purchaseOrderId;
    }
    return self;
}

@end

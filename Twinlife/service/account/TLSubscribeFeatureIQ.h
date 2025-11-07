/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"
#import "TLAccountService.h"

//
// Interface: TLSubscribeFeatureIQSerializer
//

@interface TLSubscribeFeatureIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSubscribeFeatureIQ
//

@interface TLSubscribeFeatureIQ : TLBinaryPacketIQ

@property (readonly) TLMerchantIdentificationType merchantId;
@property (readonly, nonnull) NSString *purchaseProductId;
@property (readonly, nonnull) NSString *purchaseToken;
@property (readonly, nonnull) NSString *purchaseOrderId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  merchantId:(TLMerchantIdentificationType)merchantId purchaseProductId:(nonnull NSString *)purchaseProductId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId;

@end

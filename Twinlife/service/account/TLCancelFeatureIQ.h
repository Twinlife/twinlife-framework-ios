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
// Interface: TLCancelFeatureIQSerializer
//

@interface TLCancelFeatureIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCancelFeatureIQ
//

@interface TLCancelFeatureIQ : TLBinaryPacketIQ

@property (readonly) TLMerchantIdentificationType merchantId;
@property (readonly, nonnull) NSString *purchaseToken;
@property (readonly, nonnull) NSString *purchaseOrderId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  merchantId:(TLMerchantIdentificationType)merchantId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId;

@end

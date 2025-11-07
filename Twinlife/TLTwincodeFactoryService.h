/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"
#import "TLTwincode.h"

@class TLTwincodeInbound;
@class TLTwincodeOutbound;

//
// Interface: TLTwincodeFactory
//

@interface TLTwincodeFactory : TLTwincode

@property (nonnull, readonly) TLTwincodeInbound *twincodeInbound;
@property (nonnull, readonly) TLTwincodeOutbound *twincodeOutbound;
@property (nonnull, readonly) NSUUID *twincodeSwitchId;

@end

//
// Interface: TLTwincodeFactoryServiceConfiguration
//


@interface TLTwincodeFactoryServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Interface: TLTwincodeFactoryService
//

@class TLAttributeNameValue;

@interface TLTwincodeFactoryService : TLBaseService

+ (nonnull NSString *)VERSION;

/// Create a set of twincodes with the factory, inbound, outbound, switch.
/// Bind the inbound twincode to the device.  Each twincode is configured with its own attributes.
- (void)createTwincodeWithFactoryAttributes:(nonnull NSArray<TLAttributeNameValue *> *)factoryAttributes inboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)inboundAttributes outboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)outboundAttributes switchAttributes:(nullable NSArray<TLAttributeNameValue *> *)switchAttributes twincodeSchemaId:(nonnull NSUUID *)twincodeSchemaId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeFactory *_Nullable twincodeFactory))block;

/// Delete the twincode factory and the associated inbound, outbound and switch twincodes.
- (void)deleteTwincodeWithFactoryId:(nonnull NSUUID *)factoryId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable twincodeFactoryId))block;

@end

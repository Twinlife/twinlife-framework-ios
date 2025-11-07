/*
 *  Copyright (c) 2014-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwincodeFactoryService.h"
#import "TLBaseServiceImpl.h"
#import "TLTwincodeImpl.h"

//
// Interface: TLFactoryPendingRequest
//

@interface TLFactoryPendingRequest : NSObject

@end

//
// Interface: TLCreateFactoryPendingRequest ()
//

typedef void (^TLCreateTwincodeFactoryComplete) (TLBaseServiceErrorCode status, TLTwincodeFactory * _Nullable twincodeFactory);

@interface TLCreateFactoryPendingRequest : TLFactoryPendingRequest

@property (readonly, nonnull) NSMutableArray<TLAttributeNameValue *> *factoryAttributes;
@property (readonly, nullable) NSArray<TLAttributeNameValue *> *inboundAttributes;
@property (readonly, nullable) NSArray<TLAttributeNameValue *> *outboundAttributes;
@property (readonly, nonnull) TLCreateTwincodeFactoryComplete complete;

-(nonnull instancetype)initWithFactoryAttributes:(nonnull NSArray<TLAttributeNameValue *> *)factoryAttributes inboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)inboundAttributes outboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)outboundAttributes complete:(nonnull TLCreateTwincodeFactoryComplete)complete;

@end

//
// Interface: TLDeleteFactoryPendingRequest ()
//

typedef void (^TLDeleteTwincodeFactoryComplete) (TLBaseServiceErrorCode status, NSUUID * _Nullable factoryId);

@interface TLDeleteFactoryPendingRequest : TLFactoryPendingRequest

@property (readonly, nonnull) NSUUID *factoryId;
@property (readonly, nonnull) TLDeleteTwincodeFactoryComplete complete;

-(nonnull instancetype)initWithFactoryId:(nonnull NSUUID *)factoryId complete:(nonnull TLDeleteTwincodeFactoryComplete)complete;

@end

//
// Interface: TLTwincodeFactory ()
//

@interface TLTwincodeFactory ()

- (nonnull instancetype)initWithUUID:(nonnull NSUUID *)uuid modificationDate:(int64_t)modificationDate twincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeSwitchId:(nonnull NSUUID *)twincodeSwitchId attributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes;

@end

//
// Interface: TLTwincodeFactoryService ()
//

@interface TLTwincodeFactoryService ()

+ (void)initialize;

@end

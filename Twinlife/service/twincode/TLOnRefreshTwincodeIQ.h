/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLAttributeNameValue;

//
// Interface: TLRefreshTwincodeInfo
//

@interface TLRefreshTwincodeInfo : NSObject

@property (readonly, nonnull) NSUUID *twincodeOutboundId;
@property (readonly, nonnull) NSArray<TLAttributeNameValue *> *attributes;
@property (readonly, nullable) NSData *signature;

- (nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nullable NSData *)signature;

@end

//
// Interface: TLOnRefreshTwincodeIQSerializer
//

@interface TLOnRefreshTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnRefreshTwincodeIQ
//

@interface TLOnRefreshTwincodeIQ : TLBinaryPacketIQ

@property (readonly) int64_t timestamp;
@property (readonly, nullable) NSMutableArray<TLRefreshTwincodeInfo *> *updateTwincodeList;
@property (readonly, nullable) NSArray<NSUUID *> *deleteTwincodeList;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq timestamp:(int64_t)timestamp updateTwincodeList:(nullable NSMutableArray<TLRefreshTwincodeInfo *> *)updateTwincodeList deleteTwincodeList:(nullable NSArray<NSUUID *> *)deleteTwincodeList;

@end

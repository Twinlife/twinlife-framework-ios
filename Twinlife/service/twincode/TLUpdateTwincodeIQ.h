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
// Interface: TLUpdateTwincodeIQSerializer
//

@interface TLUpdateTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdateTwincodeIQ
//

@interface TLUpdateTwincodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nonnull) NSArray<TLAttributeNameValue *> *attributes;
@property (readonly, nullable) NSArray<NSString *> *deleteAttributeNames;
@property (readonly, nullable) NSData *signature;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames signature:(nullable NSData *)signature;

@end

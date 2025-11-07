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
// Interface: TLOnGetTwincodeIQSerializer
//

@interface TLOnGetTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnGetTwincodeIQ
//

@interface TLOnGetTwincodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSArray<TLAttributeNameValue *> *attributes;
@property (readonly) int64_t modificationDate;
@property (readonly, nullable) NSData *signature;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq modificationDate:(int64_t)modificationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nullable NSData *)signature;

@end

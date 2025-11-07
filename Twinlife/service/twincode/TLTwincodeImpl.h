/*
 *  Copyright (c) 2015-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwincode.h"

//
// Interface: TLTwincodePendingRequest
//

@interface TLTwincodePendingRequest : NSObject

@end

//
// TLTwincode
//

@interface TLTwincode ()

@property int64_t modificationDate;
@property (nullable) NSMutableArray<TLAttributeNameValue *> *attributes;

- (nonnull instancetype)initWithUUID:(nonnull NSUUID *)twincodeId modificationDate:(int64_t)modificationDate attributes:(nullable NSMutableArray<TLAttributeNameValue *> *)attributes;

- (BOOL)isEqual:(nullable id)object;

- (NSUInteger)hash;

@end

//
// TLTwincodeImpl
//

@class TLAttributeNameValue;

@interface TLTwincodeImpl : NSObject

@property (nonnull, readonly) NSUUID *uuid;
@property (readonly) int64_t modificationDate;
@property (nonnull, readonly) NSArray<TLAttributeNameValue *> *attributes;

- (nonnull instancetype)initWithUUID:(nonnull NSUUID *)uuid modificationDate:(int64_t)modificationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes;

- (nullable id)getAttributeWithName:(nonnull NSString *)name;

- (BOOL)hasAttributeWithName:(nonnull NSString *)name;

@end


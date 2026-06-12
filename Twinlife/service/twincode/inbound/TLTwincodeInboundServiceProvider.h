/*
 *  Copyright (c) 2015-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#include "TLDatabaseServiceProvider.h"

@class TLTwincodeInboundService;
@class TLTwincodeInfo;

//
// Interface: TLTwincodeInboundServiceProvider
//

@interface TLTwincodeInboundServiceProvider : TLDatabaseServiceProvider <TLTwincodeObjectFactory>

- (nonnull instancetype)initWithService:(nonnull TLTwincodeInboundService *)service database:(nonnull TLDatabaseService *)database;

- (nullable TLTwincodeInbound *)loadTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeInboundId;

- (nullable TLTwincodeInbound *)loadTwincodeWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (nullable TLTwincodeInbound *)importTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (nonnull NSArray<TLTwincodeInbound *> *)loadTwincodes;

- (nullable TLTwincodeInbound *)restoreTwincodeWithDatabaseId:(int64_t)databaseId twincodeId:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nonnull NSUUID *)twincodeFactoryId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (nullable NSArray<TLTwincodeInfo *> *)syncWithTwincodes:(nonnull NSDictionary<NSUUID *, NSArray<TLTwincodeInfo *> *> *)serverTwincodes;

@end

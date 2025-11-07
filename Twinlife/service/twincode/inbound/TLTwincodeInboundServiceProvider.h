/*
 *  Copyright (c) 2015-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#include "TLDatabaseServiceProvider.h"

@class TLTwincodeInboundService;

//
// Interface: TLTwincodeInboundServiceProvider
//

@interface TLTwincodeInboundServiceProvider : TLDatabaseServiceProvider <TLTwincodeObjectFactory>

- (nonnull instancetype)initWithService:(nonnull TLTwincodeInboundService *)service database:(nonnull TLDatabaseService *)database;

- (nullable TLTwincodeInbound *)loadTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeInboundId;

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (nullable TLTwincodeInbound *)importTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

@end

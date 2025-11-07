/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDatabaseServiceProvider.h"
#import "TLTwincode.h"

@class TLTwincodeOutboundService;
@class TLCryptoService;

//
// Interface: TLTwincodeRefreshInfo
//

@interface TLTwincodeRefreshInfo : NSObject

@property (readonly, nonnull) NSMutableDictionary<NSUUID *, NSNumber *> *twincodes;
@property (readonly) int64_t timestamp;

- (nonnull instancetype)initWithTwincodes:(nonnull NSMutableDictionary<NSUUID *, NSNumber *> *)twincodes timestamp:(int64_t)timestamp;

@end

//
// Interface: TLTwincodeOutboundServiceProvider
//

@interface TLTwincodeOutboundServiceProvider : TLDatabaseServiceProvider <TLTwincodeObjectFactory, TLTwincodesCleaner>

- (nonnull instancetype)initWithService:(nonnull TLTwincodeOutboundService *)service database:(nonnull TLDatabaseService *)database;

- (nullable TLTwincodeOutbound *)loadTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeId;

/// Update an existing twincode in the database.  The twincode instance is updated with the
/// given attributes and saved in the database.
- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate isSigned:(BOOL)isSigned;

/// Import a possibly new twincode from the server in the database.  The twincode is associated with the refresh
/// timestamp and period.  The refresh update is scheduled to be the current date + refresh period.
- (nullable TLTwincodeOutbound *)importTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes pubSigningKey:(nullable NSData *)pubSigningKey pubEncryptionKey:(nullable NSData *)pubEncryptionKey keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey trustMethod:(TLTrustMethod)trustMethod modificationDate:(int64_t)modificationDate  refreshPeriod:(int64_t)refreshPeriod;

- (nullable TLTwincodeOutbound *)refreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes previousAttributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)previousAttributes modificationDate:(int64_t)modificationDate;

/// Refresh the twincode in the database when it was changed on the server.  The twincode is associated with the refresh
/// timestamp and period.  The refresh update is scheduled to be the current date + refresh period.
- (nullable TLTwincodeOutbound *)refreshTwincodeWithTwincodeId:(long)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes previousAttributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)previousAttributes modificationDate:(int64_t)modificationDate;

/// Get the next deadline date to refresh the twincodes.
- (int64_t)getRefreshDeadline;

/// Get a list of twincodes that must be refreshed.
- (nullable TLTwincodeRefreshInfo *)getRefreshListWithMaxCount:(int)maxCount;

/// Update the twincode refresh information and setup a new refresh date based on the currentDate and the twincode refresh period.
- (void)updateRefreshTimestampWithList:(nonnull NSArray<NSNumber *> *)list refreshTimestamp:(int64_t)refreshTimestamp currentDate:(int64_t)currentDate;

/// Remove the twincode from the database if there is no reference to it from a Conversation and Repository.
/// The image associated with the twincode is also evicted.
- (void)evictTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId;

/// Delete the twincode
- (void)deleteTwincode:(nonnull NSNumber *)databaseId;

/// Create a private key for the { twincodeInbound, twincodeOutbound } by using the crypto service.
- (void)createPrivateKeyWithCryptoService:(nonnull TLCryptoService *)cryptoService twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound;

- (void)associateTwincodes:(nonnull TLTwincodeOutbound *)twincodeOutbound previousPeerTwincode:(nullable TLTwincodeOutbound *)previousPeerTwincode peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode;

- (void)setCertifiedWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode trustMethod:(TLTrustMethod)trustMethod;

@end

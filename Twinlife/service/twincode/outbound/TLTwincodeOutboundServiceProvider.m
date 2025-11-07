/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLAttributeNameValue.h"
#import "TLTwincodeOutboundServiceProvider.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLDataInputStream.h"
#import "TLImageId.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define LOG_TAG @"TwincodeOutboundServiceProvider"

#define TWINCODE_OUTBOUND_SERVICE_PROVIDER_SCHEMA_ID @"20b764ab-7069-4c28-8cab-8c2926d7334a"

/**
 * twincodeOutbound table:
 * id INTEGER: local database identifier (primary key)
 * twincodeId TEXT UNIQUE NOT NULL: twincode outbound id
 * creationDate INTEGER: twincode creation date
 * modificationDate INTEGER: twincode modification date
 * name TEXT: name attribute
 * avatarId INTEGER: avatar id attribute
 * capabilities TEXT: capabilities attribute
 * description TEXT: description attribute
 * attributes BLOB: other attributes (serialized)
 * refreshPeriod INTEGER: period in ms to refresh the twincode information
 * refreshDate INTEGER: deadline date for the next refresh for the twincode information
 * refreshTimestamp INTEGER: server timestamp from a previous/past refresh
 * flags INTEGER NOT NULL: various control flags
 *
 * Note: id, twincodeId, creationDate are readonly.
 */
#define TWINCODE_OUTBOUND_CREATE_TABLE \
        @"CREATE TABLE IF NOT EXISTS twincodeOutbound (id INTEGER PRIMARY KEY," \
        " twincodeId TEXT UNIQUE NOT NULL, creationDate INTEGER NOT NULL DEFAULT 0,"\
        " modificationDate INTEGER NOT NULL DEFAULT 0," \
        " name TEXT, avatarId INTEGER, capabilities TEXT, description TEXT, attributes BLOB," \
        " refreshPeriod INTEGER DEFAULT 3600000, refreshDate INTEGER DEFAULT 0," \
        " refreshTimestamp INTEGER, flags INTEGER NOT NULL" \
        ")"
#define TWINCODE_OUTBOUND_DROP_TABLE                  @"DROP TABLE IF EXISTS twincodeOutboundTwincodeOutbound;"

#define ALTER_TWINCODE_OUTBOUND_ADD_REFRESH_PERIOD    @"ALTER TABLE twincodeOutboundTwincodeOutbound ADD COLUMN refreshPeriod INTEGER DEFAULT 3600000"
#define ALTER_TWINCODE_OUTBOUND_ADD_REFRESH_DATE      @"ALTER TABLE twincodeOutboundTwincodeOutbound ADD COLUMN refreshDate INTEGER DEFAULT 0"
#define ALTER_TWINCODE_OUTBOUND_ADD_REFRESH_TIMESTAMP @"ALTER TABLE twincodeOutboundTwincodeOutbound ADD COLUMN refreshTimestamp INTEGER"

//
// Interface: TLTwincodeRefreshInfo
//

@implementation TLTwincodeRefreshInfo

- (nonnull instancetype)initWithTwincodes:(nonnull NSMutableDictionary<NSUUID *, NSNumber *> *)twincodes timestamp:(int64_t)timestamp {
    
    self = [super init];
    if (self) {
        _twincodes = twincodes;
        _timestamp = timestamp;
    }
    return self;
}

@end

//
// Implementation: TLTwincodeOutboundServiceProvider
//

@implementation TLTwincodeOutboundServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLTwincodeOutboundService *)service database:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@ initWithService: %@ database: %@", LOG_TAG, service, database);
    
    self = [super initWithService:service database:database sqlCreate:TWINCODE_OUTBOUND_CREATE_TABLE table:TLDatabaseTableTwincodeOutbound];
    if (self) {
        self.database.twincodeOutboundFactory = self;
    }
    return self;
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);
    
    /*
     * <pre>
     * Database Version 20
     *  Date: 2023/08/29
     *   New database model with twincodeOutbound table and change of primary key
     *
     * Database Version 9
     *  Date: 2020/05/25
     *
     *  TwincodeOutboundService
     *   Update oldVersion [3,8]:
     *    Add column refreshPeriod INTEGER in  twincodeOutboundTwincodeOutbound
     *    Add column refreshDate INTEGER in  twincodeOutboundTwincodeOutbound
     *    Add column refreshTimestamp INTEGER in  twincodeOutboundTwincodeOutbound
     *   Update oldVersion [0,1]: reset
     *
     * Database Version 6
     *  Date: 2017/04/27
     *
     *  TwincodeOutboundService
     *   Upgrade oldVersion [2,5]: -
     *   Upgrade oldVersion [0,1]: reset
     *
     * Database Version 5
     *  Date: 2017/04/20
     *
     *  TwincodeOutboundService
     *   Upgrade oldVersion [2,4]: -
     *   Upgrade oldVersion [0,1]: reset
     *
     * Database Version 4
     *  Date: 2016/10/13
     *
     *  TwincodeOutboundService
     *   Upgrade oldVersion [2,3]: -
     *   Upgrade oldVersion [0,1]: reset
     *
     * Database Version 3
     *  Date: 2015/11/28
     *
     *  TwincodeOutboundService
     *   Upgrade oldVersion == 2: -
     *   Upgrade oldVersion <= 1: reset
     *
     * </pre>
     */
    
    if (oldVersion >= 2 && oldVersion <= 9) {
        [transaction executeUpdate:ALTER_TWINCODE_OUTBOUND_ADD_REFRESH_PERIOD];
        [transaction executeUpdate:ALTER_TWINCODE_OUTBOUND_ADD_REFRESH_DATE];
        [transaction executeUpdate:ALTER_TWINCODE_OUTBOUND_ADD_REFRESH_TIMESTAMP];
    }
    
    [super onUpgradeWithTransaction:transaction oldVersion:oldVersion newVersion:newVersion];
    
    if (oldVersion < 20 && [transaction hasTableWithName:@"twincodeOutboundTwincodeOutbound"]) {
        [self upgrade20WithTransaction:transaction];
    }
}

- (int)onResumeWithDatabase:(nonnull FMDatabase *)database lastSuspendDate:(int64_t)lastSuspendDate {
    DDLogVerbose(@"%@ onResumeWithDatabase: %@ lastSuspendDate: %lld", LOG_TAG, database, lastSuspendDate);

    TL_DECL_START_MEASURE(startTime)

    // Reload the twincodes that have been modified by the NotificationServiceExtension.
    int count = 0;
    FMResultSet *resultSet = [database executeQuery:@"SELECT"
                                      " twout.id, twout.twincodeId, twout.modificationDate, twout.name,"
                                      " twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags"
                                      " FROM twincodeOutbound AS twout"
                              " WHERE twout.modificationDate > ?", [NSNumber numberWithLongLong:lastSuspendDate]];
    if (!resultSet) {
        [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
        return 0;
    }
    while ([resultSet next]) {
        if ([self.database loadTwincodeOutboundWithResultSet:resultSet offset:0]) {
            count++;
        }
    }
    [resultSet close];
    TL_END_MEASURE(startTime, @"TwincodeOutbound resume")
    return count;
}

#pragma mark - TLDatabaseObjectFactory

- (nullable id<TLDatabaseObject>)createObjectWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ createObjectWithIdentifier: %@ offset: %d", LOG_TAG, identifier, offset);
    
    // to.twincodeId, to.modificationDate, to.name, to.avatarId, to.description, to.capabilities, to.attributes
    NSUUID *twincodeId = [cursor uuidForColumnIndex:offset];
    int64_t modificationDate = [cursor longLongIntForColumnIndex:offset + 1];
    NSString *name = [cursor stringForColumnIndex:offset + 2];
    int64_t avatarId = [cursor longLongIntForColumnIndex:offset + 3];
    NSString *description = [cursor stringForColumnIndex:offset + 4];
    NSString *capabilities = [cursor stringForColumnIndex:offset + 5];
    NSData *content = [cursor dataForColumnIndex:offset + 6];
    int flags = [cursor intForColumnIndex:offset + 7];
    return [[TLTwincodeOutbound alloc] initWithIdentifier:identifier twincodeId:twincodeId name:name description:description avatarId:avatarId != 0 ? [[TLImageId alloc] initWithLocalId:avatarId] : nil capabilities:capabilities content:content modificationDate:modificationDate flags:flags];
}

- (BOOL)loadWithObject:(nonnull id<TLDatabaseObject>)object cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ loadWithObject: %@ offset: %d", LOG_TAG, object, offset);
    
    TLTwincodeOutbound *twincodeOutbound = (TLTwincodeOutbound *)object;
    int64_t modificationDate = [cursor longLongIntForColumnIndex:offset + 1];
    if (twincodeOutbound.modificationDate == modificationDate) {
        return NO;
    }
    NSString *name = [cursor stringForColumnIndex:offset + 2];
    int64_t avatarId = [cursor longLongIntForColumnIndex:offset + 3];
    NSString *description = [cursor stringForColumnIndex:offset + 4];
    NSString *capabilities = [cursor stringForColumnIndex:offset + 5];
    NSData *content = [cursor dataForColumnIndex:offset + 6];
    int flags = [cursor intForColumnIndex:offset + 7];
    [twincodeOutbound updateWithName:name description:description avatarId:avatarId != 0 ? [[TLImageId alloc] initWithLocalId:avatarId] : nil capabilities:capabilities content:content modificationDate:modificationDate flags:flags];
    return YES;
}

- (nonnull id<TLDatabaseObject>)storeObjectWithTransaction:(nonnull TLTransaction *)transaction identifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:()attributes flags:(int)flags modificationDate:(int64_t)modificationDate refreshPeriod:(int64_t)refreshPeriod refreshDate:(int64_t)refreshDate refreshTimestamp:(int64_t)refreshTimestamp initialize:(nonnull void (^)(id<TLDatabaseObject> _Nullable object))initialize {
    DDLogVerbose(@"%@ storeObjectWithTransaction: %@ twincodeId: %@ flags: %x", LOG_TAG, identifier, twincodeId, flags);
    
    TLTwincodeOutbound *twincodeOutbound = [[TLTwincodeOutbound alloc] initWithIdentifier:identifier twincodeId:twincodeId attributes:attributes flags:flags modificationDate:modificationDate];
    if (initialize) {
        initialize(twincodeOutbound);
    }
    
    if (refreshPeriod > 0 && refreshDate == 0) {
        refreshDate = modificationDate + refreshPeriod;
    }
    NSObject *name = [TLDatabaseService toObjectWithString:twincodeOutbound.name];
    NSObject *description = [TLDatabaseService toObjectWithString:twincodeOutbound.twincodeDescription];
    NSObject *avatarId = [TLDatabaseService toObjectWithImageId:twincodeOutbound.avatarId];
    NSObject *cap = [TLDatabaseService toObjectWithString:twincodeOutbound.capabilities];
    NSObject *content = [TLDatabaseService toObjectWithData:[twincodeOutbound serialize]];
    NSNumber *creationDate = [NSNumber numberWithLongLong:modificationDate];
    [transaction executeUpdate:@"INSERT INTO twincodeOutbound (id, twincodeId, name, description, avatarId, capabilities, creationDate, modificationDate, attributes, refreshPeriod, refreshDate, refreshTimestamp, flags) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [identifier identifierNumber], [twincodeId toString], name, description, avatarId, cap, creationDate, creationDate, content, [NSNumber numberWithLongLong:refreshPeriod], [NSNumber numberWithLongLong:refreshDate], [NSNumber numberWithLongLong:refreshTimestamp], [NSNumber numberWithInt:flags]];
    [self.database putCacheWithObject:twincodeOutbound];
    return twincodeOutbound;
}

- (BOOL)isLocal {
    
    return NO;
}

- (nonnull NSUUID *)schemaId {

    return [[NSUUID alloc] initWithUUIDString:TWINCODE_OUTBOUND_SERVICE_PROVIDER_SCHEMA_ID];
}

- (int)schemaVersion {

    return 0;
}

#pragma mark - TLTwincodesCleaner

- (void)deleteTwincodeWithTransaction:(nonnull TLTransaction *)transaction twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ deleteTwincodeWithTransaction: %@ twincodeOutbound: %@", LOG_TAG, transaction, twincodeOutbound);

    TLImageId *avatarId = twincodeOutbound.avatarId;
    NSNumber *twincodeId = [twincodeOutbound.identifier identifierNumber];

    //  Also delete the twincode keys and every secret we could have with that twincode.
    [transaction deleteWithDatabaseId:twincodeId.longLongValue table:TLDatabaseTableTwincodeKeys];
    [transaction executeUpdate:@"DELETE FROM secretKeys WHERE id=? OR peerTwincodeId=?", twincodeId, twincodeId];
    [transaction deleteWithObject:twincodeOutbound];
    if (avatarId) {
        [transaction deleteImageWithId:avatarId];
    }
}

#pragma mark - TLTwincodeOutboundServiceProvider

- (nullable TLTwincodeOutbound *)loadTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeId {
    DDLogVerbose(@"%@ loadTwincodeWithTwincodeId: %@", LOG_TAG, twincodeId);
    
    return [self.database loadTwincodeOutboundWithTwincodeId:twincodeId];
}

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate isSigned:(BOOL)isSigned {
    DDLogVerbose(@"%@ updateTwincodeWithTwincode: %@ attributes: %@ modificationDate: %lld isSigned: %d", LOG_TAG, twincode, attributes, modificationDate, isSigned);

    [self inTransaction:^(TLTransaction *transaction) {
        // If our twincode is signed, mark it as TRUSTED so that the TwinmeFramework knows the public keys
        // are set correctly and the server has received the signature.
        int twincodeFlags = twincode.flags;
        if (isSigned) {
            twincodeFlags |= FLAG_SIGNED | [TLTwincodeOutbound toFlagsWithTrustMethod:TLTrustMethodOwner];
        }
        [self internalUpdateWithTransaction:transaction twincodeOutbound:twincode attributes:attributes flags:twincodeFlags previousAttributes:nil modificationDate:modificationDate];
        [transaction commit];
        twincode.flags = twincodeFlags;
    }];
}

/// Import a possibly new twincode from the server in the database.  The twincode is associated with the refresh
/// timestamp and period.  The refresh update is scheduled to be the current date + refresh period.
- (nullable TLTwincodeOutbound *)importTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes pubSigningKey:(nullable NSData *)pubSigningKey pubEncryptionKey:(nullable NSData *)pubEncryptionKey keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey trustMethod:(TLTrustMethod)trustMethod modificationDate:(int64_t)modificationDate  refreshPeriod:(int64_t)refreshPeriod {

    __block TLTwincodeOutbound *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        int flags;
        if (!pubSigningKey) {
            flags = 0;
        } else {
            flags = FLAG_SIGNED | FLAG_VERIFIED | [TLTwincodeOutbound toFlagsWithTrustMethod:trustMethod];
        }
        long ident = [transaction longForQuery:@"SELECT twout.id FROM twincodeOutbound AS twout"
                       " WHERE twout.twincodeId=?", [twincodeId toString]];
        if (ident > 0) {
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ident factory:self];
            id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
            if (object && [object isKindOfClass:[TLTwincodeOutbound class]]) {
                result = (TLTwincodeOutbound *)object;
            } else {
                result = [self.database loadTwincodeOutboundWithId:ident];
            }
            if (result && (![result isKnown] || flags != result.flags || secretKey)) {
                BOOL isOwner = [result isOwner];
                // Keep the existing flags if we are owner of the twincode and don't store the public key!
                if (isOwner) {
                    flags = result.flags;
                }
                flags &= ~FLAG_NEED_FETCH;
                [self internalUpdateWithTransaction:transaction twincodeOutbound:result attributes:attributes flags:flags previousAttributes:nil modificationDate:modificationDate];
                if (pubSigningKey && !isOwner) {
                    [transaction storePublicKeyWithTwincode:result flags:TL_KEY_TYPE_25519 pubSigningKey:pubSigningKey pubEncryptionKey:pubEncryptionKey keyIndex:keyIndex secretKey:secretKey];
                }
                [transaction commit];
                result.flags = flags;
            }
        } else {
            TLTwincodeOutbound *twincodeOutbound = [transaction storeTwincodeOutboundWithTwincode:twincodeId attributes:attributes flags:flags modificationDate:modificationDate refreshPeriod:refreshPeriod refreshDate:0 refreshTimestamp:0];
            if (pubSigningKey) {
                [transaction storePublicKeyWithTwincode:twincodeOutbound flags:TL_KEY_TYPE_25519 pubSigningKey:pubSigningKey pubEncryptionKey:pubEncryptionKey keyIndex:keyIndex secretKey:secretKey];
            }
            [transaction commit];
            result = twincodeOutbound;
        }
    }];
    return result;
}

- (nullable TLTwincodeOutbound *)refreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes previousAttributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)previousAttributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ refreshTwincodeWithTwincode: %@ attributes: %@ modificationDate: %lld", LOG_TAG, twincodeOutbound, attributes, modificationDate);

    [self inTransaction:^(TLTransaction *transaction) {
        [self internalUpdateWithTransaction:transaction twincodeOutbound:twincodeOutbound attributes:attributes flags:twincodeOutbound.flags previousAttributes:previousAttributes modificationDate:modificationDate];
        [transaction commit];
    }];
    return twincodeOutbound;
}

/// Refresh the twincode in the database when it was changed on the server.  The twincode is associated with the refresh
/// timestamp and period.  The refresh update is scheduled to be the current date + refresh period.
- (nullable TLTwincodeOutbound *)refreshTwincodeWithTwincodeId:(long)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes previousAttributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)previousAttributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ refreshTwincodeWithTwincodeId: %ld attributes: %@ modificationDate: %lld", LOG_TAG, twincodeId, attributes, modificationDate);

    __block TLTwincodeOutbound *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithId:twincodeId];
        if (!twincodeOutbound) {
            // This twincode is removed from the database: no need to refresh it.
            return;
        }
        [self internalUpdateWithTransaction:transaction twincodeOutbound:twincodeOutbound attributes:attributes flags:twincodeOutbound.flags previousAttributes:previousAttributes modificationDate:modificationDate];
        [transaction commit];
        result = twincodeOutbound;
    }];
    return result;
}

- (int64_t)getRefreshDeadline {
    DDLogVerbose(@"%@ getRefreshDeadline", LOG_TAG);
    
    __block long deadline = 0;
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT COUNT(*), MIN(refreshDate) FROM twincodeOutbound WHERE refreshPeriod > 0"];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if ([resultSet next]) {
            long count = [resultSet longForColumnIndex:0];
            deadline = [resultSet longForColumnIndex:1];
            // We could have a refreshDate == 0, in that case use a positive value to trigger an immediate refresh.
            if (count > 0 && deadline <= 0) {
                deadline = 1000L;
            }
        }
        [resultSet close];
    }];
    
    return deadline;
}

- (nullable TLTwincodeRefreshInfo *)getRefreshListWithMaxCount:(int)maxCount {
    DDLogVerbose(@"%@ getRefreshListWithMaxCount: %d", LOG_TAG, maxCount);
    
    __block TLTwincodeRefreshInfo *info = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (database) {
            int64_t timestamp = LONG_MAX;
            int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
            NSMutableDictionary<NSUUID *, NSNumber *> *list = [[NSMutableDictionary alloc] init];
            FMResultSet *resultSet = [database executeQuery:@"SELECT id, twincodeId, refreshTimestamp"
                                      " FROM twincodeOutbound WHERE refreshPeriod > 0 AND refreshDate < ? LIMIT ?", [NSNumber numberWithLongLong:now], [NSNumber numberWithInt:maxCount]];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
                return;
            }
            while ([resultSet next]) {
                long databaseId = [resultSet longForColumnIndex:0];
                NSUUID *uuid = [resultSet uuidForColumnIndex:1];
                int64_t lTimestamp = [resultSet longLongIntForColumnIndex:2];
                if (timestamp > lTimestamp) {
                    timestamp = lTimestamp;
                }
                if (uuid) {
                    [list setObject:[NSNumber numberWithLong:databaseId] forKey:uuid];
                }
            }
            [resultSet close];
            info = [[TLTwincodeRefreshInfo alloc] initWithTwincodes:list timestamp:timestamp];
        }
    }];
    
    return info;
}

- (void)updateRefreshTimestampWithList:(nonnull NSArray<NSNumber *> *)list refreshTimestamp:(int64_t)refreshTimestamp currentDate:(int64_t)currentDate {
    DDLogVerbose(@"%@ updateRefreshTimestampWithList: %@ refreshTimestamp: %lld", LOG_TAG, list, refreshTimestamp);
    
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *refreshTime = [NSNumber numberWithLongLong:refreshTimestamp];
        NSNumber *now = [NSNumber numberWithLongLong:currentDate];
        for (NSNumber *twincodeId in list) {
            [transaction executeUpdate:@"UPDATE twincodeOutbound SET refreshTimestamp=?, refreshDate=? + refreshPeriod WHERE id=?", refreshTime, now, twincodeId];
        }
        [transaction commit];
    }];
}

- (void)evictTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ evictTwincode: %@ twincodeOutboundId: %@", LOG_TAG, twincodeOutboundId, twincodeOutboundId);
    
    [self inTransaction:^(TLTransaction *transaction) {
        TLTwincodeOutbound *twincode = twincodeOutbound;
        if (twincodeOutboundId) {
            twincode = [self loadTwincodeWithTwincodeId:twincodeOutboundId];
        }
        if (!twincode) {
            return;
        }
        NSNumber *identifier = [twincode.identifier identifierNumber];
        long usedRepo = [transaction longForQuery:@"SELECT COUNT(*) FROM repository WHERE peerTwincodeOutbound=? OR twincodeOutbound=?", identifier, identifier];
        long usedConv = [transaction longForQuery:@"SELECT COUNT(*) FROM conversation WHERE peerTwincodeOutbound=?", identifier];
        if (usedRepo + usedConv == 0) {
            [self deleteTwincodeWithTransaction:transaction twincodeOutbound:twincode];
            [transaction commit];
        }
    }];
}

- (void)deleteTwincode:(nonnull NSNumber *)databaseId {
    DDLogVerbose(@"%@ deleteTwincode: %@", LOG_TAG, databaseId);
    
    [self inTransaction:^(TLTransaction *transaction) {
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithId:databaseId.longValue];
        if (twincodeOutbound) {
            [transaction deleteConversationsWithSubjectId:nil twincodeId:databaseId];
            [self deleteTwincodeWithTransaction:transaction twincodeOutbound:twincodeOutbound];
            [transaction commit];
        }
    }];
}

- (void)createPrivateKeyWithCryptoService:(nonnull TLCryptoService *)cryptoService twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound {
    DDLogVerbose(@"%@ createPrivateKeyWithCryptoService: %@ twincodeOutbound: %@ twincodeInbound: %@", LOG_TAG, cryptoService, twincodeOutbound, twincodeInbound);
    
    [self inTransaction:^(TLTransaction *transaction) {
        [cryptoService createPrivateKeyWithTransaction:transaction twincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound];

        int flags = twincodeOutbound.flags | FLAG_SIGNED | [TLTwincodeOutbound toFlagsWithTrustMethod:TLTrustMethodOwner];
        twincodeOutbound.modificationDate = [[NSDate date] timeIntervalSince1970] * 1000;
        [transaction executeUpdate:@"UPDATE twincodeOutbound SET modificationDate=?, flags=? WHERE id=?", [NSNumber numberWithLongLong:twincodeOutbound.modificationDate], [NSNumber numberWithInt:flags], [twincodeOutbound.identifier identifierNumber]];
        [transaction commit];
        twincodeOutbound.flags = flags;
    }];
}

- (void)associateTwincodes:(nonnull TLTwincodeOutbound *)twincodeOutbound previousPeerTwincode:(nullable TLTwincodeOutbound *)previousPeerTwincode peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode {
    DDLogVerbose(@"%@ associateTwincodes: %@ twincodeOutbound: %@ twincodeInbound: %@", LOG_TAG, twincodeOutbound, previousPeerTwincode, peerTwincode);
    
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *twincodeId = [twincodeOutbound.identifier identifierNumber];
        NSNumber *peerId = [peerTwincode.identifier identifierNumber];
        NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];

        // If a previous peer twincode is defined, re-associate the secrets to the new { twincode, peerTwincode } pair.
        if (previousPeerTwincode) {
            NSNumber *previousPeerId = [previousPeerTwincode.identifier identifierNumber];
            FMResultSet *resultSet = [transaction executeQuery:@"SELECT flags, creationDate, secretUpdateDate, secret1, secret2"
                                      " FROM secretKeys WHERE id=? AND peerTwincodeId=?", twincodeId, previousPeerId];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
                return;
            }
            if (![resultSet next]) {
                [resultSet close];
                // Previous key association was not found, nothing to associate.
                return;
            }

            int flags = [resultSet intForColumnIndex:0];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:1];
            int64_t secretUpdateDate = [resultSet longLongIntForColumnIndex:2];
            NSData *secret1 = [resultSet dataForColumnIndex:3];
            NSData *secret2 = [resultSet dataForColumnIndex:4];
            [resultSet close];
                
            [transaction executeUpdate:@"INSERT OR REPLACE INTO secretKeys (id, peerTwincodeId, creationDate, modificationDate, secretUpdateDate, flags, secret1, secret2) values (?, ?, ?, ?, ?, ?, ?, ?)", twincodeId, peerId, [NSNumber numberWithLongLong:creationDate], now, [NSNumber numberWithLongLong:secretUpdateDate], [NSNumber numberWithInt:flags], [TLDatabaseService toObjectWithData:secret1], [TLDatabaseService toObjectWithData:secret2]];
                
            [transaction executeUpdate:@"DELETE FROM secretKeys WHERE id=? AND peerTwincodeId=?", twincodeId, previousPeerId];
        }

        // Check if the FLAG_ENCRYPT flags are set on the twincodes:
        // - we must have the { <twincode>, <peer-twincode> } key association,
        // - we must know the peer secret { <peer-twincode>, null } association.
        [transaction updateTwincodeEncryptFlagsWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincode now:now];
        [transaction commit];
    }];
}

- (void)setCertifiedWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode trustMethod:(TLTrustMethod)trustMethod {
    DDLogVerbose(@"%@ setCertifiedWithTwincode: %@ peerTwincode: %@ trustMethod: %lu", LOG_TAG, twincodeOutbound, peerTwincode, trustMethod);
    
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *twincodeId = [twincodeOutbound.identifier identifierNumber];
        NSNumber *peerId = [peerTwincode.identifier identifierNumber];
        NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];

        // For our twincode, only update the FLAG_CERTIFIED.
        int twincodeFlags = twincodeOutbound.flags | FLAG_CERTIFIED;
        [transaction executeUpdate:@"UPDATE twincodeOutbound SET flags=?, "
         "modificationDate=? WHERE id=?", [NSNumber numberWithInt:twincodeFlags], now, twincodeId];

        // For the peer twincode, set the FLAG_CERTIFIED but also the FLAG_TRUSTED and record the trust method used.
        // If an existing trust method is defined, it is added (ex: INVITATION_CODE + VIDEO).
        int peerTwincodeFlags = peerTwincode.flags | FLAG_CERTIFIED | FLAG_TRUSTED | [TLTwincodeOutbound toFlagsWithTrustMethod:trustMethod];
        [transaction executeUpdate:@"UPDATE twincodeOutbound SET flags=?, "
         "modificationDate=? WHERE id=?", [NSNumber numberWithInt:peerTwincodeFlags], now, peerId];
        [transaction commit];
        
        twincodeOutbound.flags = twincodeFlags;
        peerTwincode.flags = peerTwincodeFlags;
    }];
}

#pragma mark - private

- (void)internalUpdateWithTransaction:(nonnull TLTransaction *)transaction twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes flags:(int)flags previousAttributes:(nullable NSMutableArray<TLAttributeNameValue *> *)previousAttributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ internalUpdateWithTransaction: %@ twincodeOutbound: %@ flags: %d", LOG_TAG, transaction, twincodeOutbound, flags);
    
    [twincodeOutbound importWithAttributes:attributes previousAttributes:previousAttributes modificationDate:modificationDate];
    TLImageId *previousAvatarId = twincodeOutbound.avatarId;
    if ([transaction storeAvatarWithTwincode:twincodeOutbound attributes:attributes] && previousAttributes && previousAvatarId) {
        TLExportedImageId *avatarId = [self publicWithImageId:previousAvatarId];
        if (avatarId) {
            [previousAttributes addObject:[[TLAttributeNameImageIdValue alloc] initWithName:TL_TWINCODE_AVATAR_ID value:avatarId]];
        }
    }
    
    NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
    TLDatabaseIdentifier *identifier = [twincodeOutbound databaseId];
    NSObject *name = [TLDatabaseService toObjectWithString:twincodeOutbound.name];
    NSObject *description = [TLDatabaseService toObjectWithString:twincodeOutbound.twincodeDescription];
    NSObject *avatarId = [TLDatabaseService toObjectWithImageId:twincodeOutbound.avatarId];
    NSObject *cap = [TLDatabaseService toObjectWithString:twincodeOutbound.capabilities];
    NSObject *content = [TLDatabaseService toObjectWithData:[twincodeOutbound serialize]];
    [transaction executeUpdate:@"UPDATE twincodeOutbound SET name=?, description=?, capabilities=?, "
     "avatarId=?, attributes=?, modificationDate=?, flags=?, refreshTimestamp=?, refreshDate=? + refreshPeriod WHERE id=?", name, description, cap, avatarId, content, now, [NSNumber numberWithInt:flags], [NSNumber numberWithLongLong:modificationDate], now, [identifier identifierNumber]];

    twincodeOutbound.modificationDate = now.longLongValue;
}

- (void)upgrade20WithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ upgrade20WithTransaction: %@", LOG_TAG, transaction);
    
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT uuid, refreshPeriod, refreshDate, "
                              "refreshTimestamp, content FROM twincodeOutboundTwincodeOutbound"];
    if (resultSet) {
        while ([resultSet next]) {
            NSUUID *twincodeId = [resultSet uuidForColumnIndex:0];
            int64_t refreshPeriod = [resultSet longLongIntForColumnIndex:1];
            int64_t refreshDate = [resultSet longLongIntForColumnIndex:2];
            int64_t refreshTimestamp = [resultSet longLongIntForColumnIndex:3];
            NSData *content = [resultSet dataForColumnIndex:4];
            if (content) {
                TLDataInputStream *dataInputStream = [[TLDataInputStream alloc] initWithData:content];
                
                (void)[dataInputStream readUUID];
                int64_t modificationDate = [dataInputStream readUInt64];
                NSMutableArray *attributes = [[NSMutableArray alloc] init];
                NSInteger count = [dataInputStream readUInteger];
                for (int i = 0; i < count; i++) {
                    TLAttributeNameValue *attribute = [TLBaseService deserializeWithDataInputStream:dataInputStream];
                    if (attribute) {
                        [attributes addObject:attribute];
                    }
                }
                if ([dataInputStream isCompleted] && twincodeId) {
                    [transaction storeTwincodeOutboundWithTwincode:twincodeId attributes:attributes flags:0 modificationDate:modificationDate refreshPeriod:refreshPeriod refreshDate:refreshDate refreshTimestamp:refreshTimestamp];
                }
            }
        }
        [resultSet close];
    }

    [transaction dropTable:@"twincodeOutboundTwincodeOutbound"];
}

@end

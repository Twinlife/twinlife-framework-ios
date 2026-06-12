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

#import "TLTwincodeOutboundServiceImpl.h"
#import "TLTwincodeInboundServiceImpl.h"
#import "TLTwincodeInboundServiceProvider.h"
#import "TLTwincodeInfo.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define LOG_TAG @"TwincodeInboundServiceProvider"

#define TWINCODE_INBOUND_SERVICE_PROVIDER_SCHEMA_ID @"33c38ac6-e89d-4639-b116-90fc47a5f9f4"

/**
 * twincodeInbound table:
 * id INTEGER: local database identifier (primary key)
 * twincodeId TEXT UNIQUE NOT NULL: twincode inbound id
 * factoryId TEXT: the factory that created this twincode.
 * twincodeOutbound INTEGER: the associated twincode outbound.
 * capabilities TEXT: capabilities attribute
 * modificationDate INTEGER: the last modification date.
 * attributes BLOB: the other attributes
 */
#define TWINCODE_INBOUND_CREATE_TABLE \
        @"CREATE TABLE IF NOT EXISTS twincodeInbound (id INTEGER PRIMARY KEY," \
                " twincodeId TEXT UNIQUE NOT NULL, factoryId TEXT, twincodeOutbound INTEGER," \
                " capabilities TEXT," \
                " modificationDate INTEGER NOT NULL, attributes BLOB)"

//
// Implementation: TLTwincodeInboundServiceProvider
//

@implementation TLTwincodeInboundServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLTwincodeInboundService *)service database:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@ initWithService: %@ database: %@", LOG_TAG, service, database);

    self = [super initWithService:service database:database sqlCreate:TWINCODE_INBOUND_CREATE_TABLE table:TLDatabaseTableTwincodeInbound];
    if (self) {
        self.database.twincodeInboundFactory = self;
    }
    return self;
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);

    /*
     * <pre>
     * Database Version 20
     *  Date: 2023/08/29
     *   New database model with twincodeInbound table and change of primary key
     *   The old table to new table migration is made by the RepositoryServiceProvider.
     *   We must keep the old table for the RepositoryService migration and it will be dropped there.
     * </pre>
     */
    [super onUpgradeWithTransaction:transaction oldVersion:oldVersion newVersion:newVersion];
}

- (int)onResumeWithDatabase:(nonnull FMDatabase *)database lastSuspendDate:(int64_t)lastSuspendDate {
    DDLogVerbose(@"%@ onResumeWithDatabase: %@ lastSuspendDate: %lld", LOG_TAG, database, lastSuspendDate);

    TL_DECL_START_MEASURE(startTime)

    // Reload the twincodes that have been modified by the NotificationServiceExtension.
    int count = 0;
    FMResultSet *resultSet = [database executeQuery:@"SELECT ti.id, ti.twincodeId, ti.factoryId,"
                              " ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes"
                              " FROM twincodeInbound AS ti WHERE ti.modificationDate > ?", [NSNumber numberWithLongLong:lastSuspendDate]];
    if (!resultSet) {
        [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
        return 0;
    }
    while ([resultSet next]) {
        if ([self.database loadTwincodeInboundWithResultSet:resultSet offset:0]) {
            count++;
        }
    }
    [resultSet close];
    TL_END_MEASURE(startTime, @"TwincodeInboundService resume")
    return count;
}

#pragma mark - TLDatabaseObjectFactory

- (nullable id<TLDatabaseObject>)createObjectWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ createObjectWithIdentifier: %@ offset: %d", LOG_TAG, identifier, offset);

    // ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes
    NSUUID *twincodeId = [cursor uuidForColumnIndex:offset];
    NSUUID *factoryId = [cursor uuidForColumnIndex:offset + 1];
    long twincodeOutboundId = [cursor longForColumnIndex:offset + 2];
    TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithId:twincodeOutboundId];
    int64_t modificationDate = [cursor longLongIntForColumnIndex:offset + 3];
    NSString *capabilities = [cursor stringForColumnIndex:offset + 4];
    NSData *content = [cursor dataForColumnIndex:offset + 5];
    return [[TLTwincodeInbound alloc] initWithIdentifier:identifier twincodeId:twincodeId factoryId:factoryId twincodeOutbound:twincodeOutbound capabilities:capabilities content:content modificationDate:modificationDate];
}

- (BOOL)loadWithObject:(nonnull id<TLDatabaseObject>)object cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ loadWithObject: %@ offset: %d", LOG_TAG, object, offset);

    TLTwincodeInbound *twincodeInbound = (TLTwincodeInbound *)object;
    int64_t modificationDate = [cursor longLongIntForColumnIndex:offset + 3];
    if (twincodeInbound.modificationDate == modificationDate) {
        return NO;
    }
    NSString *capabilities = [cursor stringForColumnIndex:offset + 4];
    NSData *content = [cursor dataForColumnIndex:offset + 5];
    [twincodeInbound updateWithCapabilities:capabilities content:content modificationDate:modificationDate];
    return YES;
}

- (nonnull id<TLDatabaseObject>)storeObjectWithTransaction:(nonnull TLTransaction *)transaction identifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:()attributes flags:(int)flags creationDate:(int64_t)creationDate modificationDate:(int64_t)modificationDate refreshPeriod:(int64_t)refreshPeriod refreshDate:(int64_t)refreshDate refreshTimestamp:(int64_t)refreshTimestamp initialize:(nonnull void (^)(id<TLDatabaseObject> _Nullable object))initialize {
    DDLogVerbose(@"%@ storeObjectWithDatabase: %@ twincodeId: %@", LOG_TAG, identifier, twincodeId);

    TLTwincodeInbound *twincodeInbound = [[TLTwincodeInbound alloc] initWithIdentifier:identifier twincodeId:twincodeId attributes:attributes modificationDate:modificationDate];
    if (initialize) {
        initialize(twincodeInbound);
    }

    NSObject *cap = [TLDatabaseService toObjectWithString:twincodeInbound.capabilities];
    NSObject *factoryId = [TLDatabaseService toObjectWithUUID:twincodeInbound.factoryId];
    NSObject *content = [TLDatabaseService toObjectWithData:[twincodeInbound serialize]];
    NSObject *twincodeOutbound = [twincodeInbound.twincodeOutbound.identifier identifierNumber];
    [transaction executeUpdate:@"INSERT INTO twincodeInbound (id, twincodeId, capabilities, modificationDate, factoryId, attributes, twincodeOutbound) VALUES(?, ?, ?, ?, ?, ?, ?)", [identifier identifierNumber], [twincodeId toString], cap, [NSNumber numberWithLongLong:modificationDate], factoryId, content, twincodeOutbound];
    [self.database putCacheWithObject:twincodeInbound];
    return twincodeInbound;
}

- (BOOL)isLocal {
    
    return NO;
}

- (nonnull NSUUID *)schemaId {

    return [[NSUUID alloc] initWithUUIDString:TWINCODE_INBOUND_SERVICE_PROVIDER_SCHEMA_ID];
}

- (int)schemaVersion {

    return 0;
}

#pragma mark - TLTwincodeInboundServiceProvider

- (nullable TLTwincodeInbound *)loadTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeInboundId {
    DDLogVerbose(@"%@ loadTwincodeWithTwincodeInboundId: %@", LOG_TAG, twincodeInboundId);
    
    return [self.database loadTwincodeInboundWithTwincodeId:twincodeInboundId];
}

- (nullable TLTwincodeInbound *)loadTwincodeWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ loadTwincodeWithTwincodeOutbound: %@", LOG_TAG, twincodeOutbound);

    __block TLTwincodeInbound *twincodeInbound = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (database) {
            FMResultSet *resultSet = [database executeQuery:@"SELECT ti.id, ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes FROM twincodeInbound AS ti WHERE ti.twincodeOutbound = ?", [twincodeOutbound.databaseId identifierNumber]];
            if (resultSet) {
                if ([resultSet next]) {
                    twincodeInbound = [self.database loadTwincodeInboundWithResultSet:resultSet offset:0];
                }
                [resultSet close];
            }
        }
    }];
    return twincodeInbound;
}

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ updateTwincodeWithTwincode: %@ modificationDate: %lld", LOG_TAG, twincodeInbound, modificationDate);
    
    [twincodeInbound importWithAttributes:attributes modificationDate:modificationDate];
    [self inTransaction:^(TLTransaction *transaction) {
        NSObject *content = [TLDatabaseService toObjectWithData:[twincodeInbound serialize]];
        [transaction executeUpdate:@"UPDATE twincodeInbound SET capabilities=?, modificationDate=?, attributes=? WHERE id=?", [twincodeInbound.identifier identifierNumber], twincodeInbound.capabilities, [NSNumber numberWithLongLong:modificationDate], content];
        [transaction commit];
    }];
}

- (nullable TLTwincodeInbound *)importTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ importTwincodeWithTwincodeId: %@ twincodeOutbound: %@ attributes: %@ modificationDate: %lld", LOG_TAG, twincodeId, twincodeOutbound, attributes, modificationDate);

    __block TLTwincodeInbound *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        long ident = [transaction longForQuery:@"SELECT ti.id FROM twincodeInbound AS ti WHERE ti.twincodeId=?", [twincodeId toString]];
        if (ident > 0) {
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ident factory:self];
            id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
            if (object && [(NSObject *)object isKindOfClass:[TLTwincodeInbound class]]) {
                result = (TLTwincodeInbound *)object;
            } else {
                result = [self.database loadTwincodeInboundWithTwincodeId:twincodeId];
            }

        } else {
            TLTwincodeInbound *twincodeInbound = [transaction storeTwincodeInboundWithTwincode:twincodeId twincodeOutbound:twincodeOutbound twincodeFactoryId:nil attributes:attributes modificationDate:modificationDate];
            [transaction commit];
            result = twincodeInbound;
        }
    }];

    return result;
}

- (nonnull NSArray<TLTwincodeInbound *> *)loadTwincodes {
    DDLogVerbose(@"%@ loadTwincodes", LOG_TAG);
    
    return [self.database loadAllTwincodeInbounds];
}


- (nullable TLTwincodeInbound *)restoreTwincodeWithDatabaseId:(int64_t)databaseId twincodeId:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nonnull NSUUID *)twincodeFactoryId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ restoreTwincodeWithDatabaseId: %lld twincodeId:%@ twincodeOutbound: %@ modificationDate: %lld", LOG_TAG, databaseId, twincodeId, twincodeOutbound, modificationDate);

    __block TLTwincodeInbound *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        long ident = [transaction longForQuery:@"SELECT ti.id FROM twincodeInbound AS ti WHERE ti.twincodeId=?", [twincodeId toString]];
        if (ident > 0) {
            DDLogError(@"%@ Twincode %@ already exists in database", LOG_TAG, twincodeId.UUIDString);
            return;
        }
        TLTwincodeInbound *twincodeInbound = [transaction storeTwincodeInboundWithDatabaseId:databaseId twincodeId:twincodeId twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId attributes:attributes flags:0 modificationDate:modificationDate];
        [transaction commit];
        result = twincodeInbound;
    }];

    return result;
}

- (nullable NSArray<TLTwincodeInfo *> *)syncWithTwincodes:(nonnull NSDictionary<NSUUID *, NSArray<TLTwincodeInfo *> *> *)serverTwincodes {

    __block NSMutableArray<TLTwincodeInfo *> *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {

        NSMutableDictionary<NSUUID *, TLTwincodeInfo *> *twincodes = [[NSMutableDictionary alloc] init];
        for (NSUUID *schemaId in serverTwincodes) {
            NSArray<TLTwincodeInfo *> *list = serverTwincodes[schemaId];
            for (TLTwincodeInfo *twincodeInfo in list) {
                [twincodes setObject:twincodeInfo forKey:twincodeInfo.twincodeInboundId];
            }
        }

        // Step 2: load the twincode inbound and their associated twincode outbound in a single SQL query.
        // If the twincode inbound factory is not known, update it from what we got from the server.
        FMResultSet *resultSet = [transaction executeQuery:@"SELECT twout.id, twout.twincodeId, twout.modificationDate,"
                                  " twout.name, twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags,"
                                  " ti.id, ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate,"
                                  " ti.capabilities, ti.attributes"
                                  " FROM twincodeInbound AS ti"
                                  " INNER JOIN twincodeOutbound AS twout ON ti.twincodeOutbound = twout.id"];
        if (!resultSet) {
            return;
        }
        NSMutableArray<TLTwincodeInbound *> *toUpdate = nil;
        while ([resultSet next]) {
            // Note: this load is necessary to put the TLTwincodeOutbound in the cache.
            [self.database loadTwincodeOutboundWithResultSet:resultSet offset:0];
            TLTwincodeInbound *twincodeInbound = [self.database loadTwincodeInboundWithResultSet:resultSet offset:9];
            if (twincodeInbound) {
                TLTwincodeInfo *twincodeInfo = twincodes[twincodeInbound.uuid];
                if (twincodeInfo) {
                    [twincodes removeObjectForKey:twincodeInbound.uuid];
                    if (!twincodeInbound.factoryId) {
                        twincodeInbound.factoryId = twincodeInfo.twincodeFactoryId;
                        if (!toUpdate) {
                            toUpdate = [[NSMutableArray alloc] init];
                        }
                        [toUpdate addObject:twincodeInbound];
                        [self.service.twinlife assertionWithAssertPoint:[TLTwincodeAssertPoint RECOVER_FACTORY_ID], [TLAssertValue initWithTwincodeInbound:twincodeInbound], nil];
                    }
                }
            }
        }
        [resultSet close];

        // Step 3: update the twincode inbound whose factory was incorrect.
        if (toUpdate) {
            for (TLTwincodeInbound *twincodeInbound in toUpdate) {
                [transaction executeUpdate:@"UPDATE twincodeInbound SET factoryId=? WHERE id=?", [TLDatabaseService toObjectWithUUID:twincodeInbound.factoryId], [twincodeInbound.identifier identifierNumber]];
            }
        }

        // Step 4: insert the twincode inbound which are not known only if we have the associated twincode outbound.
        // If the twincode outbound is not known, there is no associated object and the twincode is not known.
        // It must be removed from the server.
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        for (NSUUID *twincodeId in twincodes) {
            TLTwincodeInfo *twincodeInfo = twincodes[twincodeId];
            TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithTwincodeId:twincodeInfo.twincodeOutboundId];

            if (twincodeOutbound) {
                TLTwincodeInbound *twincodeInbound = [transaction storeTwincodeInboundWithTwincode:twincodeInfo.twincodeInboundId twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeInfo.twincodeFactoryId attributes:nil modificationDate:now];
                [self.service.twinlife assertionWithAssertPoint:[TLTwincodeAssertPoint RECOVER_TWINCODE_IN], [TLAssertValue initWithTwincodeInbound:twincodeInbound], nil];
            } else {
                if (result == nil) {
                    result = [[NSMutableArray alloc] init];
                }
                [result addObject:twincodeInfo];
                [self.service.twinlife assertionWithAssertPoint:[TLTwincodeAssertPoint UNKNOWN_TWINCODE], [TLAssertValue initWithTwincodeId:twincodeInfo.twincodeOutboundId], [TLAssertValue initWithTwincodeId:twincodeInfo.twincodeInboundId], [TLAssertValue initWithTwincodeId:twincodeInfo.twincodeFactoryId], nil];
            }
        }
        [transaction commit];
    }];

    return result;
}

@end

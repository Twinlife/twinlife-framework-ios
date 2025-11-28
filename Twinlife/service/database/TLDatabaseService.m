/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLAttributeNameValue.h"
#import "TLDatabaseService.h"
#import "TLDatabaseServiceProvider.h"
#import "TLBaseService.h"
#import "TLTwincode.h"
#import "TLTwincodeInboundServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLRepositoryService.h"
#import "TLDatabaseCheck.h"
#import "TLImageId.h"

#import <sqlite3.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

/**
 * sequence table:
 * name TEXT NOT NULL: the sequence name (primary key)
 * id INTEGER: the next sequence id ready to be used.
 */
#define SEQUENCE_TABLE_CREATE       @"CREATE TABLE IF NOT EXISTS sequence" \
         " (name TEXT PRIMARY KEY NOT NULL, id INTEGER NOT NULL);"

/**
 * Tables from V7 to V19:
 *  "CREATE TABLE IF NOT EXISTS conversationId (key TEXT PRIMARY KEY NOT NULL, id INTEGER);";
 */

//
// Interface: TLDatabaseAllocator
//

@interface TLDatabaseAllocator : NSObject

@property long next;
@property long last;

- (nonnull instancetype)init;

@end

//
// Interface: TLTransaction
//

@interface TLTransaction ()

@property (readonly, nonnull) TLDatabaseService *databaseService;
@property (readonly, nonnull) NSArray<TLDatabaseAllocator *> *allocatorIds;
@property (nullable) FMDatabase *database;
@property (nullable) NSMutableArray<TLDatabaseAllocator *> *usedAllocators;

- (nonnull instancetype)initWithDatabaseService:(nonnull TLDatabaseService *)databaseService;

@end

//
// Interface: TLDatabaseService
//

@interface TLDatabaseService ()

@property (readonly, nonnull) NSMutableArray<TLDatabaseServiceProvider *> *serviceProviders;
@property (readonly, nonnull) NSMutableDictionary<TLDatabaseIdentifier *, id<TLDatabaseObject>> *objectCache;
@property (readonly, nonnull) NSMutableDictionary<NSUUID *, TLDatabaseIdentifier *> *idCache;
@property (readonly, nonnull) TLTransaction *transaction;
@property (readonly, nonnull) TLTwinlife *twinlife;
@property (nullable) FMDatabaseQueue *databaseQueue;
@property (nullable) id<TLRepositoryObjectLoader> repositoryObjectLoader;
@property (nullable) id<TLNotificationsCleaner> notificationsCleaner;
@property (nullable) id<TLConversationsCleaner> conversationsCleaner;
@property (nullable) id<TLImagesCleaner> imagesCleaner;
@property (nullable) id<TLTwincodesCleaner> twincodesCleaner;

+ (nullable NSString *)getTableNameWithTable:(TLDatabaseTable)table;

// - (nullable TLDatabaseIdentifier *)getCachedIdentifier:(nonnull NSUUID *)objectId;

@end

//
// Interface: TLQueryBuilder
//

@interface TLQueryBuilder ()

@property (nonnull, readonly) NSMutableString *query;
@property (nonnull, readonly) NSMutableArray<NSObject *> *params;
@property BOOL hasWhere;

@end

//
// Interface: TLDatabaseFullException
//
@implementation TLDatabaseFullException

+ (nonnull TLDatabaseFullException *)createWithReason:(nullable NSString *)reason userInfo:(nullable NSDictionary *)userInfo {
    
    return [[TLDatabaseFullException alloc] initWithName:@"DatabaseFullException" reason:reason userInfo:userInfo];
}

@end

//
// Interface: TLDatabaseErrorException
//
@implementation TLDatabaseErrorException

- (nonnull instancetype)initWithReason:(nullable NSString *)reason error:(nullable NSError *)error {
    
    self = [super initWithName:@"DatabaseErrorException" reason:reason userInfo:error.userInfo];
    if (self) {
        _code = error.code;
    }
    return self;
}

+ (nonnull TLDatabaseErrorException *)createWithReason:(nullable NSString *)reason error:(nullable NSError *)error {

    return [[TLDatabaseErrorException alloc] initWithReason:reason error:error];
}

@end

//
// Implementation: TLDatabaseAssertPoint
//

@implementation TLDatabaseAssertPoint : TLAssertPoint

TL_CREATE_ASSERT_POINT(DATABASE_ERROR, 20)
TL_CREATE_ASSERT_POINT(EXCEPTION, 21)
TL_CREATE_ASSERT_POINT(DATABASE_UPDATE_ERROR, 22)

@end

//
// Implementation: TLQueryBuilder
//

@implementation TLQueryBuilder : NSObject

- (nonnull instancetype)initWithSQL:(nonnull NSString *)sql {
    
    self = [super init];
    if (self) {
        _query = [[NSMutableString alloc] initWithFormat:@"SELECT %@", sql];
        _params = [[NSMutableArray alloc] init];
        _hasWhere = NO;
    }
    return self;
}

- (nonnull NSString *)sql {
    
    return self.query;
}

- (nonnull NSArray<NSObject *> *)sqlParams {
    
    return self.params;
}

- (void)inWhere {

    if (self.hasWhere) {
        [self.query appendString:@" AND "];
    } else {
        [self.query appendString:@" WHERE "];
        self.hasWhere = YES;
    }
}

- (void)filterBefore:(int64_t)before field:(nonnull NSString *)field {
    
    if (before != 0) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@"<?"];
        [self.params addObject:[NSNumber numberWithLongLong:before]];
    }
}

- (void)filterAfter:(int64_t)after field:(nonnull NSString *)field {
    
    if (after != 0) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@">?"];
        [self.params addObject:[NSNumber numberWithLongLong:after]];
    }
}

- (void)filterOwner:(nullable id<TLRepositoryObject>)owner field:(nonnull NSString *)field {
    
    if (owner) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@"=?"];
        [self.params addObject:[owner.identifier identifierNumber]];
    }
}

- (void)filterName:(nullable NSString *)name field:(nonnull NSString *)field {
    
    if (name) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@" LIKE ?"];

        // If the text to search contains a '%' we have to escape it (using '%' as escape failed for me).
        // Use the '^' as the escape character but if it occurs, we must also escape it.
        if ([field containsString:@"%"]) {
            name = [name stringByReplacingOccurrencesOfString:@"^" withString:@"^^"];
            name = [name stringByReplacingOccurrencesOfString:@"%" withString:@"^%"];
            [self.query appendString:@" ESCAPE '^'"];
        }

        // Enclose the search text with the '%' pattern (similar to .* in regex).
        [self.params addObject:[NSString stringWithFormat:@"%%%@%%", name]];
    }
}

- (void)filterUUID:(nullable NSUUID *)uuid field:(nonnull NSString *)field {
    
    if (uuid) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@"=?"];
        [self.params addObject:[TLDatabaseService toObjectWithUUID:uuid]];
    }
}

- (void)filterLong:(long)value field:(nonnull NSString *)field {
    
    if (value) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@"=?"];
        [self.params addObject:[NSNumber numberWithLong:value]];
    }
}

- (void)filterIdentifier:(nullable TLDatabaseIdentifier *)value field:(nonnull NSString *)field {
    
    if (value) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@"=?"];
        [self.params addObject:[value identifierNumber]];
    }
}

- (void)filterNumber:(nullable NSNumber *)value field:(nonnull NSString *)field {
    
    if (value != nil) {
        [self inWhere];
        [self.query appendString:field];
        [self.query appendString:@"=?"];
        [self.params addObject:value];
    }
}

- (void)filterInUUID:(nonnull NSArray<NSUUID *> *)list field:(nonnull NSString *)field {
    
    [self inWhere];
    [self.query appendString:field];
    [self.query appendString:@" IN ("];
    BOOL needSep = NO;
    for (NSUUID *uuid in list) {
        if (needSep) {
            [self.query appendString:@","];
        }
        needSep = YES;
        [self.query appendString:@"?"];
        [self.params addObject:[TLDatabaseService toObjectWithUUID:uuid]];
    }
    [self.query appendString:@")"];
}

- (void)filterInList:(nonnull NSArray<NSNumber *> *)list field:(nonnull NSString *)field {
    
    [self inWhere];
    [self.query appendString:field];
    [self.query appendString:@" IN ("];
    BOOL needSep = NO;
    for (NSNumber *value in list) {
        if (needSep) {
            [self.query appendString:@","];
        }
        needSep = YES;
        [self.query appendString:@"?"];
        [self.params addObject:value];
    }
    [self.query appendString:@")"];
}

- (void)filterWhere:(nullable NSString *)sql {
    
    if (sql) {
        [self inWhere];
        [self.query appendString:sql];
    }
}

- (void)order:(nonnull NSString *)order {
    
    [self.query appendString:@" ORDER BY "];
    [self.query appendString:order];
}

- (void)limit:(long)value {
    
    [self.query appendString:@" LIMIT ?"];
    [self.params addObject:[NSNumber numberWithLong:value]];
}

- (void)appendString:(nonnull NSString *)sqlFragment {
    
    [self.query appendString:sqlFragment];
}

@end

//
// Implementation: TLDatabaseAllocator
//

@implementation TLDatabaseAllocator

- (nonnull instancetype)init {

    self = [super init];
    if (self) {
        _last = 0;
        _next = 0;
    }
    return self;
}

@end;

//
// Implementation: TLDatabaseIdentifier
//

@implementation TLDatabaseIdentifier

- (nonnull instancetype)initWithIdentifier:(long)identifier factory:(nonnull id<TLDatabaseObjectIdentification>)factory {
    
    self = [super init];
    if (self) {
        _identifier = identifier;
        _factory = factory;
    }
    return self;
}

- (nonnull NSNumber *)identifierNumber {
    
    return [NSNumber numberWithLong:self.identifier];
}

- (TLDatabaseTable)databaseTable {
    
    return [self.factory kind];
}

/// The schema ID identifies the object factory in the database.
- (nonnull NSUUID *)schemaId {
    
    return [self.factory schemaId];
}

/// The schema version identifies a specific version of the object representation.
- (int)schemaVersion {
    
    return [self.factory schemaVersion];
}

/// Indicates whether the object is local only or also stored on the server.
- (BOOL)isLocal {
    
    return [self.factory isLocal];
}

- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[TLDatabaseIdentifier class]]) {
        return NO;
    }
    
    TLDatabaseIdentifier *item = (TLDatabaseIdentifier *)object;
    
    return self.identifier == item.identifier && self.factory == item.factory;
}

- (NSUInteger)hash {
    
    return (NSUInteger)(self.identifier ^ (self.identifier >> 32) ^ (long)[self.factory kind] << 11);
}

- (id)copyWithZone:(NSZone *)zone {
    
    return self;
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"["];
    [string appendFormat:@"%ld.%@", self.identifier, [TLDatabaseService getTableNameWithTable:self.factory.kind]];
    [string appendString:@"]"];
    return string;
}

@end

//
// Implementation: TLTransaction
//

#undef LOG_TAG
#define LOG_TAG @"TLTransaction"

@implementation TLTransaction

- (nonnull instancetype)initWithDatabaseService:(nonnull TLDatabaseService *)databaseService {
    
    self = [super init];
    if (self) {
        _databaseService = databaseService;
        
        // Create a database allocator instance for each table.
        NSMutableArray *allocators = [[NSMutableArray alloc] initWithCapacity:TLDatabaseTableLast];
        for (int i = 0; i < TLDatabaseTableLast; i++) {
            [allocators addObject:[[TLDatabaseAllocator alloc] init]];
        }
        _allocatorIds = allocators;
        _database = nil;
        _usedAllocators = nil;
        
    }
    return self;
}

- (long)allocateIdWithTable:(TLDatabaseTable)table {
    
    // Note: unlike Android, the TLTransaction instance is global and unique
    @synchronized (self.databaseService) {
        TLDatabaseAllocator *allocator = self.allocatorIds[table];
        //  Keep a list of sequence allocators used in case we have to rollback.
        if (!self.usedAllocators) {
            self.usedAllocators = [[NSMutableArray alloc] init];
        }
        if (![self.usedAllocators containsObject:allocator]) {
            [self.usedAllocators addObject:allocator];
        }
        if (allocator.next < allocator.last) {
            DDLogVerbose(@"%@ allocateIdWithTable: %d -> %ld", LOG_TAG, table, allocator.next + 1);
            return allocator.next++;
        }
        
        long increment = 10;
        NSString *tableName = [TLDatabaseService getTableNameWithTable:table];
        NSString *maxQuery = table != TLDatabaseSequence ? [NSString stringWithFormat:@"SELECT MAX(id) FROM %@", tableName] : nil;
        while (true) {
            if (allocator.next == 0) {
                // Get the max ID used by looking at the target table: it happened that there was
                // some inconsistency between some target table and the sequence table.  This should
                // not occur but we check and recover from that the first time we allocate an ID.
                // There is no `sequence` table and a query on the descriptor table would need to take
                // into account the conversation and would be expensive, use 0 for that.
                // Add 1 to avoid re-using the MAX(id).
                long maxId = 1 + (maxQuery ? [self.database longForQuery:maxQuery] : 0);
                FMResultSet *resultSet = [self.database executeQuery:@"SELECT id FROM sequence WHERE name=?", tableName];
                if (resultSet && [resultSet next]) {
                    allocator.last = [resultSet longForColumnIndex:0];
                    // Use the max between the MAX(id) and the value of the sequence allocator.
                    if (allocator.last > maxId) {
                        allocator.next = allocator.last;
                    } else {
                        allocator.next = maxId;
                    }
                    [resultSet close];
                } else {
                    [resultSet close];
                    
                    // Start a new sequence at maxId excluding 0 to prevent using default long values.
                    NSNumber *sequenceId = [NSNumber numberWithLong:maxId + increment];
                    BOOL result = [self.database executeUpdate:@"INSERT INTO sequence (name, id) VALUES(?, ?)", tableName, sequenceId];
                    if (result) {
                        allocator.next = maxId;
                        allocator.last = sequenceId.longValue;
                        DDLogVerbose(@"%@ allocateIdWithTable: %d -> %ld", LOG_TAG, table, allocator.next + 1);
                        return allocator.next++;
                    }
                }
            }
            
            if (allocator.last > 0) {
                NSNumber *nextSequence = [NSNumber numberWithLong:allocator.next + increment];
                NSNumber *currentSequence = [NSNumber numberWithLong:allocator.last];
                BOOL result = [self.database executeUpdate:@"UPDATE sequence SET id=? WHERE name=? AND id=?", nextSequence, tableName, currentSequence];
                if (result) {
                    if ([self.database changes] != 0) {
                        allocator.last = nextSequence.longValue;
                        DDLogVerbose(@"%@ allocateIdWithTable: %d -> %ld", LOG_TAG, table, allocator.next + 1);
                        return allocator.next++;
                    }
                }
            }
            allocator.last = 0;
            allocator.next = 0;
        }
    }
    return 0;
}

- (BOOL)hasTableWithName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ hasTableWithName: %@", LOG_TAG, name);
    
    @synchronized (self.databaseService) {
        return [self.database longForQuery:@"SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?", name] != 0;
    }
}

- (void)deleteWithObject:(nonnull id<TLDatabaseObject>)object {
    DDLogVerbose(@"%@ deleteWithObject: %@", LOG_TAG, object);
    
    TLDatabaseIdentifier *identifier = object.identifier;
    NSString *tableName = [TLDatabaseService getTableNameWithTable:[identifier databaseTable]];
    if (tableName) {
        @synchronized (self.databaseService) {
            [self.database executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE id=?", tableName], [identifier identifierNumber]];
            [self.databaseService evictCacheWithIdentifier:identifier];
        }
    }
}

- (void)deleteWithId:(nonnull NSUUID*)objectId table:(TLDatabaseTable) table {
    DDLogVerbose(@"%@ deleteWithId: %@ table: %d", LOG_TAG, objectId, table);
    
    NSString *tableName = [TLDatabaseService getTableNameWithTable:table];
    if (tableName) {
        @synchronized (self.databaseService) {
            [self.database executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE uuid=?", tableName], [objectId toString]];
            id<TLDatabaseObject> object = [self.databaseService getCacheWithObjectId:objectId];
            if (object) {
                [self.databaseService evictCacheWithIdentifier:object.identifier];
            }
        }
    }
}

- (void)deleteWithList:(nonnull NSArray<NSNumber *> *)list table:(TLDatabaseTable)table {
    DDLogVerbose(@"%@ deleteWithList: %@ table: %d", LOG_TAG, list, table);
    
    NSString *tableName = [TLDatabaseService getTableNameWithTable:table];
    if (tableName) {
        @synchronized (self.databaseService) {
            for (NSNumber *databaseId in list) {
                [self.database executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE id=?", tableName], databaseId];
            }
        }
    }
}

- (void)deleteWithDatabaseId:(int64_t)databaseId table:(TLDatabaseTable)table {
    DDLogVerbose(@"%@ deleteWithDatabaseId: %lld table: %d", LOG_TAG, databaseId, table);
    
    NSString *tableName = [TLDatabaseService getTableNameWithTable:table];
    if (tableName) {
        @synchronized (self.databaseService) {
            [self.database executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE id=?", tableName], [NSNumber numberWithLongLong:databaseId]];
        }
    }
}

- (void)deleteImageWithId:(nullable TLImageId *)imageId {
    DDLogVerbose(@"%@ deleteImageWithId: %@", LOG_TAG, imageId);
    
    [self.databaseService.imagesCleaner deleteImageWithTransaction:self imageId:imageId];
}

- (void)deleteNotificationsWithSubjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId descriptorId:(nullable NSNumber *)descriptorId {
    DDLogVerbose(@"%@ deleteNotificationsWithSubjectId: %@ twincodeId: %@ descriptorId: %@", LOG_TAG, subjectId, twincodeId, descriptorId);
    
    [self.databaseService.notificationsCleaner deleteNotificationsWithTransaction:self subjectId:subjectId twincodeId:twincodeId descriptorId:descriptorId];
}

- (void)deleteConversationsWithSubjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId {
    DDLogVerbose(@"%@ deleteConversationsWithSubjectId: %@ twincodeId: %@", LOG_TAG, subjectId, twincodeId);
    
    [self.databaseService.conversationsCleaner deleteConversationsWithTransaction:self subjectId:subjectId twincodeId:twincodeId];
}

- (void)deleteTwincodeWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@ deleteTwincodeWithTwincodeOutbound: %@", LOG_TAG, twincodeOutbound);
    
    [self.databaseService.twincodesCleaner deleteTwincodeWithTransaction:self twincodeOutbound:twincodeOutbound];
}

- (BOOL)storeAvatarWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@ storeAvatarWithTwincode: %@ attributes: %@", LOG_TAG, twincodeOutbound, attributes);
    
    if (!attributes) {
        return nil;
    }
    
    TLAttributeNameValue *image = [TLAttributeNameValue getAttributeWithName:TL_TWINCODE_AVATAR_ID list:attributes];
    if (!image) {
        return nil;
    }
    
    if ([image.value isKindOfClass:[TLExportedImageId class]]) {
        twincodeOutbound.avatarId = (TLImageId *)image.value;
    } else if ([image.value isKindOfClass:[NSUUID class]]) {
        NSObject *avatarId = [TLDatabaseService toObjectWithUUID:(NSUUID *)image.value];
        long imageId = [self.database longForQuery:@"SELECT id FROM image WHERE uuid=?", avatarId];
        if (imageId == 0) {
            imageId = [self allocateIdWithTable:TLDatabaseTableImage];
            int64_t creationDate = [[NSDate date] timeIntervalSince1970] * 1000;
            [self executeUpdate:@"INSERT INTO image (id, uuid, creationDate, flags) VALUES(?, ?, ?, 5)", [NSNumber numberWithLong:imageId], avatarId, [NSNumber numberWithLongLong:creationDate]];
        } else {
            TLImageId *currentAvatarId = twincodeOutbound.avatarId;
            if (currentAvatarId && currentAvatarId.localId == imageId) {
                return NO;
            }
        }
        twincodeOutbound.avatarId = [[TLImageId alloc] initWithLocalId:imageId];
    } else {
        return NO;
    }
    return YES;
}

- (nullable TLTwincodeInbound *)storeTwincodeInboundWithTwincode:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ storeTwincodeInboundWithTwincode: %@ twincodeOutbound: %@ twincodeFactoryId: %@", LOG_TAG, twincodeId, twincodeOutbound, twincodeFactoryId);
    
    long ident = [self allocateIdWithTable:TLDatabaseTableTwincodeInbound];
    id<TLTwincodeObjectFactory> factory = self.databaseService.twincodeInboundFactory;
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ident factory:factory];
    return (TLTwincodeInbound *)[factory storeObjectWithTransaction:self identifier:identifier twincodeId:twincodeId attributes:attributes flags:0 modificationDate:modificationDate refreshPeriod:0 refreshDate:0 refreshTimestamp:0 initialize:^(id<TLDatabaseObject> object) {
        TLTwincodeInbound *twincodeInbound = (TLTwincodeInbound *)object;
        
        twincodeInbound.twincodeOutbound = twincodeOutbound;
        twincodeInbound.factoryId = twincodeFactoryId;
    }];
}

- (nullable TLTwincodeOutbound *)storeTwincodeOutboundWithTwincode:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes flags:(int)flags modificationDate:(int64_t)modificationDate refreshPeriod:(int64_t)refreshPeriod refreshDate:(int64_t)refreshDate refreshTimestamp:(int64_t)refreshTimestamp {
    DDLogVerbose(@"%@ storeTwincodeOutboundWithTwincode: %@", LOG_TAG, twincodeId);
    
    long ident = [self allocateIdWithTable:TLDatabaseTableTwincodeOutbound];
    id<TLTwincodeObjectFactory> factory = self.databaseService.twincodeOutboundFactory;
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ident factory:factory];
    return (TLTwincodeOutbound *)[factory storeObjectWithTransaction:self identifier:identifier twincodeId:twincodeId attributes:attributes flags:flags modificationDate:modificationDate refreshPeriod:refreshPeriod refreshDate:refreshDate refreshTimestamp:refreshTimestamp initialize:^(id<TLDatabaseObject> object) {
        TLTwincodeOutbound *twincodeOutbound = (TLTwincodeOutbound *)object;
        [self storeAvatarWithTwincode:twincodeOutbound attributes:attributes];
    }];
}

- (nullable TLTwincodeOutbound *)loadOrStoreTwincodeOutboundId:(nonnull NSUUID *)twincodeId {
    DDLogVerbose(@"%@ loadOrStoreTwincodeOutboundId: %@", LOG_TAG, twincodeId);
    
    TLTwincodeOutbound *twincodeOutbound = [self.databaseService loadTwincodeOutboundWithTwincodeId:twincodeId];
    if (twincodeOutbound) {
        return twincodeOutbound;
    }
    
    long ident = [self allocateIdWithTable:TLDatabaseTableTwincodeOutbound];
    id<TLTwincodeObjectFactory> factory = self.databaseService.twincodeOutboundFactory;
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ident factory:factory];
    NSMutableArray<TLAttributeNameValue *> *attributes = [[NSMutableArray alloc] init];
    return (TLTwincodeOutbound *)[factory storeObjectWithTransaction:self identifier:identifier twincodeId:twincodeId attributes:attributes flags:FLAG_NEED_FETCH modificationDate:0 refreshPeriod:TL_REFRESH_PERIOD refreshDate:0 refreshTimestamp:0 initialize:^(id<TLDatabaseObject> object) {
        TLTwincodeOutbound *twincodeOutbound = (TLTwincodeOutbound *)object;
        
        // We store this twincode without information: we need to fetch them later from the server.
        [twincodeOutbound needFetch];
    }];
}

- (void)saveSecretKeyWithKeyId:(nonnull NSNumber *)keyId keyIndex:(int)keyIndex secretKey:(nonnull NSData *)secretKey now:(nonnull NSNumber *)now {
    DDLogVerbose(@"%@ saveSecretKeyWithKeyId: %@ keyIndex: %d secretKey: %@ now: %@", LOG_TAG, keyId, keyIndex, secretKey, now);

    // Either insert or update the secret key.
    // Flags are always 0 and peerTwincodeId is always NULL because this is the peer secret.
    // Note: we cannot use the insert() to detect if the row existed because the secretKeys table
    // is using a primary key on two columns and SQLite is using a rowid as primary column, hence
    // it will always successfully insert any row.
    long hasSecret = [self longForQuery:@"SELECT COUNT(id) FROM secretKeys WHERE id=? AND peerTwincodeId IS NULL", keyId];
    if (hasSecret == 0) {
        if (keyIndex == 1) {
            [self executeUpdate:@"INSERT OR REPLACE INTO secretKeys (id, peerTwincodeId, creationDate, modificationDate, secretUpdateDate, secret1) values(?, ?, ?, ?, ?, ?)", keyId, [NSNull alloc], now, now, now, [TLDatabaseService toObjectWithData:secretKey]];
        } else {
            [self executeUpdate:@"INSERT OR REPLACE INTO secretKeys (id, peerTwincodeId, creationDate, modificationDate, secretUpdateDate, secret2) values(?, ?, ?, ?, ?, ?)", keyId, [NSNull alloc], now, now, now, [TLDatabaseService toObjectWithData:secretKey]];
        }
    } else {
        if (keyIndex == 1) {
            [self executeUpdate:@"UPDATE secretKeys SET secretUpdateDate=?, secret1=? WHERE id=? AND peerTwincodeId IS NULL", now, [TLDatabaseService toObjectWithData:secretKey], keyId];

        } else {
            [self executeUpdate:@"UPDATE secretKeys SET secretUpdateDate=?, secret2=? WHERE id=? AND peerTwincodeId IS NULL", now, [TLDatabaseService toObjectWithData:secretKey], keyId];
        }
    }
}

- (void)storePublicKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound flags:(int)flags pubSigningKey:(nonnull NSData *)pubSigningKey pubEncryptionKey:(nullable NSData *)pubEncryptionKey keyIndex:(int)keyIndex  secretKey:(nullable NSData *)secretKey {
    DDLogVerbose(@"%@ storePublicKeyWithTwincode: %@ flags: %d pubSigningKey: %@ keyIndex: %d", LOG_TAG, twincodeOutbound, flags, pubSigningKey, keyIndex);
    
    NSNumber *keyId = [twincodeOutbound.identifier identifierNumber];
    NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
    NSObject *encryptionKey = [TLDatabaseService toObjectWithData:pubEncryptionKey];
    [self executeUpdate:@"INSERT OR REPLACE INTO twincodeKeys (id, creationDate, modificationDate, flags, signingKey, encryptionKey) VALUES(?, ?, ?, ?, ?, ?)", keyId, now, now, [NSNumber numberWithInt:flags], pubSigningKey, encryptionKey];

    [self saveSecretKeyWithKeyId:keyId keyIndex:keyIndex secretKey:secretKey now:now];
}

- (void)updateTwincodeEncryptFlagsWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound now:(nonnull NSNumber *)now {
    DDLogVerbose(@"%@ updateTwincodeEncryptFlagsWithTwincode: %@ peerTwincodeOutbound: %@", LOG_TAG, twincodeOutbound, peerTwincodeOutbound);
    
    NSNumber *twincodeId = [twincodeOutbound.identifier identifierNumber];
    NSNumber *peerId = [peerTwincodeOutbound.identifier identifierNumber];

    // Check if the FLAG_ENCRYPT flags is set on the peer twincode:
    // - we must have the { <twincode>, <peer-twincode> } key association,
    // - we must know the peer secret { <peer-twincode>, null } association.
    long flags = [self longForQuery:@"SELECT s.flags"
                          " FROM secretKeys AS s, secretKeys AS peer"
                          " WHERE s.id=? AND s.peerTwincodeId=? AND peer.id=s.peerTwincodeId AND peer.secret1 IS NOT NULL", twincodeId, peerId];
    if ((flags & (TLCryptoServiceUseSecret1 | TLCryptoServiceUseSecret2)) != 0) {
        // Now, make sure our twincode has FLAG_ENCRYPT set.
        int twincodeFlags = twincodeOutbound.flags;
        if ((twincodeFlags & FLAG_ENCRYPT) == 0) {
            twincodeFlags |= FLAG_ENCRYPT;
                    
            [self executeUpdate:@"UPDATE twincodeOutbound SET flags=?, modificationDate=? WHERE id=?", [NSNumber numberWithInt:twincodeFlags], now, twincodeId];
            twincodeOutbound.flags = twincodeFlags;
            twincodeOutbound.modificationDate = now.longLongValue;
        }

        // Likewise for the peer twincode.
        int peerTwincodeFlags = peerTwincodeOutbound.flags;
        if ((peerTwincodeFlags & FLAG_ENCRYPT) == 0) {
            peerTwincodeFlags |= FLAG_ENCRYPT;
                    
            [self executeUpdate:@"UPDATE twincodeOutbound SET flags=?, modificationDate=? WHERE id=?", [NSNumber numberWithInt:peerTwincodeFlags], now, peerId];
            peerTwincodeOutbound.flags = peerTwincodeFlags;
            peerTwincodeOutbound.modificationDate = now.longLongValue;
        }
    }
}

- (nullable FMResultSet *)executeQuery:(nonnull NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    FMResultSet *result = [self.database executeQuery:sql withVAList:args];
    
    va_end(args);
    return result;
}

- (nullable FMResultSet *)executeWithQuery:(nonnull TLQueryBuilder *)query {
    
    return [self.database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
}

- (long)longForQuery:(nonnull NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    FMResultSet *result = [self.database executeQuery:sql withVAList:args];
    
    va_end(args);
    if (!result) {
        return 0;
    }
    long value;
    if (![result next]) {
        value = 0;
    } else {
        value = [result longForColumnIndex:0];
    }
    [result close];
    return value;
}

- (nonnull NSMutableArray<NSUUID *> *)listUUIDWithSQL:(nonnull NSString *)sql, ... {
    va_list args;
    va_start(args, sql);
    
    FMResultSet *resultSet = [self.database executeQuery:sql withVAList:args];
    
    va_end(args);
    if (!resultSet) {
        return [[NSMutableArray alloc] init];
    }
    
    NSMutableArray<NSUUID *> *result = [[NSMutableArray alloc] init];
    while ([resultSet next]) {
        NSUUID *uuid = [resultSet uuidForColumnIndex:0];
        if (uuid) {
            [result addObject:uuid];
        }
    }
    [resultSet close];
    return result;
}

- (nonnull NSMutableArray<NSNumber *> *)listIdsWithSQL:(nonnull NSString *)sql, ...{
    va_list args;
    va_start(args, sql);
    
    FMResultSet *resultSet = [self.database executeQuery:sql withVAList:args];
    
    va_end(args);
    if (!resultSet) {
        return [[NSMutableArray alloc] init];
    }
    
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] init];
    while ([resultSet next]) {
        [result addObject:[NSNumber numberWithLong:[resultSet longForColumnIndex:0]]];
    }
    [resultSet close];
    return result;
}

- (void)executeUpdate:(nonnull NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    BOOL result = [self.database executeUpdate:sql withVAList:args];
    
    va_end(args);
    
    if (!result) {
        NSError *error = [self.database lastError];
        
        DDLogError(@"%@ executeUpdate failed: %@", LOG_TAG, error);
        DDLogError(@"%@ SQL: %@", LOG_TAG, sql);
        if (!error) {
            @throw [TLDatabaseErrorException createWithReason:[NSString stringWithFormat:@"SQL update %@ no-error", sql] error:error];
            
        } else if (error.code == SQLITE_FULL) {
            @throw [TLDatabaseFullException createWithReason:error.domain userInfo:error.userInfo];
            
        } else {
            TL_ASSERTION(self.databaseService.twinlife, [TLDatabaseAssertPoint DATABASE_UPDATE_ERROR], [TLAssertValue initWithNSError:error], [TLAssertValue initWithLength:sql.length], nil);
            @throw [TLDatabaseErrorException createWithReason:[NSString stringWithFormat:@"SQL update %@ error: %@", sql, error] error:error];
        }
    }
}

- (void)createSchemaWithSQL:(nonnull NSString *)sql {
    DDLogVerbose(@"%@ createSchemaWithSQL: %@", LOG_TAG, sql);
    
    [self executeUpdate:sql];
}

- (int)changes {
    DDLogVerbose(@"%@ changes", LOG_TAG);
    
    return [self.database changes];
}

- (void)commit {
    
    [self.database commit];
    self.usedAllocators = nil;
    if (!self.database.isInTransaction) {
        [self.database beginTransaction];
    }
}

- (nullable NSError *)lastError {
    
    return [self.database lastError];
}

- (void)dropTable:(nonnull NSString *)name {
    DDLogVerbose(@"%@ dropTable %@", LOG_TAG, name);
    
    NSString *dropSql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", name];
    [self.database executeUpdate:dropSql];
}

- (void)rollback {
    DDLogVerbose(@"%@ rollback", LOG_TAG);

    @synchronized (self.databaseService) {
        if (self.usedAllocators) {
            // Force a reload of the allocators because the transaction was aborted
            // and we have allocated some ids, which means the sequence table was
            // not updated either.
            for (TLDatabaseAllocator *allocator in self.usedAllocators) {
                allocator.next = 0;
                allocator.last = 0;
            }
        }
    }
}

@end

//
// Implementation: TLDatabaseService
//

#undef LOG_TAG
#define LOG_TAG @"TLDatabaseService"

@implementation TLDatabaseService

+ (nullable NSString *)getTableNameWithTable:(TLDatabaseTable)table {
    
    switch (table) {
        case TLDatabaseTableTwincodeInbound:
            return @"twincodeInbound";

        case TLDatabaseTableTwincodeOutbound:
            return @"twincodeOutbound";

        case TLDatabaseTableTwincodeKeys:
            return @"twincodeKeys";

        case TLDatabaseTableSecretKeys:
            return @"secretKeys";

        case TLDatabaseTableRepository:
            return @"repository";

        case TLDatabaseTableNotification:
            return @"notification";

        case TLDatabaseTableConversation:
            return @"conversation";

        case TLDatabaseTableDescriptor:
            return @"descriptor";

        case TLDatabaseTableAnnotation:
            return @"annotation";

        case TLDatabaseTableOperation:
            return @"operation";

        case TLDatabaseTableInvitation:
            return @"invitation";

        case TLDatabaseTableImage:
            return @"image";

        case TLDatabaseSequence:
            return @"sequenceId";

        default:
            return nil;
    }
}

+ (nonnull NSObject *)toObjectWithString:(nullable NSString *)value {
    
    return value ? value : [NSNull alloc];
}

+ (nonnull NSObject *)toObjectWithNumber:(nullable NSNumber *)value {
    
    return value != nil ? value : [NSNull alloc];
}

+ (nonnull NSObject *)toObjectWithUUID:(nullable NSUUID *)value {
    
    return value ? [value toString] : [NSNull alloc];
}

+ (nonnull NSObject *)toObjectWithImageId:(nullable TLImageId *)value {
    
    return value ? [NSNumber numberWithLongLong:value.localId] : [NSNull alloc];
}

+ (nonnull NSObject *)toObjectWithTwincodeInbound:(nullable TLTwincodeInbound *)value {
    
    return value ? [value.identifier identifierNumber] : [NSNull alloc];
}

+ (nonnull NSObject *)toObjectWithTwincodeOutbound:(nullable TLTwincodeOutbound *)value {
    
    return value ? [value.identifier identifierNumber] : [NSNull alloc];
}

+ (nonnull NSObject *)toObjectWithObject:(nullable id<TLRepositoryObject>)value {
    
    return value ? [value.identifier identifierNumber] : [NSNull alloc];
}

+ (nonnull NSObject *)toObjectWithData:(nullable NSData *)value {
    
    return value ? value : [NSNull alloc];
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ init", LOG_TAG);

    self = [super init];
    if (self) {
        _twinlife = twinlife;
        _objectCache = [[NSMutableDictionary alloc] initWithCapacity:100];
        _idCache = [[NSMutableDictionary alloc] initWithCapacity:100];
        _serviceProviders = [[NSMutableArray alloc] initWithCapacity:10];
        _transaction = [[TLTransaction alloc] initWithDatabaseService:self];
    }
    return self;
}

- (void)registerWithService:(nonnull TLDatabaseServiceProvider *)service {
    DDLogVerbose(@"%@ registerWithService: %@", LOG_TAG, service);

    [self.serviceProviders addObject:service];
    if ([service conformsToProtocol:@protocol(TLRepositoryObjectLoader)]) {
        self.repositoryObjectLoader = (id<TLRepositoryObjectLoader>) service;
    } else if ([service conformsToProtocol:@protocol(TLNotificationsCleaner)]) {
        self.notificationsCleaner = (id<TLNotificationsCleaner>) service;
    } else if ([service conformsToProtocol:@protocol(TLConversationsCleaner)]) {
        self.conversationsCleaner = (id<TLConversationsCleaner>) service;
    } else if ([service conformsToProtocol:@protocol(TLImagesCleaner)]) {
        self.imagesCleaner = (id<TLImagesCleaner>) service;
    } else if ([service conformsToProtocol:@protocol(TLTwincodesCleaner)]) {
        self.twincodesCleaner = (id<TLTwincodesCleaner>) service;
    }
}

- (void)configureWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ configureWithDatabase: %@", LOG_TAG, database);

    // On some iOS (mostly iPadOS), we are getting transaction failures with SQLCipher that returns
    // the error code 14 (CANTOPEN_FILE) from time to time.  Occurrence is arround 0.001%.
    // Try to use the WAL mode which appears to be recommended everywhere...
    [database executeStatements:@"PRAGMA journal_mode=WAL;"];

    // Reduce to 500 pages (2Mb) the WAL autocheckpoint
    [database executeStatements:@"PRAGMA wal_autocheckpoint=500;"];

    // Clear content in database pages when rows are deleted.
    [database executeStatements:@"PRAGMA secure_delete=ON;"];
}

- (void)onCreateWithDatabaseQueue:(nonnull FMDatabaseQueue *)databaseQueue version:(int)version{
    DDLogVerbose(@"%@ onCreateWithDatabaseQueue: %@", LOG_TAG, databaseQueue);

    self.databaseQueue = databaseQueue;
    [databaseQueue inTransaction:^(FMDatabase *database, BOOL *rollback) {
        self.transaction.database = database;
        @try {
            [self configureWithDatabase:database];
            [self.transaction createSchemaWithSQL:SEQUENCE_TABLE_CREATE];
            for (TLDatabaseServiceProvider *serviceProvider in self.serviceProviders) {
                [serviceProvider onCreateWithTransaction:self.transaction];
            }
            // PRAGMA user_version=version
            self.transaction.database.userVersion = version;
            [self.transaction commit];
        } @catch (NSException *exception) {
            *rollback = YES;
            DDLogError(@"%@ exception: %@", LOG_TAG, exception);
        }
    }];
}

- (void)onOpenWithDatabaseQueue:(nonnull FMDatabaseQueue *)databaseQueue {
    DDLogVerbose(@"%@ onOpenWithDatabaseQueue: %@", LOG_TAG, databaseQueue);
    
    self.databaseQueue = databaseQueue;
    [databaseQueue inDatabase:^(FMDatabase *database) {
        self.transaction.database = database;
        // database.traceExecution = YES;
        [self configureWithDatabase:database];

        // Force a reload of the allocators because the NotificationServiceExtension or
        // the application could have allocated some ids and we need sequential increment
        // of database id for Operation and Descriptor at least.
        for (TLDatabaseAllocator *allocator in self.transaction.allocatorIds) {
            allocator.next = 0;
            allocator.last = 0;
        }

        // If we were suspended and the caches are enabled, we have to reload the objects
        // that were modified by the NotificationServiceExtension.
        int64_t lastSuspendDate = self.twinlife.lastSuspendDate;
        if (lastSuspendDate > 0 && self.twinlife.twinlifeConfiguration.enableCaches) {
            int reloadCount = 0;

            for (TLDatabaseServiceProvider *serviceProvider in self.serviceProviders) {
                reloadCount += [serviceProvider onResumeWithDatabase:database lastSuspendDate:lastSuspendDate];
            }
            DDLogError(@"%@ reloaded %d objects", LOG_TAG, reloadCount);
        }
    }];

    for (TLDatabaseServiceProvider *serviceProvider in self.serviceProviders) {
        [serviceProvider onOpen];
    }
}

/// Open the database and make a migration from the old version to the new one.
- (TLBaseServiceErrorCode)onUpgradeWithDatabaseQueue:(nonnull FMDatabaseQueue *)databaseQueue oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithDatabaseQueue: %@ oldVersion: %d newVersion: %d", LOG_TAG, databaseQueue, oldVersion, newVersion);

    __block TLBaseServiceErrorCode result = TLBaseServiceErrorCodeSuccess;
    self.databaseQueue = databaseQueue;
    [databaseQueue inDatabase:^(FMDatabase *database) {
        self.transaction.database = database;
        [self configureWithDatabase:database];
    }];

    if (oldVersion < 20) {
        // Migrate old conversationId table to the new sequence table and change some names:
        // localId     -> conversation
        // operationId -> operation
        result = [self inTransaction:^(TLTransaction *transaction) {
            [transaction dropTable:@"directoryContext"];
            [transaction dropTable:@"directoryNode"];
            [transaction dropTable:@"repositoryFileObject"];
            [transaction dropTable:@"twincodeFactoryTwincodeFactory"];
            [transaction dropTable:@"twincodeSwitchTwincodeSwitch"];
            
            [transaction createSchemaWithSQL:SEQUENCE_TABLE_CREATE];
            if ([transaction hasTableWithName:@"conversationId"]) {
                FMResultSet *resultSet = [transaction executeQuery:@"SELECT key, id FROM conversationId"];
                if (resultSet) {
                    while ([resultSet next]) {
                        NSString *name = [resultSet stringForColumnIndex:0];
                        long value = [resultSet longLongIntForColumnIndex:1];
                        
                        if ([name isEqualToString:@"localId"]) {
                            name = [TLDatabaseService getTableNameWithTable:TLDatabaseTableConversation];
                        } else if ([name isEqualToString:@"operationId"]) {
                            name = [TLDatabaseService getTableNameWithTable:TLDatabaseTableOperation];
                        }
                        [self.transaction executeUpdate:@"INSERT INTO sequence (name, id) VALUES(?, ?)", name, [NSNumber numberWithLongLong:value]];
                    }
                    [resultSet close];
                }
                [self.transaction dropTable:@"conversationId"];
            }

            [self.transaction commit];
        }];
        if (result != TLBaseServiceErrorCodeSuccess) {
            return result;
        }
    }

    // Migrate each service in a specific order and commit transaction after each service migration.
    // If we are interrupted in the middle, the service must be prepared to re-do or do nothing at
    // a next application restart.
    for (TLDatabaseServiceProvider *serviceProvider in self.serviceProviders) {
        result = [self inTransaction:^(TLTransaction *transaction) {
            [serviceProvider onUpgradeWithTransaction:self.transaction oldVersion:oldVersion newVersion:newVersion];
            [self.transaction commit];
        }];
        if (result != TLBaseServiceErrorCodeSuccess) {
            break;
        }
    }
    return result;
}

- (void)onCloseDatabase {
    DDLogVerbose(@"%@ onCloseDatabase", LOG_TAG);

    @synchronized (self) {
        // When caches are disabled, clear the cached before suspending to release the memory.
        if (!self.twinlife.twinlifeConfiguration.enableCaches) {
            [self.idCache removeAllObjects];
            [self.objectCache removeAllObjects];
        }
        self.databaseQueue = nil;
        self.transaction.database = nil;
    }
}

- (void)syncDatabase {
    DDLogVerbose(@"%@ syncDatabase", LOG_TAG);

    // Before a database backup/migration, we must checkpoint the WAL file
    // and also change the journal mode to DELETE to put the database in correct state.
    TL_DECL_START_MEASURE(startTime)
    [self.databaseQueue inDatabase:^(FMDatabase *database) {
        [database executeStatements:@"PRAGMA wal_checkpoint(FULL)"];
        [database executeStatements:@"PRAGMA journal_mode = DELETE"];
    }];
    TL_END_MEASURE(startTime, @"syncDatabase WAL checkpoint, switch to DELETE")
}

- (nullable id<TLDatabaseObject>)getCacheWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier {
    DDLogVerbose(@"%@ getCacheWithIdentifier: %@", LOG_TAG, identifier);

    @synchronized (self) {
        return self.objectCache[identifier];
    }
}

- (nullable id<TLDatabaseObject>)getCacheWithObjectId:(nonnull NSUUID *)objectId {
    DDLogVerbose(@"%@ getCacheWithObjectId: %@", LOG_TAG, objectId);

    @synchronized (self) {
        TLDatabaseIdentifier *identifier = self.idCache[objectId];
        if (identifier) {
            return self.objectCache[identifier];
        } else {
            return nil;
        }
    }
}

- (void)putCacheWithObject:(nonnull id<TLDatabaseObject>)object {
    DDLogVerbose(@"%@ putCacheWithObject: %@", LOG_TAG, object);

    TLDatabaseIdentifier *identifier = [object identifier];
    NSUUID *objectId = [object objectId];
    @synchronized (self) {
        if (objectId) {
            [self.idCache setObject:identifier forKey:objectId];
        }
        [self.objectCache setObject:object forKey:identifier];
    }
}

- (void)evictCacheWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier {
    DDLogVerbose(@"%@ evictCacheWithIdentifier: %@", LOG_TAG, identifier);

    @synchronized (self) {
        id<TLDatabaseObject> object = self.objectCache[identifier];
        [self.objectCache removeObjectForKey:identifier];
        if (object) {
            NSUUID *objectId = [object objectId];
            if (objectId) {
                [self.idCache removeObjectForKey:objectId];
            }
        }
    }
}

- (void)evictCacheWithObjectId:(nullable NSUUID *)objectId {
    DDLogVerbose(@"%@ evictCacheWithObjectId: %@", LOG_TAG, objectId);

    if (objectId) {
        @synchronized (self) {
            TLDatabaseIdentifier *identifier = self.idCache[objectId];
            if (identifier) {
                id<TLDatabaseObject> object = self.objectCache[identifier];
                if (object) {
                    [self.objectCache removeObjectForKey:identifier];
                }
                [self.idCache removeObjectForKey:objectId];
            }
        }
    }
}

- (nullable TLTwincodeInbound *)loadTwincodeInboundWithResultSet:(nonnull FMResultSet *)resultSet offset:(int)offset {
    DDLogVerbose(@"%@ loadTwincodeInboundWithResultSet: %@ offset: %d", LOG_TAG, resultSet, offset);
    
    if ([resultSet columnIndexIsNull:offset]) {
        return nil;
    }

    TLTwincodeInbound *result;
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:[resultSet longForColumnIndex:offset] factory:(id<TLDatabaseObjectIdentification>)self.twincodeInboundFactory];
    @synchronized (self) {
        id<TLDatabaseObject> object = self.objectCache[identifier];
        if (!object || ![(NSObject *)object isKindOfClass:[TLTwincodeInbound class]]) {
            object = [self.twincodeInboundFactory createObjectWithIdentifier:identifier cursor:resultSet offset:offset + 1];
            NSUUID *objectId = [object objectId];
            if (objectId) {
                [self.idCache setObject:identifier forKey:objectId];
            }
            [self.objectCache setObject:object forKey:identifier];
        } else {
            [self.twincodeInboundFactory loadWithObject:object cursor:resultSet offset:offset + 1];
        }
        result = (TLTwincodeInbound *)object;
    }
    return result;
}

- (nullable TLTwincodeOutbound *)loadTwincodeOutboundWithResultSet:(nonnull FMResultSet *)resultSet offset:(int)offset {
    DDLogVerbose(@"%@ loadTwincodeOutboundWithResultSet: %@ offset: %d", LOG_TAG, resultSet, offset);
    
    if ([resultSet columnIndexIsNull:offset]) {
        return nil;
    }

    TLTwincodeOutbound *result;
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:[resultSet longForColumnIndex:offset] factory:(id<TLDatabaseObjectIdentification>)self.twincodeOutboundFactory];
    @synchronized (self) {
        id<TLDatabaseObject> object = self.objectCache[identifier];
        if (!object || ![(NSObject *)object isKindOfClass:[TLTwincodeOutbound class]]) {
            object = [self.twincodeOutboundFactory createObjectWithIdentifier:identifier cursor:resultSet offset:offset + 1];
            NSUUID *objectId = [object objectId];
            if (objectId) {
                [self.idCache setObject:identifier forKey:objectId];
            }
            [self.objectCache setObject:object forKey:identifier];
        } else {
            [self.twincodeOutboundFactory loadWithObject:object cursor:resultSet offset:offset + 1];
        }
        result = (TLTwincodeOutbound *)object;
    }
    return result;
}

- (nullable TLTwincodeInbound *)loadTwincodeInboundWithTwincodeId:(nonnull NSUUID *)twincodeId {
    DDLogVerbose(@"%@ loadTwincodeInboundWithTwincodeId: %@", LOG_TAG, twincodeId);
    
    @synchronized (self) {
        TLDatabaseIdentifier *identifier = self.idCache[twincodeId];
        if (identifier) {
            id<TLDatabaseObject> object = self.objectCache[identifier];
            if (object && [(NSObject *)object isKindOfClass:[TLTwincodeInbound class]]) {
                return (TLTwincodeInbound *)object;
            }
        }
    }

    __block TLTwincodeInbound *twincodeInbound = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (database) {
            FMResultSet *resultSet = [database executeQuery:@"SELECT ti.id, ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes FROM twincodeInbound AS ti WHERE ti.twincodeId = ?", [twincodeId toString]];
            if (resultSet) {
                if ([resultSet next]) {
                    twincodeInbound = [self loadTwincodeInboundWithResultSet:resultSet offset:0];
                }
                [resultSet close];
            }
        }
    }];
    return twincodeInbound;
}

- (nullable TLTwincodeOutbound *)loadTwincodeOutboundWithTwincodeId:(nonnull NSUUID *)twincodeId {
    DDLogVerbose(@"%@ loadTwincodeOutboundWithTwincodeId: %@", LOG_TAG, twincodeId);
    
    @synchronized (self) {
        TLDatabaseIdentifier *identifier = self.idCache[twincodeId];
        if (identifier) {
            id<TLDatabaseObject> object = self.objectCache[identifier];
            if (object && [(NSObject *)object isKindOfClass:[TLTwincodeOutbound class]]) {
                return (TLTwincodeOutbound *)object;
            }
        }
    }

    __block TLTwincodeOutbound *twincodeOutbound = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (database) {
            FMResultSet *resultSet = [database executeQuery:@"SELECT"
                                      " twout.id, twout.twincodeId, twout.modificationDate, twout.name,"
                                      " twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags"
                                      " FROM twincodeOutbound AS twout"
                                      " WHERE twout.twincodeId = ?", [twincodeId toString]];
            if (resultSet) {
                if ([resultSet next]) {
                    twincodeOutbound = [self loadTwincodeOutboundWithResultSet:resultSet offset:0];
                }
                [resultSet close];
            }
        }
    }];
    return twincodeOutbound;
}

- (nullable TLTwincodeOutbound *)loadTwincodeOutboundWithId:(long)databaseId {
    DDLogVerbose(@"%@ loadTwincodeOutboundWithId: %ld", LOG_TAG, databaseId);
    
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:databaseId factory:self.twincodeOutboundFactory];
    @synchronized (self) {
        id<TLDatabaseObject> object = self.objectCache[identifier];
        if (object && [(NSObject *)object isKindOfClass:[TLTwincodeOutbound class]]) {
            return (TLTwincodeOutbound *)object;
        }
    }

    TLTwincodeOutbound *twincodeOutbound = nil;
    FMResultSet *resultSet = [self.transaction.database executeQuery:@"SELECT"
                                      " twout.id, twout.twincodeId, twout.modificationDate, twout.name,"
                                      " twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags"
                                      " FROM twincodeOutbound AS twout"
                              " WHERE twout.id = ?", [NSNumber numberWithLong:databaseId]];
    if (resultSet) {
        if ([resultSet next]) {
            twincodeOutbound = [self loadTwincodeOutboundWithResultSet:resultSet offset:0];
        }
        [resultSet close];
    }
    return twincodeOutbound;
}

- (nullable id<TLRepositoryObject>)loadRepositoryObjectWithId:(long)databaseId schemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ loadRepositoryObjectWithId: %ld schemaId: %@", LOG_TAG, databaseId, schemaId);

    return [self.repositoryObjectLoader loadRepositoryObjectWithId:databaseId schemaId:schemaId];
}

- (TLBaseServiceErrorCode)inTransaction:(__attribute__((noescape)) void (^)(TLTransaction *transaction))block {
    DDLogVerbose(@"%@ inTransaction: %@", LOG_TAG, block);

    __block TLBaseServiceErrorCode result;
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try {
            if (db) {
                block(self.transaction);
                result = TLBaseServiceErrorCodeSuccess;
            } else {
                result = TLBaseServiceErrorCodeDatabaseError;
            }
        } @catch (TLDatabaseErrorException *exception) {
            result = TLBaseServiceErrorCodeDatabaseError;
            *rollback = YES;
            DDLogError(@"%@ exception inTransaction: %@", LOG_TAG, exception);
            [self.transaction rollback];
            [self.twinlife exceptionWithAssertPoint:[TLDatabaseAssertPoint DATABASE_ERROR] exception:exception, [TLAssertValue initWithNumber:exception.code], nil];

        } @catch (TLDatabaseFullException *exception) {
            result = TLBaseServiceErrorCodeNoStorageSpace;
            *rollback = YES;
            DDLogError(@"%@ exception inTransaction: %@", LOG_TAG, exception);
            [self.transaction rollback];

        } @catch (NSException *exception) {
            result = TLBaseServiceErrorCodeLibraryError;
            *rollback = YES;
            DDLogError(@"%@ exception inTransaction: %@", LOG_TAG, exception);
            [self.transaction rollback];
            [self.twinlife exceptionWithAssertPoint:[TLDatabaseAssertPoint EXCEPTION] exception:exception, nil];
        }
    }];
    return result;
}

- (void)inDatabase:(nonnull __attribute__((noescape)) void (^)(FMDatabase *_Nullable db))block {
    DDLogVerbose(@"%@ inDatabase: %@", LOG_TAG, block);

    FMDatabaseQueue *currentSyncQueue = [self.databaseQueue currentSyncQueue];
    if (currentSyncQueue) {
        block(self.transaction.database);
    } else {
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            @try {
                if (db) {
                    block(db);
                }
            } @catch (NSException *exception) {
                DDLogError(@"%@ exception inDatabase: %@", LOG_TAG, exception);
                [self.twinlife exceptionWithAssertPoint:[TLDatabaseAssertPoint EXCEPTION] exception:exception, nil];
            }
        }];
    }
}

- (nonnull NSMutableString *)checkConsistency {
    DDLogVerbose(@"%@ checkConsistency", LOG_TAG);

    __block NSMutableString *content;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        content = [TLDatabaseCheck checkConsistencyWithDatabase:db];
    }];
    return content;
}

@end

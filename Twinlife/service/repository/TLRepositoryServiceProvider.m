/*
 *  Copyright (c) 2015-2024 twinlife SA.
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

#import "TLRepositoryService.h"
#import "TLRepositoryServiceProvider.h"
#import "TLRepositoryServiceImpl.h"
#import "TLTwincodeInboundServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLDataInputStream.h"
#import "TLDataOutputStream.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLFilter.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define DEFAULT_SIZE 512

/**
 * repository table:
 * id INTEGER: local database identifier (primary key)
 * uuid TEXT UNIQUE NOT NULL: object id
 * schemaId TEXT: the object schema id
 * schemaVersion INTEGER: the object schema version
 * creationDate INTEGER NOT NULL: object creation date
 * twincodeInbound INTEGER: the optional twincode inbound local database identifier
 * twincodeOutbound INTEGER: the optional twincode outbound
 * peerTwincodeOutbound INTEGER: the optional peer twincode outbound
 * owner INTEGER: the optional object owner.
 * name TEXT: name attribute
 * description TEXT: description attribute
 * modificationDate INTEGER NOT NULL: object modification date
 * flags INTEGER: various control flags on the object
 * attributes BLOB: other attributes (serialized)
 * stats BLOB: the object stats (serialized)
 * Note:
 * - id, uuid, schemaId, creationDate are readonly.
 */
#define REPOSITORY_CREATE_TABLE \
        @"CREATE TABLE IF NOT EXISTS repository (id INTEGER PRIMARY KEY," \
                " uuid TEXT UNIQUE NOT NULL, schemaId TEXT, schemaVersion INTEGER DEFAULT 0, creationDate INTEGER NOT NULL," \
                " twincodeInbound INTEGER, twincodeOutbound INTEGER, peerTwincodeOutbound INTEGER, owner INTEGER," \
                " name TEXT, description TEXT, modificationDate INTEGER NOT NULL, attributes BLOB, flags INTEGER," \
                " stats BLOB" \
                ")"
/**
 * Index used for owner search with WHERE r.owner=?
 */
#define REPOSITORY_CREATE_INDEX \
        @"CREATE INDEX IF NOT EXISTS idx_repository_owner ON repository (owner)"

#define ALTER_REPOSITORY_OBJECT_ADD_STATS @"ALTER TABLE repositoryObject ADD COLUMN stats BLOB"
#define ALTER_REPOSITORY_OBJECT_ADD_SCHEMAID @"ALTER TABLE repositoryObject ADD COLUMN schemaId TEXT"

//
// Interface: TLRepositoryServiceProvider
//

@interface TLRepositoryObjectFactoryImpl ()

@property (readonly, nonnull) TLDatabaseService *databaseService;
@property (readonly, nonnull) TLRepositoryServiceProvider *serviceProvider;
@property (readonly, nonnull) id<TLRepositoryObjectFactory> factory;
@property (nullable) TLTransaction *currentTransaction;

- (nonnull instancetype)initWithService:(nonnull TLRepositoryServiceProvider *)service database:(nonnull TLDatabaseService *)database factory:(nonnull id<TLRepositoryObjectFactory>)factory;

- (id<TLRepositoryObject>)importWithTransaction:(nonnull TLTransaction *)transaction identifier:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes;

@end

//
// Interface: TLRepositoryServiceProvider ()
//

@interface TLRepositoryServiceProvider ()

@property (readonly, nonnull) TLRepositoryService *repositoryService;
@property (readonly, nonnull) NSMutableArray<TLRepositoryObjectFactoryImpl *> *factories;
@property (readonly, nonnull) NSMutableDictionary<NSUUID *, TLRepositoryObjectFactoryImpl *> *factoryMap;
@property BOOL migrationRunning;

/// Migrate the twincodeOutboundTwincodeOutbound table to the twincodeOutbound new table format.
- (nullable TLTwincodeInbound *)loadLegacyTwincodeInboundWithTransaction:(nonnull TLTransaction *)transaction twincodeId:(nonnull NSUUID *)twincodeInboundId twincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId;

@end

//
// Implementation: TLRepositoryStatInfo
//

@implementation TLRepositoryStatInfo : NSObject

- (nonnull instancetype)initWithObjectStats:(nonnull TLObjectStatImpl *)stats peerTwincodeFlags:(int)peerTwincodeFlags {
    
    self = [super init];
    if (self) {
        _stats = stats;
        _peerTwincodeFlags = peerTwincodeFlags;
    }
    return self;
}

@end

//
// Implementation: TLRepositoryObjectFactoryImpl
//

#define LOG_TAG @"TLRepositoryObjectFactoryImpl"

@implementation TLRepositoryObjectFactoryImpl

- (nonnull instancetype)initWithService:(nonnull TLRepositoryServiceProvider *)service database:(nonnull TLDatabaseService *)database factory:(nonnull id<TLRepositoryObjectFactory>)factory {
    DDLogVerbose(@"%@: initWithService: %@ database: %@ factory: %@", LOG_TAG, service, database, factory);
    
    self = [super init];
    if (self) {
        _serviceProvider = service;
        _databaseService = database;
        _factory = factory;
    }
    return self;
}

/// Give information about the database table that contains the object.
- (TLDatabaseTable)kind {
    
    return TLDatabaseTableRepository;
}

/// The schema ID identifies the object factory in the database.
- (nonnull NSUUID *)schemaId {
    
    return self.factory.schemaId;
}

/// The schema version identifies a specific version of the object representation.
- (int)schemaVersion {
    
    return self.factory.schemaVersion;
}

/// Indicates whether the object is local only or also stored on the server.
- (BOOL)isLocal {
    
    return self.factory.isLocal;
}

- (nullable id<TLDatabaseObject>)createObjectWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ createObjectWithIdentifier: %@ offset: %d", LOG_TAG, identifier, offset);
    
    // r.uuid, r.creationDate, r.name, r.description, r.attributes, r.modificationDate, r.owner
    NSUUID *uuid = [cursor uuidForColumnIndex:offset];
    int64_t creationDate = [cursor longLongIntForColumnIndex:offset + 1];
    NSString *name = [cursor stringForColumnIndex:offset + 2];
    NSString *description = [cursor stringForColumnIndex:offset + 3];
    NSData *content = [cursor dataForColumnIndex:offset + 4];
    int64_t modificationDate = [cursor longLongIntForColumnIndex:offset + 5];
    long ownerId = [cursor longForColumnIndex:offset + 6];
    NSMutableArray<TLAttributeNameValue *> *attributes = [TLBinaryCompactDecoder deserializeWithData:content];
    
    id<TLRepositoryObject> result = [self.factory createObjectWithId:identifier uuid:uuid creationDate:creationDate name:name description:description attributes:attributes modificationDate:modificationDate];
    if (ownerId > 0) {
        id<TLRepositoryObjectFactory> ownerFactory = self.factory.ownerFactory;
        if (ownerFactory) {
            TLRepositoryObjectFactoryImpl *dbOwnerFactory = [self.serviceProvider factoryWithSchemaId:ownerFactory.schemaId];
            if (dbOwnerFactory) {
                TLDatabaseIdentifier *ownerIdentifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ownerId factory:dbOwnerFactory];
                id<TLDatabaseObject> ownerObject = [self.databaseService getCacheWithIdentifier:ownerIdentifier];
                if (!ownerObject) {
                    ownerObject = [self.serviceProvider loadObjectWithFactory:dbOwnerFactory dbId:ownerId uuid:nil];
                }
                if (ownerObject /* && [(NSObject *)ownerObject isKindOfClass:[TLRepositoryObject class]]*/) {
                    [result setOwner:(id<TLRepositoryObject>)ownerObject];
                }
            }
        }
    }
    
    return result;
}

- (BOOL)loadWithObject:(nonnull id<TLDatabaseObject>)object cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ loadWithObject: %@ offset: %d", LOG_TAG, object, offset);
    
    id<TLRepositoryObject> repositoryObject = (id<TLRepositoryObject>)object;
    int64_t modificationDate = [cursor longLongIntForColumnIndex:offset + 5];
    if (repositoryObject.modificationDate == modificationDate) {
        return NO;
    }

    NSString *name = [cursor stringForColumnIndex:offset + 2];
    NSString *description = [cursor stringForColumnIndex:offset + 3];
    NSData *content = [cursor dataForColumnIndex:offset + 4];
    long ownerId = [cursor longForColumnIndex:offset + 6];
    NSMutableArray<TLAttributeNameValue *> *attributes = [TLBinaryCompactDecoder deserializeWithData:content];
    
    [self.factory loadObjectWithObject:repositoryObject name:name description:description attributes:attributes modificationDate:modificationDate];
    if (ownerId > 0 && ![repositoryObject owner]) {
        id<TLRepositoryObjectFactory> ownerFactory = self.factory.ownerFactory;
        if (ownerFactory) {
            TLRepositoryObjectFactoryImpl *dbOwnerFactory = [self.serviceProvider factoryWithSchemaId:ownerFactory.schemaId];
            if (dbOwnerFactory) {
                TLDatabaseIdentifier *ownerIdentifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ownerId factory:dbOwnerFactory];
                id<TLDatabaseObject> ownerObject = [self.databaseService getCacheWithIdentifier:ownerIdentifier];
                if (!ownerObject) {
                    ownerObject = [self.serviceProvider loadObjectWithFactory:dbOwnerFactory dbId:ownerId uuid:nil];
                }
                if (ownerObject /* && [(NSObject *)ownerObject isKindOfClass:[TLRepositoryObject class]]*/) {
                    [repositoryObject setOwner:(id<TLRepositoryObject>)ownerObject];
                }
            }
        }
    }
    return YES;
}

- (void)importWithObject:(nonnull id<TLRepositoryObject>)object twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId twincodeInboundId:(nullable NSUUID *)twincodeInboundId twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId peerTwincodeOutboundId:(nullable NSUUID *)peerTwincodeOutboundId ownerId:(nullable NSUUID *)ownerId {
    DDLogVerbose(@"%@ importWithObject: %@ twincodeFactoryId: %@ twincodeInboundId: %@ twincodeOutboundId: %@ peerTwincodeOutboundId: %@ ownerId: %@", LOG_TAG, object, twincodeFactoryId, twincodeInboundId, twincodeOutboundId, peerTwincodeOutboundId, ownerId);
    
    @try {
        if (twincodeOutboundId) {
            TLTwincodeOutbound *twincodeOutbound = [self.databaseService loadTwincodeOutboundWithTwincodeId:twincodeOutboundId];
            object.twincodeOutbound = twincodeOutbound;
            if (twincodeInboundId) {
                TLTwincodeInbound *twincodeInbound = [self.databaseService loadTwincodeInboundWithTwincodeId:twincodeInboundId];
                
                // The inbound twincode is not in the database but we are doing a database migration.
                // Look for the twincode in the old table and migrate that twincode to the new table.
                if (!twincodeInbound && self.serviceProvider.migrationRunning) {
                    twincodeInbound = [self.serviceProvider loadLegacyTwincodeInboundWithTransaction:self.currentTransaction twincodeId:twincodeInboundId twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId];
                    if (!twincodeInbound) {
                        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
                        twincodeInbound = [self.currentTransaction storeTwincodeInboundWithTwincode:twincodeInboundId twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId attributes:nil modificationDate:now];
                    }
                }
                object.twincodeInbound = twincodeInbound;
            }
        }
        if (peerTwincodeOutboundId) {
            TLTwincodeOutbound *twincodeOutbound = [self.databaseService loadTwincodeOutboundWithTwincodeId:peerTwincodeOutboundId];
            object.peerTwincodeOutbound = twincodeOutbound;
        }
        if (ownerId) {
            id<TLDatabaseObject> ownerObject = [self.databaseService getCacheWithObjectId:ownerId];
            if (!ownerObject) {
                id<TLRepositoryObjectFactory> ownerFactory = self.factory.ownerFactory;
                if (ownerFactory) {
                    TLRepositoryObjectFactoryImpl *dbOwnerFactory = [self.serviceProvider factoryWithSchemaId:ownerFactory.schemaId];
                    if (dbOwnerFactory) {
                        id<TLDatabaseObject> ownerObject = [self.databaseService getCacheWithObjectId:ownerId];
                        if (!ownerObject) {
                            ownerObject = [self.serviceProvider loadObjectWithFactory:dbOwnerFactory dbId:0 uuid:ownerId];
                        }
                        if (ownerObject /* && [(NSObject *)ownerObject isKindOfClass:[TLRepositoryObject class]]*/) {
                            [object setOwner:(id<TLRepositoryObject>)ownerObject];
                        }
                    }
                }
            }
            object.owner = (id<TLRepositoryObject>)ownerObject;
        }
    }
    @catch (NSException *exception) {
        DDLogError(@"%@ import raised exception: %@", LOG_TAG, exception);

    }
}

- (id<TLRepositoryObject>)importWithTransaction:(nonnull TLTransaction *)transaction identifier:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@ importWithTransaction: %@ identifier: %@ uuid: %@ key: %@ creationDate: %lld attributes: %@", LOG_TAG, transaction, identifier, uuid, key, creationDate, attributes);
    
    @try {
        self.currentTransaction = transaction;
        return [self.factory importObjectWithId:identifier importService:self uuid:uuid key:key creationDate:creationDate attributes:attributes];
        
    } @finally {
        self.currentTransaction = nil;
    }
}

- (id<TLRepositoryObject>)saveWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ saveWithIdentifier: %@ uuid: %@ attributes: %@ modificationDate: %lld", LOG_TAG, identifier, uuid, attributes, modificationDate);

    return [self.factory createObjectWithId:identifier uuid:uuid creationDate:modificationDate name:nil description:nil attributes:attributes modificationDate:modificationDate];
}

@end

//
// Implementation: TLRepositoryServiceProvider
//

#undef LOG_TAG
#define LOG_TAG @"RepositoryServiceProvider"

@implementation TLRepositoryServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLRepositoryService *)service database:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@: initWithService: %@ database: %@", LOG_TAG, service, database);
    
    self = [super initWithService:service database:database sqlCreate:REPOSITORY_CREATE_TABLE table:TLDatabaseTableRepository];
    
    if (self) {
        _factories = [[NSMutableArray alloc] initWithCapacity:10];
        _factoryMap = [[NSMutableDictionary alloc] initWithCapacity:10];
        _repositoryService = service;
        _migrationRunning = NO;
    }
    return self;
}

- (void)configureWithFactories:(nonnull NSArray<id<TLRepositoryObjectFactory>> *)factories {
    DDLogVerbose(@"%@: configureWithFactories: %@", LOG_TAG, factories);

    for (id<TLRepositoryObjectFactory> factory in factories) {
        TLRepositoryObjectFactoryImpl *dbFactory = [[TLRepositoryObjectFactoryImpl alloc] initWithService:self database:self.database factory:factory];
        [self.factories addObject:dbFactory];
        [self.factoryMap setObject:dbFactory forKey:factory.schemaId];
    }
}

- (void)onCreateWithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ onCreateWithTransaction: %@", LOG_TAG, transaction);

    [super onCreateWithTransaction:transaction];
    [transaction createSchemaWithSQL:REPOSITORY_CREATE_INDEX];
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);
    
    /*
     * <pre>
     * Database Version 14:
     *  Date: 2022/12/07:
     *   Repair the repositoryObject inconsistency in the key column that is sometimes null.
     *
     * Database Version 7
     *  Date: 2019/01/17
     *
     *  RepositoryService
     *   Update oldVersion [2,6]:
     *    Add column stats BLOB in  repositoryObject
     *    Add column schemaId TEXT in repositoryObject
     *   Update oldVersion [0,1]: reset
     * </pre>
     */
    [super onUpgradeWithTransaction:transaction oldVersion:oldVersion newVersion:newVersion];
    [transaction createSchemaWithSQL:REPOSITORY_CREATE_INDEX];
    if (oldVersion < 20 && [transaction hasTableWithName:@"repositoryObject"]) {
        [self upgrade20WithTransaction:transaction];
    }
}

#pragma mark TLRepositoryObjectLoader

- (nullable id<TLRepositoryObject>)loadRepositoryObjectWithId:(long)databaseId schemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ loadRepositoryObjectWithId: %ld schemaId: %@", LOG_TAG, databaseId, schemaId);
    
    TLRepositoryObjectFactoryImpl *factory = [self factoryWithSchemaId:schemaId];
    if (!factory) {
        return nil;
    }
    
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:databaseId factory:factory];
    id<TLDatabaseObject> dbObject = [self.database getCacheWithIdentifier:identifier];
    if (dbObject) {
        return (id<TLRepositoryObject>) dbObject;
    }
    
    return [self loadObjectWithFactory:factory dbId:databaseId uuid:nil];
}

#pragma mark TLRepositoryServiceProvider

- (nullable TLRepositoryObjectFactoryImpl *)factoryWithSchemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ factoryWithSchemaId: %@", LOG_TAG, schemaId);
    
    return self.factoryMap[schemaId];
}

- (nonnull NSArray<TLRepositoryObjectFactoryImpl *> *)getFactories {
    DDLogVerbose(@"%@ getFactories", LOG_TAG);

    return self.factories;
}

- (nullable id<TLRepositoryObject>)loadObjectWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory dbId:(long)dbId uuid:(nullable NSUUID *)uuid {
    DDLogVerbose(@"%@ loadObjectWithFactory: %@ uuid: %@", LOG_TAG, factory, uuid);
    
    if (uuid) {
        id<TLDatabaseObject> object = [self.database getCacheWithObjectId:uuid];
        if (object != nil) {
            return (id<TLRepositoryObject>) object;
        }
    }

    NSUUID *schemaId = [factory.factory schemaId];
    int mode = [factory.factory twincodeUsage];
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"r.id, r.uuid, r.creationDate,"
                             " r.name, r.description, r.attributes, r.modificationDate, r.owner"];

    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND) != 0) {
        [query appendString:@", twout.id, twout.twincodeId, twout.modificationDate, twout.name, twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND) != 0) {
        [query appendString:@", po.id, po.twincodeId, po.modificationDate, po.name, po.avatarId, po.description, po.capabilities, po.attributes, po.flags"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND) != 0) {
        [query appendString:@", ti.id, ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes"];
    }
    [query appendString:@" FROM repository AS r"];
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND) != 0) {
        [query appendString:@" LEFT JOIN twincodeInbound AS ti on r.twincodeInbound = ti.id"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND) != 0) {
        [query appendString:@" LEFT JOIN twincodeOutbound AS twout on r.twincodeOutbound = twout.id"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND) != 0) {
        [query appendString:@" LEFT JOIN twincodeOutbound AS po on r.peerTwincodeOutbound = po.id"];
    }
    
    if (uuid) {
        [query filterUUID:uuid field:@"r.uuid"];
    } else {
        [query filterLong:dbId field:@"r.id"];
    }
    [query filterUUID:schemaId field:@"r.schemaId"];
    
    __block id<TLRepositoryObject> result = nil;
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            id<TLRepositoryObject> repoObject = [self loadRepositoryObjectWithFactory:factory cursor:resultSet mode:mode offset:0];
            if (repoObject) {
                result = repoObject;
                break;
            }
        }
        [resultSet close];
    }];
    return result;
}

- (nonnull NSArray<id<TLRepositoryObject>> *)listObjectsWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory filter:(nullable TLFilter *)filter {
    DDLogVerbose(@"%@ listObjectsWithFactory: %@ filter: %@", LOG_TAG, factory, filter);
    
    NSUUID *schemaId = [factory.factory schemaId];
    int mode = [factory.factory twincodeUsage];
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"r.id, r.uuid, r.creationDate, r.name,"
                             " r.description, r.attributes, r.modificationDate, r.owner"];

    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND) != 0) {
        [query appendString:@", twout.id, twout.twincodeId, twout.modificationDate, twout.name, twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND) != 0) {
        [query appendString:@", po.id, po.twincodeId, po.modificationDate, po.name, po.avatarId, po.description, po.capabilities, po.attributes, po.flags"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND) != 0) {
        [query appendString:@", ti.id, ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes"];
    }
    [query appendString:@" FROM repository AS r"];
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND) != 0) {
        [query appendString:@" LEFT JOIN twincodeInbound AS ti on r.twincodeInbound = ti.id"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND) != 0) {
        [query appendString:@" LEFT JOIN twincodeOutbound AS twout on r.twincodeOutbound = twout.id"];
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND) != 0) {
        [query appendString:@" LEFT JOIN twincodeOutbound AS po on r.peerTwincodeOutbound = po.id"];
    }
    [query filterUUID:schemaId field:@"r.schemaId"];
    if (filter) {
        [query filterOwner:filter.owner field:@"r.owner"];
    }
    
    __block NSMutableArray<id<TLRepositoryObject>> *result = [[NSMutableArray alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            id<TLRepositoryObject> repoObject = [self loadRepositoryObjectWithFactory:factory cursor:resultSet mode:mode offset:0];
            if (repoObject && (!filter || !filter.acceptWithObject || filter.acceptWithObject(repoObject))) {
                [result addObject:repoObject];
            }
        }
        [resultSet close];
    }];
    
    return result;
}

- (nullable id<TLRepositoryObject>)findObjectWithInboundId:(BOOL)withInboundId uuid:(nonnull NSUUID *)uuid factories:(nonnull NSArray<TLRepositoryObjectFactoryImpl *> *)factories {
    DDLogVerbose(@"%@ findObjectWithInboundId: %d uuid: %@ factories: %@", LOG_TAG, withInboundId, uuid, factories);
    
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"r.schemaId,"
            " r.id, r.uuid, r.creationDate, r.name, r.description, r.attributes, r.modificationDate, r.owner,"
            " twout.id, twout.twincodeId, twout.modificationDate, twout.name, twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags,"
            " po.id, po.twincodeId, po.modificationDate, po.name, po.avatarId, po.description, po.capabilities, po.attributes, po.flags,"
            " ti.id, ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes"];

    if (withInboundId) {
        [query appendString:@" FROM twincodeInbound AS ti"
         " INNER JOIN repository AS r ON r.twincodeInbound = ti.id"
         " LEFT JOIN twincodeOutbound AS twout ON r.twincodeOutbound = twout.id"
         " LEFT JOIN twincodeOutbound AS po ON r.peerTwincodeOutbound = po.id"];
        [query filterUUID:uuid field:@"ti.twincodeId"];
    } else {
        [query appendString:@" FROM repository AS r"
         " LEFT JOIN twincodeInbound AS ti ON r.twincodeInbound = ti.id"
         " LEFT JOIN twincodeOutbound AS twout ON r.twincodeOutbound = twout.id"
         " LEFT JOIN twincodeOutbound AS po ON r.peerTwincodeOutbound = po.id"];
        [query filterUUID:uuid field:@"r.uuid"];
    }
    
    NSMutableArray<NSUUID *> *params = [[NSMutableArray alloc] initWithCapacity:factories.count];
    for (id<TLRepositoryObjectFactory> factory in factories) {
        [params addObject:factory.schemaId];
    }
    [query filterInUUID:params field:@"r.schemaId"];

    __block NSMutableArray<id<TLRepositoryObject>> *result = [[NSMutableArray alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            NSUUID *schemaId = [resultSet uuidForColumnIndex:0];
            if (schemaId) {
                TLRepositoryObjectFactoryImpl *factory = self.factoryMap[schemaId];
                if (factory) {
                    id<TLRepositoryObject> repoObject = [self loadRepositoryObjectWithFactory:factory cursor:resultSet mode:TL_REPOSITORY_OBJECT_FACTORY_USE_ALL offset:1];
                    if (repoObject) {
                        [result addObject:repoObject];
                    }
                }
            }
        }
        [resultSet close];
    }];
    
    return result.count == 1 ? result[0] : nil;
}

- (BOOL)hasObjectsWithSchemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ hasObjectsWithSchemaId: %@", LOG_TAG, schemaId);
    
    __block int count = 0;
    [self inDatabase:^(FMDatabase *database) {
        count = [database intForQuery:@"SELECT COUNT(*) FROM repository WHERE schemaId=?", [schemaId toString]];
    }];
    return count > 0;
}

- (nullable id<TLRepositoryObject>)createObjectWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory uuid:(nonnull NSUUID *)uuid withInitializer:(nonnull void (^)(id<TLRepositoryObject> _Nonnull object))initializer {
    DDLogVerbose(@"%@ createObjectWithFactory: %@ uuid: %@", LOG_TAG, factory, uuid);

    __block id<TLRepositoryObject> result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        long dbId = [transaction allocateIdWithTable:TLDatabaseTableRepository];
        TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:dbId factory:factory];
        id<TLRepositoryObject> object = [factory saveWithIdentifier:identifier uuid:uuid attributes:nil modificationDate:now];
        initializer(object);
        [self internalInsertWithTransaction:transaction object:object creationDate:now modificationDate:now stats:nil];
        [transaction commit];
        [self.database putCacheWithObject:object];
        result = object;
    }];
    return result;
}

- (nullable id<TLRepositoryObject>)importObjectWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes objectKey:(nullable NSUUID *)objectKey {
    DDLogVerbose(@"%@ importObjectWithFactory: %@ uuid: %@ creationDate: %lld attributes: %@ objectKey: %@", LOG_TAG, factory, uuid, creationDate, attributes, objectKey);

    __block id<TLRepositoryObject> result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        long dbId = [transaction allocateIdWithTable:TLDatabaseTableRepository];
        TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:dbId factory:factory];
        id<TLRepositoryObject> object = [factory importWithTransaction:transaction identifier:identifier uuid:uuid key:objectKey creationDate:creationDate attributes:attributes];
        if (object) {
            [self internalInsertWithTransaction:transaction object:object creationDate:creationDate modificationDate:now stats:nil];
            [transaction commit];
            [self.database putCacheWithObject:object];
            result = object;
        }
    }];
    return result;
}

- (void)updateWithObject:(nonnull id<TLRepositoryObject>)object modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ updateWithObject: %@ modificationDate: %lld", LOG_TAG, object, modificationDate);

    [self inTransaction:^(TLTransaction *transaction) {
        TLDatabaseIdentifier *identifier = [object identifier];
        NSObject *name = [TLDatabaseService toObjectWithString:object.name];
        NSObject *description = [TLDatabaseService toObjectWithString:object.objectDescription];
        NSObject *twincodeInbound = [TLDatabaseService toObjectWithTwincodeInbound:object.twincodeInbound];
        NSObject *twincodeOutbound = [TLDatabaseService toObjectWithTwincodeOutbound:object.twincodeOutbound];
        NSObject *peerTwincodeOutbound = [TLDatabaseService toObjectWithTwincodeOutbound:object.peerTwincodeOutbound];
        NSObject *owner = [TLDatabaseService toObjectWithObject:object.owner];
        NSObject *attributes = [TLDatabaseService toObjectWithData:[TLBinaryCompactEncoder serializeWithAttributes:[object attributesWithAll:NO]]];
        [transaction executeUpdate:@"UPDATE repository SET name=?, description=?, modificationDate=?,"
         "twincodeInbound=?, twincodeOutbound=?, peerTwincodeOutbound=?, owner=?, attributes=? WHERE id=?", name, description, [NSNumber numberWithLongLong:modificationDate], twincodeInbound, twincodeOutbound, peerTwincodeOutbound, owner, attributes, [identifier identifierNumber]];
        [transaction commit];
    }];
}

- (nullable TLObjectStatImpl *)loadStatWithObject:(nonnull id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ loadStatWithObject: %@", LOG_TAG, object);

    __block TLObjectStatImpl *stat = nil;
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT stats FROM repository WHERE id=?", [object.identifier identifierNumber]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if ([resultSet next]) {
            NSData *data = [resultSet dataForColumnIndex:0];
            if (data) {
                stat = [TLObjectStatImpl deserializeWithDatabaseId:object.identifier data:data];
            } else {
                stat = [[TLObjectStatImpl alloc] initWithId:object.identifier];
            }
        }
        [resultSet close];
    }];
    return stat;
}

- (nonnull NSMutableDictionary<TLDatabaseIdentifier *, TLRepositoryStatInfo *> *)loadStatsWithSchemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ loadStatsWithSchemaId: %@", LOG_TAG, schemaId);

    NSMutableDictionary<TLDatabaseIdentifier *, TLRepositoryStatInfo *> *result = [[NSMutableDictionary alloc] init];
    TLRepositoryObjectFactoryImpl *factory = [self factoryWithSchemaId:schemaId];
    if (!factory) {
        return result;
    }
    
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT r.id, r.stats, po.flags FROM repository AS r"
                                  " LEFT JOIN twincodeOutbound AS po ON r.peerTwincodeOutbound = po.id"
                                  " WHERE r.schemaId=?", [schemaId toString]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            long databaseId = [resultSet longForColumnIndex:0];
            NSData *data = [resultSet dataForColumnIndex:1];
            if (data) {
                TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:databaseId factory:factory];
                TLObjectStatImpl *stat = [TLObjectStatImpl deserializeWithDatabaseId:identifier data:data];
                if (stat) {
                    int peerTwincodeFlags = [resultSet intForColumnIndex:2];
                    [result setObject:[[TLRepositoryStatInfo alloc] initWithObjectStats:stat peerTwincodeFlags:peerTwincodeFlags] forKey:identifier];
                }
            }
        }
        [resultSet close];
    }];
    return result;
}

- (int)onResumeWithDatabase:(nonnull FMDatabase *)database lastSuspendDate:(int64_t)lastSuspendDate {
    DDLogVerbose(@"%@ onResumeWithDatabase: %lld", LOG_TAG, lastSuspendDate);

    TL_DECL_START_MEASURE(startTime)

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"r.schemaId,"
            " r.id, r.uuid, r.creationDate, r.name, r.description, r.attributes, r.modificationDate, r.owner,"
            " twout.id, twout.twincodeId, twout.modificationDate, twout.name, twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags,"
            " po.id, po.twincodeId, po.modificationDate, po.name, po.avatarId, po.description, po.capabilities, po.attributes, po.flags,"
            " ti.id, ti.twincodeId, ti.factoryId, ti.twincodeOutbound, ti.modificationDate, ti.capabilities, ti.attributes"];
    [query appendString:@" FROM repository AS r"
     " LEFT JOIN twincodeInbound AS ti ON r.twincodeInbound = ti.id"
     " LEFT JOIN twincodeOutbound AS twout ON r.twincodeOutbound = twout.id"
     " LEFT JOIN twincodeOutbound AS po ON r.peerTwincodeOutbound = po.id"];
    [query filterAfter:lastSuspendDate field:@"r.modificationDate"];

    FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
    if (!resultSet) {
        [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
        return 0;
    }

    int count = 0;
    while ([resultSet next]) {
        NSUUID *schemaId = [resultSet uuidForColumnIndex:0];
        if (schemaId) {
            TLRepositoryObjectFactoryImpl *factory = self.factoryMap[schemaId];
            if (factory && ![resultSet columnIndexIsNull:1]) {

                TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:[resultSet longForColumnIndex:1] factory:factory];
                id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
                if (object) {
                    id<TLRepositoryObject> repoObject = [self loadRepositoryObjectWithFactory:factory cursor:resultSet mode:TL_REPOSITORY_OBJECT_FACTORY_USE_ALL offset:1];
                    if (repoObject) {
                        count++;
                    }
                }
            }
        }
    }
    [resultSet close];
    TL_END_MEASURE(startTime, @"RepositoryService resume")
    return count;
}

- (void)updateObjectWithStat:(nonnull TLObjectStatImpl *)stats {
    DDLogVerbose(@"%@ updateObjectWithStat: %@", LOG_TAG, stats);
    
    TLDataOutputStream *dataOutputStream = [[TLDataOutputStream alloc] init];
    [stats serialize:dataOutputStream];
    NSData *content = [dataOutputStream getData];
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE repository SET stats=? WHERE id=?", content, [stats.databaseId identifierNumber]];
        [transaction commit];
    }];
}

- (void)updateWithStats:(nonnull NSArray<TLObjectStatImpl *> *)stats {
    DDLogVerbose(@"%@ updateWithStats: stats: %@", LOG_TAG, stats);

    [self inTransaction:^(TLTransaction *transaction) {
        for (TLObjectStatImpl *stat in stats) {
            TLDataOutputStream *dataOutputStream = [[TLDataOutputStream alloc] init];
            [stat serialize:dataOutputStream];
            NSData *content = [dataOutputStream getData];
            [transaction executeUpdate:@"UPDATE repository SET stats=? WHERE id=?", content, [stat.databaseId identifierNumber]];
        }
        [transaction commit];
    }];
}

- (void)deleteObject:(nonnull id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ deleteObject: object: %@", LOG_TAG, object);

    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *identifier = [object.identifier identifierNumber];
        [transaction deleteConversationsWithSubjectId:identifier twincodeId:nil];
        [transaction deleteWithObject:object];
        [transaction commit];
    }];
}

- (nullable TLTwincodeInbound *)loadLegacyTwincodeInboundWithTransaction:(nonnull TLTransaction *)transaction twincodeId:(nonnull NSUUID *)twincodeInboundId twincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId {
    DDLogVerbose(@"%@ loadLegacyTwincodeInboundWithTransaction: %@ twincodeInboundId: %@ twincodeOutbound: %@ twincodeFactoryId: %@", LOG_TAG, transaction, twincodeInboundId, twincodeOutbound, twincodeFactoryId);
    
    // Legacy database search: use upper case UUID with UUIDString.
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT content FROM twincodeInboundTwincodeInbound WHERE uuid=?", twincodeInboundId.UUIDString];
    if (!resultSet) {
        return nil;
    }
    
    while ([resultSet next]) {
        NSData *content = [resultSet dataForColumnIndex:0];
        if (content) {
            TLDataInputStream *dataInputStream = [[TLDataInputStream alloc] initWithData:content];
            
            /* ignored NSUUID *uuid = */ [dataInputStream readUUID];
            int64_t modificationDate = [dataInputStream readUInt64];
            NSMutableArray *attributes = [[NSMutableArray alloc] init];
            NSUInteger count = [dataInputStream readUInteger];
            for (int i = 0; i < count; i++) {
                TLAttributeNameValue *attribute = [TLBaseService deserializeWithDataInputStream:dataInputStream];
                if (attribute) {
                    [attributes addObject:attribute];
                }
            }
            if ([dataInputStream isCompleted]) {
                [resultSet close];
                return [transaction storeTwincodeInboundWithTwincode:twincodeInboundId twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId attributes:attributes modificationDate:modificationDate];
            }
        }
    }
    [resultSet close];
    return nil;
}

- (nullable id<TLRepositoryObject>)loadRepositoryObjectWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory cursor:(nonnull FMResultSet *)cursor mode:(int)mode offset:(int)offset {
    DDLogVerbose(@"%@ loadRepositoryObjectWithFactory: %@ mode: %d offset: %d", LOG_TAG, factory, mode, offset);

    if ([cursor columnIndexIsNull:offset]) {
        return nil;
    }

    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:[cursor longForColumnIndex:offset] factory:factory];
    id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
    id<TLRepositoryObject> result;
    if (!object) {
        object = [factory createObjectWithIdentifier:identifier cursor:cursor offset:offset + 1];
        result = (id<TLRepositoryObject>) object;
    } else {
        result = (id<TLRepositoryObject>) object;
        // Note: on iOS, after re-loading the repository object we must proceed with reloading
        // every twincode because they could have been changed either by the application or
        // by the NotificationServiceExtension.
        [factory loadWithObject:result cursor:cursor offset:offset + 1];
    }

    offset += 8;
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND) != 0) {
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithResultSet:cursor offset:offset];
        result.twincodeOutbound = twincodeOutbound;
        offset += 9;
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND) != 0) {
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithResultSet:cursor offset:offset];
        result.peerTwincodeOutbound = twincodeOutbound;
        offset += 9;
    }
    if ((mode & TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND) != 0) {
        TLTwincodeInbound *twincodeInbound = [self.database loadTwincodeInboundWithResultSet:cursor offset:offset];
        result.twincodeInbound = twincodeInbound;
        // offset += 7;
    }
    if (![result isValid]) {
        [self.repositoryService notifyInvalidWithObject:result];
        return nil;
    }
    if (object) {
        [self.database putCacheWithObject:object];
    }
    return result;
}

- (void)internalInsertWithTransaction:(nonnull TLTransaction *)transaction object:(nonnull id<TLRepositoryObject>)object creationDate:(int64_t)creationDate modificationDate:(int64_t)modificationDate stats:(nullable NSData *)stats {

    TLDatabaseIdentifier *identifier = [object identifier];
    NSObject *name = [TLDatabaseService toObjectWithString:object.name];
    NSObject *description = [TLDatabaseService toObjectWithString:object.objectDescription];
    NSObject *twincodeInbound = [TLDatabaseService toObjectWithTwincodeInbound:object.twincodeInbound];
    NSObject *twincodeOutbound = [TLDatabaseService toObjectWithTwincodeOutbound:object.twincodeOutbound];
    NSObject *peerTwincodeOutbound = [TLDatabaseService toObjectWithTwincodeOutbound:object.peerTwincodeOutbound];
    NSObject *owner = [TLDatabaseService toObjectWithObject:object.owner];
    NSObject *attributeData = [TLDatabaseService toObjectWithData:[TLBinaryCompactEncoder serializeWithAttributes:[object attributesWithAll:NO]]];
    NSObject *statData = [TLDatabaseService toObjectWithData:stats];
    [transaction executeUpdate:@"INSERT INTO repository (id, uuid, schemaId, schemaVersion, " \
             "name, description, creationDate, modificationDate, twincodeInbound, twincodeOutbound, " \
             "peerTwincodeOutbound, owner, attributes, stats) " \
     "VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [identifier identifierNumber], [object.objectId toString], [identifier.schemaId toString], [NSNumber numberWithInt:identifier.schemaVersion], name, description, [NSNumber numberWithLongLong:creationDate], [NSNumber numberWithLongLong:modificationDate], twincodeInbound, twincodeOutbound, peerTwincodeOutbound, owner, attributeData, statData];
}

- (void)upgrade20WithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ upgrade20WithTransaction: %@", LOG_TAG, transaction);
    
    self.migrationRunning = YES;
    [transaction executeQuery:REPOSITORY_CREATE_TABLE];
    for (TLRepositoryObjectFactoryImpl *factory in self.factories) {
        [self upgradeSchema20WithTransaction:transaction factory:factory];
    }
    self.migrationRunning = NO;

    // Now we can drop the old tables.
    [transaction dropTable:@"repositoryObject"];
    [transaction dropTable:@"twincodeInboundTwincodeInbound"];
}

- (void)upgradeSchema20WithTransaction:(nonnull TLTransaction *)transaction factory:(nonnull TLRepositoryObjectFactoryImpl *)factory {
    DDLogVerbose(@"%@ upgradeSchema20WithTransaction: %@ factory: %@", LOG_TAG, transaction, factory);
    
    NSUUID *schemaId = [factory schemaId];
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT uuid, key, content, stats"
                              " FROM repositoryObject WHERE schemaId=?", schemaId.UUIDString];
    if (!resultSet) {
        return;
    }
    while ([resultSet next]) {
        NSUUID *uuid = [resultSet uuidForColumnIndex:0];
        NSUUID *key = [resultSet uuidForColumnIndex:1];
        NSData *content = [resultSet dataForColumnIndex:2];
        NSData *stats = [resultSet dataForColumnIndex:3];

        if (!uuid || !content) {
            continue;
        }
        @try {
            TLDataInputStream *dataInputStream = [[TLDataInputStream alloc] initWithData:content];
            /* unused NSUUID *uuid = */ [dataInputStream readUUID];
            uint64_t modificationDate = [dataInputStream readUInt64];
            /* unused NSUUID *schemaId = */ [dataInputStream readUUID];
            /* unused int schemaVersion = */ [dataInputStream readInt];
            /* unused NSString *serializer = */ [dataInputStream readString];
            /* unused BOOL immutable = */ [dataInputStream readBoolean];
            NSUUID *serializedKey =  [dataInputStream readUUID];
            if ([TLDataInputStream isNullUUID:serializedKey]) {
                serializedKey = nil;
            }

            // Before 2019, the CreateContactPhase1Executor was creating a Contact without a key.
            // The key was initialized/known after the creation of identity twincode and then the object updated.
            // After that update, the database repositoryObject `key` column was not updated and hence we have it null now.
            // The ObjectImpl that is serialize contains the key and we load these bad rows and update the key
            // in the database table 3 years after!  The CreateContactPhase2Executor did not have that issue.
            // After 2019, the twincode inbound that represents the key is always created before the Contact.
            // A Contact is always inserted with a non null key (and it is never modified).
            if (!key) {
                key = serializedKey;
            }
            NSString *attrContent = [dataInputStream readString];
            NSMutableArray *exclusiveContents = nil;
            NSUInteger size = [dataInputStream readUInteger];
            if (size > 0) {
                exclusiveContents = [[NSMutableArray alloc] initWithCapacity:size];
                for (int i = 0; i < size; i++) {
                    NSString *exclusiveContent = [dataInputStream readString];
                    [exclusiveContents addObject:exclusiveContent];
                }
            }
            NSArray<TLAttributeNameValue *> *attributes = [self.repositoryService deserializeWithContent:attrContent];

            if (attributes) {
                long newId = [transaction allocateIdWithTable:TLDatabaseTableRepository];
                TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:newId factory:factory];
                id<TLRepositoryObject> object = [factory importWithTransaction:transaction identifier:identifier uuid:uuid key:key creationDate:modificationDate attributes:attributes];

                [self internalInsertWithTransaction:transaction object:object creationDate:modificationDate modificationDate:modificationDate stats:stats];
                [self.database putCacheWithObject:object];
            }
        } @catch (NSException *exception) {
            DDLogError(@"%@ upgradeSchema20WithTransaction: exception: %@", LOG_TAG, exception);

        }
    }
    [resultSet close];
}

@end

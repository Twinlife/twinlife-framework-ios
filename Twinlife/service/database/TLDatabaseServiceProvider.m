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

#import "TLDatabaseServiceProvider.h"
#import "TLBaseService.h"
#import "TLImageId.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLDatabaseServiceProvider
//

#undef LOG_TAG
#define LOG_TAG @"TLDatabaseServiceProvider"

@implementation TLDatabaseServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLBaseService *)service database:(nonnull TLDatabaseService *)database sqlCreate:(nonnull NSString *)sqlCreate table:(TLDatabaseTable)table {
    DDLogVerbose(@"%@ initWithService: %@ database: %@ sqlCreate: %@ table: %d", LOG_TAG, service, database, sqlCreate, table);
    
    self = [super init];
    if (self) {
        _service = service;
        _database = database;
        _createTable = sqlCreate;
        _table = table;
        [database registerWithService:self];
    }
    return self;
}

- (void)onCreateWithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ onCreateWithTransaction: %@ ", LOG_TAG, transaction);
    
    [transaction createSchemaWithSQL:self.createTable];
}

- (void)onOpen {
    DDLogVerbose(@"%@ onOpen", LOG_TAG);
    
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);
    
    [transaction createSchemaWithSQL:self.createTable];
}

- (int)onResumeWithDatabase:(nonnull FMDatabase *)database lastSuspendDate:(int64_t)lastSuspendDate {
    DDLogVerbose(@"%@ onResumeWithDatabase: %@ lastSuspendDate: %lld", LOG_TAG, database, lastSuspendDate);

    return 0;
}

- (TLDatabaseTable)kind {
    
    return self.table;
}

- (void)inDatabase:(__attribute__((noescape)) void (^)(FMDatabase *db))block {
    DDLogVerbose(@"%@ inDatabase: %@", LOG_TAG, block);
    
    [self.database inDatabase:block];
}

- (void)inTransaction:(nonnull __attribute__((noescape)) void (^)(TLTransaction *_Nonnull transaction))block {
    DDLogVerbose(@"%@ inTransaction: %@", LOG_TAG, block);
    
    TLBaseServiceErrorCode result = [self.database inTransaction:block];
    if (result != TLBaseServiceErrorCodeSuccess) {
        [self.service onDatabaseErrorWithCode:result];
    }
}

- (void)deleteWithObject:(nonnull id<TLDatabaseObject>)object {
    DDLogVerbose(@"%@ deleteObjectWithObjectId: %@", LOG_TAG, object);
    
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction deleteWithObject:object];
        [transaction commit];
    }];
}

- (void)deleteWithUUID:(nonnull NSUUID *)objectId {
    DDLogVerbose(@"%@ deleteWithUUID: %@", LOG_TAG, objectId);
    
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction deleteWithId:objectId table:self.table];
        [transaction commit];
    }];
}

- (nullable TLExportedImageId *)publicWithImageId:(nonnull TLImageId *)imageId {
    DDLogVerbose(@"%@ publicWithImageId: %@", LOG_TAG, imageId);
    
    __block TLExportedImageId *result = nil;
    [self.database inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT uuid FROM image WHERE id=?", [NSNumber numberWithLongLong:imageId.localId]];
        if (!resultSet) {
            return;
        }
        if ([resultSet next]) {
            NSUUID *publicId = [resultSet uuidForColumnIndex:0];
            if (publicId) {
                result = [[TLExportedImageId alloc] initWithPublicId:publicId localId:imageId.localId];
            }
        }
        [resultSet close];
    }];
    return result;
}

@end

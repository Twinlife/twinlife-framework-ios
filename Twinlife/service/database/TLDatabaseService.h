/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "NSUUID+Extensions.h"
#import "TLDatabase.h"
#import "TLBaseService.h"
#import "TLAssertion.h"

@class TLTwinlife;
@class TLBaseService;
@class TLDatabaseIdentifier;
@class FMDatabase;
@class FMResultSet;
@class FMDatabaseQueue;
@class TLTwincodeInbound;
@class TLTwincodeOutbound;
@class TLAttributeNameValue;
@class TLTransaction;
@class TLDatabaseServiceProvider;
@class TLImageId;
@protocol TLRepositoryObject;

//
// Interface: TLDatabaseFullException
//
@interface TLDatabaseFullException : NSException

+ (nonnull TLDatabaseFullException *)createWithReason:(nullable NSString *)reason userInfo:(nullable NSDictionary *)userInfo;

@end

//
// Interface: TLDatabaseErrorException
//
@interface TLDatabaseErrorException : NSException

@property (readonly) NSInteger code;

- (nonnull instancetype)initWithReason:(nullable NSString *)reason error:(nullable NSError *)error;

+ (nonnull TLDatabaseErrorException *)createWithReason:(nullable NSString *)reason error:(nullable NSError *)error;

@end

//
// Interface: TLDatabaseAssertPoint
//

@interface TLDatabaseAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)DATABASE_ERROR;
+(nonnull TLAssertPoint *)EXCEPTION;
+(nonnull TLAssertPoint *)DATABASE_UPDATE_ERROR;

@end

//
// Interface: TLQueryBuilder
//

@interface TLQueryBuilder : NSObject

- (nonnull instancetype)initWithSQL:(nonnull NSString *)sql;

- (nonnull NSString *)sql;

- (nonnull NSArray<NSObject *> *)sqlParams;

- (void)filterBefore:(int64_t)before field:(nonnull NSString *)field;

- (void)filterAfter:(int64_t)after field:(nonnull NSString *)field;

- (void)filterOwner:(nullable id<TLRepositoryObject>)owner field:(nonnull NSString *)field;

- (void)filterName:(nullable NSString *)name field:(nonnull NSString *)field;

- (void)filterUUID:(nullable NSUUID *)uuid field:(nonnull NSString *)field;

- (void)filterLong:(long)value field:(nonnull NSString *)field;

- (void)filterIdentifier:(nullable TLDatabaseIdentifier *)value field:(nonnull NSString *)field;

- (void)filterNumber:(nullable NSNumber *)value field:(nonnull NSString *)field;

- (void)filterInUUID:(nonnull NSArray<NSUUID *> *)list field:(nonnull NSString *)field;

- (void)filterInList:(nonnull NSArray<NSNumber *> *)list field:(nonnull NSString *)field;

- (void)filterWhere:(nullable NSString *)sql;

- (void)order:(nonnull NSString *)order;

- (void)limit:(long)value;

- (void)appendString:(nonnull NSString *)sqlFragment;

@end

//
// Interface: TLDatabaseObjectFactory
//

@protocol TLDatabaseObjectFactory <TLDatabaseObjectIdentification>

- (nullable id<TLDatabaseObject>)createObjectWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier cursor:(nonnull FMResultSet *)cursor offset:(int)offset;

- (BOOL)loadWithObject:(nonnull id<TLDatabaseObject>)object cursor:(nonnull FMResultSet *)cursor offset:(int)offset;

@end

//
// Interface: TLTwincodeObjectFactory
//

@protocol TLTwincodeObjectFactory <TLDatabaseObjectFactory>

- (nonnull id<TLDatabaseObject>)storeObjectWithTransaction:(nonnull TLTransaction *)transaction identifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:()attributes flags:(int)flags modificationDate:(int64_t)modificationDate refreshPeriod:(int64_t)refreshPeriod refreshDate:(int64_t)refreshDate refreshTimestamp:(int64_t)refreshTimestamp initialize:(nonnull void (^)(id<TLDatabaseObject> _Nullable object))initialize;

@end

//
// Interface: TLRepositoryObjectLoader
//

@protocol TLRepositoryObjectLoader

/// Load the repository object with the given database id and using the given schema Id.
/// The schemaId is used to find the good repository object factory if the repository object
/// is not found in the cache and must be loaded.
- (nullable id<TLRepositoryObject>)loadRepositoryObjectWithId:(long)databaseId schemaId:(nonnull NSUUID *)schemaId;

@end

//
// Interface: TLTwincodesCleaner
//

@protocol TLTwincodesCleaner

/// Delete the twincode from the database as well as the keys, secrets and image.
- (void)deleteTwincodeWithTransaction:(nonnull TLTransaction *)transaction twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound;

@end

//
// Interface: TLImagesCleaner
//

@protocol TLImagesCleaner

/// Delete the image from the database, remove it from the image cache and if the big image was downloaded
/// remove it from the file system.  It is called from the twincode outbound service when a twincode is removed.
- (void)deleteImageWithTransaction:(nonnull TLTransaction *)transaction imageId:(nullable TLImageId *)imageId;

@end

//
// Interface: TLNotificationsCleaner
//

@protocol TLNotificationsCleaner

/// Delete some notifications with the given transaction (commit must be done by the caller).
/// Identify the notifications that are not acknowledged and report them to the NotificationService.
/// Load the repository object with the given database id and using the given schema Id.
- (void)deleteNotificationsWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId descriptorId:(nullable NSNumber *)descriptorId;

@end

//
// Interface: TLConversationsCleaner
//

@protocol TLConversationsCleaner

/// Delete some conversation (and related data) with the given transaction (commit must be done by the caller).
/// By deleting the conversation, we also trigger deletion of notifications.
/// Delete some notifications with the given transaction (commit must be done by the caller).
- (void)deleteConversationsWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId;

@end

//
// Interface: TLTransaction
//

@interface TLTransaction : NSObject

/// Allocate a unique id for the given database table.
- (long)allocateIdWithTable:(TLDatabaseTable)table;

/// Returns YES if the database table exists.
- (BOOL)hasTableWithName:(nonnull NSString *)name;

/// Delete the object from its associated database table and remove it from the cache.
- (void)deleteWithObject:(nonnull id<TLDatabaseObject>)object;

/// Delete from the database table the object with the given uuid.
/// The object is also removed from the cache if it was present.
- (void)deleteWithId:(nonnull NSUUID*)objectId table:(TLDatabaseTable)table;

/// Delete a list of records from the database table.
- (void)deleteWithList:(nonnull NSArray<NSNumber *> *)list table:(TLDatabaseTable)table;

/// Delete from the database table the row with the given id in the table.
- (void)deleteWithDatabaseId:(int64_t)databaseId table:(TLDatabaseTable)table;

/// Delete the image with the given id and cleanup the image cache.
- (void)deleteImageWithId:(nullable TLImageId *)imageId;

/// Delete some notifications with the given transaction (commit must be done by the caller).
/// Identify the notifications that are not acknowledged and report them to the NotificationService.
/// Load the repository object with the given database id and using the given schema Id.
- (void)deleteNotificationsWithSubjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId descriptorId:(nullable NSNumber *)descriptorId;

/// Delete some conversation (and related data) with the given transaction (commit must be done by the caller).
/// By deleting the conversation, we also trigger deletion of notifications.
/// Delete some notifications with the given transaction (commit must be done by the caller).
- (void)deleteConversationsWithSubjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId;

/// Delete the twincode from the database as well as the keys, secrets and image.
- (void)deleteTwincodeWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound;

/// Look at the attributes and store the avatarId attribute if there is one in the list.
/// Return YES if the attributes contained an AVATAR_ID.
- (BOOL)storeAvatarWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes;

- (nullable TLTwincodeInbound *)storeTwincodeInboundWithTwincode:(nonnull NSUUID *)twincodeId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

- (nullable TLTwincodeOutbound *)storeTwincodeOutboundWithTwincode:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes flags:(int)flags modificationDate:(int64_t)modificationDate refreshPeriod:(int64_t)refreshPeriod refreshDate:(int64_t)refreshDate refreshTimestamp:(int64_t)refreshTimestamp;

- (nullable TLTwincodeOutbound *)loadOrStoreTwincodeOutboundId:(nonnull NSUUID *)twincodeId;

- (void)saveSecretKeyWithKeyId:(nonnull NSNumber *)keyId keyIndex:(int)keyIndex secretKey:(nonnull NSData *)secretKey now:(nonnull NSNumber *)now;

- (void)storePublicKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound flags:(int)flags pubSigningKey:(nonnull NSData *)pubSigningKey pubEncryptionKey:(nullable NSData *)pubEncryptionKey keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey;

- (void)updateTwincodeEncryptFlagsWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound now:(nonnull NSNumber *)now;

- (nullable FMResultSet *)executeQuery:(nonnull NSString*)sql, ...;

- (nullable FMResultSet *)executeWithQuery:(nonnull TLQueryBuilder *)query;

- (long)longForQuery:(nonnull NSString*)sql, ...;

- (nonnull NSMutableArray<NSUUID *> *)listUUIDWithSQL:(nonnull NSString *)sql, ...;

- (nonnull NSMutableArray<NSNumber *> *)listIdsWithSQL:(nonnull NSString *)sql, ...;

- (void)executeUpdate:(nonnull NSString*)sql, ...;

/// Create a database table or index.
- (void)createSchemaWithSQL:(nonnull NSString *)sql;

/// Return number of changes made in last SQL statement.
- (int)changes;

- (void)commit;

- (nullable NSError *)lastError;

/// Drop the database table with the given name.
- (void)dropTable:(nonnull NSString *)name;

@end

//
// Interface: TLDatabaseService
//

@interface TLDatabaseService : NSObject

@property (nullable) id<TLTwincodeObjectFactory> twincodeInboundFactory;
@property (nullable) id<TLTwincodeObjectFactory> twincodeOutboundFactory;

+ (nonnull NSObject *)toObjectWithString:(nullable NSString *)value;
+ (nonnull NSObject *)toObjectWithNumber:(nullable NSNumber *)value;
+ (nonnull NSObject *)toObjectWithUUID:(nullable NSUUID *)value;
+ (nonnull NSObject *)toObjectWithImageId:(nullable TLImageId *)value;
+ (nonnull NSObject *)toObjectWithTwincodeInbound:(nullable TLTwincodeInbound *)value;
+ (nonnull NSObject *)toObjectWithTwincodeOutbound:(nullable TLTwincodeOutbound *)value;
+ (nonnull NSObject *)toObjectWithObject:(nullable id<TLRepositoryObject>)value;
+ (nonnull NSObject *)toObjectWithData:(nullable NSData *)value;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife;

/// Register a service provider that will use the database.
- (void)registerWithService:(nonnull TLDatabaseServiceProvider *)service;

/// Create the database.
- (void)onCreateWithDatabaseQueue:(nonnull FMDatabaseQueue *)databaseQueue version:(int)version;

/// Open the database.
- (void)onOpenWithDatabaseQueue:(nonnull FMDatabaseQueue *)databaseQueue;

/// Database is closed.
- (void)onCloseDatabase;

/// Open the database and make a migration from the old version to the new one.
- (TLBaseServiceErrorCode)onUpgradeWithDatabaseQueue:(nonnull FMDatabaseQueue *)databaseQueue oldVersion:(int)oldVersion newVersion:(int)newVersion;

/// Sync the database by running the WAL checkpoint and switch to DELETE journal mode.
- (void)syncDatabase;

/// Get from the cache the object with the given database identifier.
- (nullable id<TLDatabaseObject>)getCacheWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier;

- (nullable id<TLDatabaseObject>)getCacheWithObjectId:(nonnull NSUUID *)objectId;

/// Put in the cache the database object instance.
- (void)putCacheWithObject:(nonnull id<TLDatabaseObject>)object;

/// Remove from the cache the database object with the given database identifier.
- (void)evictCacheWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier;

/// Remove from the cache the object with the given uuid.
- (void)evictCacheWithObjectId:(nullable NSUUID *)objectId;

- (nullable TLTwincodeInbound *)loadTwincodeInboundWithResultSet:(nonnull FMResultSet *)resultSet offset:(int)offset;

- (nullable TLTwincodeOutbound *)loadTwincodeOutboundWithResultSet:(nonnull FMResultSet *)resultSet offset:(int)offset;

- (nullable TLTwincodeInbound *)loadTwincodeInboundWithTwincodeId:(nonnull NSUUID *)twincodeId;

- (nullable TLTwincodeOutbound *)loadTwincodeOutboundWithTwincodeId:(nonnull NSUUID *)twincodeId;

- (nullable TLTwincodeOutbound *)loadTwincodeOutboundWithId:(long)databaseId;

/// Load the repository object with the given database id and using the given schema Id.
/// The schemaId is used to find the good repository object factory if the repository object
/// is not found in the cache and must be loaded.
- (nullable id<TLRepositoryObject>)loadRepositoryObjectWithId:(long)databaseId schemaId:(nonnull NSUUID *)schemaId;

- (TLBaseServiceErrorCode)inTransaction:(nonnull __attribute__((noescape)) void (^)(TLTransaction *_Nonnull transaction))block;

- (void)inDatabase:(nonnull __attribute__((noescape)) void (^)(FMDatabase *_Nullable db))block;

- (nonnull NSMutableString *)checkConsistency;

@end

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

#import "TLDatabaseServiceProvider.h"

@class TLRepositoryService;
@class TLRepositoryObjectFactoryImpl;
@class TLObjectStatImpl;
@protocol RepositoryObject;

//
// Interface: TLRepositoryStatInfo
//

@interface TLRepositoryStatInfo : NSObject

@property (readonly, nonnull) TLObjectStatImpl *stats;
@property (readonly) int peerTwincodeFlags;

- (nonnull instancetype)initWithObjectStats:(nonnull TLObjectStatImpl *)stats peerTwincodeFlags:(int)peerTwincodeFlags;

@end

//
// Interface: TLRepositoryServiceProvider
//

@interface TLRepositoryObjectFactoryImpl : NSObject <TLDatabaseObjectFactory, TLRepositoryImportService>

@end

//
// Interface: TLRepositoryServiceProvider
//

@interface TLRepositoryServiceProvider : TLDatabaseServiceProvider <TLRepositoryObjectLoader>

- (nonnull instancetype)initWithService:(nonnull TLRepositoryService *)service database:(nonnull TLDatabaseService *)database;

- (void)configureWithFactories:(nonnull NSArray<id<TLRepositoryObjectFactory>> *)factories;

/// Get the repository object factory to create objects with the given schema.
- (nullable TLRepositoryObjectFactoryImpl *)factoryWithSchemaId:(nonnull NSUUID *)schemaId;

/// Get the list of factories that have been registered during creation.
- (nonnull NSArray<TLRepositoryObjectFactoryImpl *> *)getFactories;

/// Load from the database the repository object with the given uuid and factory.
/// The factory is used to know the object schema and create instance of that object
/// to load it from the database.
- (nullable id<TLRepositoryObject>)loadObjectWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory dbId:(long)dbId uuid:(nullable NSUUID *)uuid;

/// List the objects with the given factory.  The factory is used to know the schema Id of the objects to load
/// and to create instances when they are loaded from the database.
- (nonnull NSArray<id<TLRepositoryObject>> *)listObjectsWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory filter:(nullable TLFilter *)filter;

/// Find the object with either the objectId or the twincode inbound id of the object.
/// Only one object must be found and its schema must be from one of the factories.
- (nullable id<TLRepositoryObject>)findObjectWithInboundId:(BOOL)withInboundId uuid:(nonnull NSUUID *)uuid factories:(nonnull NSArray<TLRepositoryObjectFactoryImpl *> *)factories;

- (nullable id<TLRepositoryObject>)createObjectWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory uuid:(nonnull NSUUID *)uuid withInitializer:(nonnull void (^)(id<TLRepositoryObject> _Nonnull object))initializer;

- (nullable id<TLRepositoryObject>)importObjectWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes objectKey:(nullable NSUUID *)objectKey;

- (void)updateWithObject:(nonnull id<TLRepositoryObject>)object modificationDate:(int64_t)modificationDate;

- (BOOL)hasObjectsWithSchemaId:(nonnull NSUUID *)schemaId;

/// Load the object stat for the given object.
- (nullable TLObjectStatImpl *)loadStatWithObject:(nonnull id<TLRepositoryObject>)object;

/// Load the object stats for every object of the given schema.
- (nonnull NSMutableDictionary<TLDatabaseIdentifier *, TLRepositoryStatInfo *> *)loadStatsWithSchemaId:(nonnull NSUUID *)schemaId;

- (void)updateObjectWithStat:(nonnull TLObjectStatImpl *)stats;

- (void)updateWithStats:(nonnull NSArray<TLObjectStatImpl *> *)stats;

- (void)deleteObject:(nonnull id<TLRepositoryObject>)object;

@end

/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLRepositoryObjectHandler.h"
#import "TLRepositoryServiceImpl.h"
#import "TLDatabase.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

@interface TLRepositoryObjectRestorerV1 : TLRestorer<id<TLRepositoryObject>>

@property (nonatomic, nonnull, readonly) TLRepositoryService *repositoryService;
@property (nonatomic, nonnull, readonly) NSArray<NSUUID *> *supportedSchemaIds;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSUUID *, NSNumber *> *stats;
@property (nonatomic, nullable) NSArray<id<TLRepositoryObject>> *localObjects;

- (nonnull instancetype)initWithRepositoryService:(TLRepositoryService *)repositoryService supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds;

@end

@implementation TLUnknownRepositoryObject

- (nonnull TLDatabaseIdentifier *)identifier { 
    return nil;
}

- (nonnull NSUUID *)objectId { 
    return nil;
}

- (nonnull NSString *)name {
    return @"";
}

- (nonnull NSString *)objectDescription {
    return @"";
}

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll {
    return [NSArray array];
}


- (BOOL)isValid {
    return NO;
}

- (BOOL)canCreateP2P {
    return NO;
}


@end

#undef LOG_TAG
#define LOG_TAG @"TLRepositoryObjectRestorerV1"

@implementation TLRepositoryObjectRestorerV1

+ (nonnull NSNumber *) VERSION {
    return @1;
}

- (nonnull instancetype)initWithRepositoryService:(TLRepositoryService *)repositoryService supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds {
    self = [super init];
    
    if (self) {
        _repositoryService = repositoryService;
        _supportedSchemaIds = supportedSchemaIds;
        _stats = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (nullable id<TLRepositoryObject>) restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");
        
    NSUUID *schemaId = [decoder readUUID];
    int64_t dbId = [decoder readLong];
    NSUUID *objectId = [decoder readUUID];
    int64_t creationDate = [decoder readLong];
    int64_t modificationDate = [decoder readLong];
    
    NSArray<TLAttributeNameValue *> *attrs = [decoder readAttributes];
    
    if (!attrs) {
        attrs = [NSArray array];
    }
    
    if (![self.supportedSchemaIds containsObject:schemaId]) {
        DDLogWarn(@"%@ Restore not supported for objects with schema ID: %@", LOG_TAG, schemaId.UUIDString);
        return nil;
    }
    
    id<TLRepositoryObject> repositoryObject;
   
    if (inPlace) {
        repositoryObject = [self.repositoryService restoreExistingObjectWithSchemaId:schemaId databaseId:dbId objectId:objectId creationDate:creationDate modificationDate:modificationDate attributes:attrs];
    } else {
        repositoryObject = [self.repositoryService restoreObjectWithSchemaId:schemaId databaseId:dbId objectId:objectId creationDate:creationDate modificationDate:modificationDate attributes:attrs];
    }
    
    if (!repositoryObject) {
        DDLogError(@"%@ Could not restore object %@", LOG_TAG, objectId);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    DDLogVerbose(@"%@ Restored repository object schemaId=%@ objectId=%@", LOG_TAG, repositoryObject.identifier.schemaId.UUIDString, repositoryObject.objectId.UUIDString);
    
    [self addStatWithSchemaId:schemaId];
    
    return repositoryObject;
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);
 
    NSUUID *schemaId = [decoder readUUID];
    [decoder readLong]; //dbId
    NSUUID *objectId = [decoder readUUID];
    [decoder readLong]; //creationDate
    [decoder readLong]; //modificationDate
    
    NSSet<TLAttributeNameValue *> *attrs = [NSSet setWithArray:[decoder readAttributes]];
    if (!attrs) {
        attrs = [NSSet set];
    }

    if (![self.supportedSchemaIds containsObject:schemaId]) {
        DDLogWarn(@"%@ Restore not supported for objects with schema ID: %@", LOG_TAG, schemaId.UUIDString);
        return [[TLBackupVerifyResultAbsent alloc] initWithIdentifier:objectId schemaId:schemaId type:TLUnknownRepositoryObject.class];
    }
    
    if (!self.localObjects) {
        self.localObjects = [self.repositoryService getLocalObjectsWithSupportedSchemaIds:self.supportedSchemaIds];
    }
    
    id<TLRepositoryObject> repositoryObject;
    
    for (id<TLRepositoryObject>localObject in self.localObjects) {
        if ([localObject.objectId isEqual:objectId]) {
            repositoryObject = localObject;
            break;
        }
    }
    
    if (!repositoryObject) {
        return [[TLBackupVerifyResultAbsent alloc] initWithIdentifier:objectId schemaId:schemaId type:TLUnknownRepositoryObject.class];
    }
    
    NSSet<TLAttributeNameValue *> *dbAttrs = [NSSet setWithArray:[repositoryObject attributesWithAll:YES]];
    
    BOOL modified  = dbAttrs.count != attrs.count || ![dbAttrs isEqualToSet:attrs];
    
    return [[TLBackupVerifyResultPresent alloc] initWithObject:repositoryObject modified:modified];
}

- (void)addStatWithSchemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ addStatWithSchemaId:%@", LOG_TAG, schemaId.UUIDString);
    
    NSNumber *counter = self.stats[schemaId];
    
    if (!counter) {
        counter = @1;
    } else {
        counter = [NSNumber numberWithInt:(counter.intValue + 1)];
    }
    
    self.stats[schemaId] = counter;
}

- (nullable NSDictionary<NSUUID *, NSNumber *> *) getStats {
    return self.stats;
}

@end

@interface TLRepositoryObjectHandler ()

@property (nonatomic, nonnull, readonly) TLRepositoryService *repositoryService;
@property (nonatomic, nonnull, readonly) NSArray<NSUUID *> *supportedSchemaIds;
@property (nonatomic, nonnull, readonly) NSMutableDictionary<NSUUID *, NSNumber *> *stats;

- (void)addStatWithSchemaId:(nonnull NSUUID *)schemaId;

@end

#undef LOG_TAG
#define LOG_TAG @"TLRepositoryObjectHandler"

@implementation TLRepositoryObjectHandler


- (nonnull instancetype)initWithRepositoryService:(nonnull TLRepositoryService *)repositoryService supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds{

    self = [super initWithRestorers:@{
        TLRepositoryObjectRestorerV1.VERSION : [[TLRepositoryObjectRestorerV1 alloc] initWithRepositoryService:repositoryService supportedSchemaIds:supportedSchemaIds]
    }];
    
    if (self) {
        _repositoryService = repositoryService;
        _supportedSchemaIds = supportedSchemaIds;
        _stats = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogVerbose(@"%@ backupWithBinaryEncoder: %@", LOG_TAG, encoder);

    for (id<TLRepositoryObject> repositoryObject in [self.repositoryService getLocalObjectsWithSupportedSchemaIds:self.supportedSchemaIds]) {
        [encoder writeUUID:TL_REPOSITORY_OBJECT_BACKUP_SCHEMA_ID];
        [encoder writeInt:TL_REPOSITORY_OBJECT_BACKUP_SCHEMA_VERSION];
        [encoder writeUUID:repositoryObject.identifier.schemaId];
        [encoder writeLong:repositoryObject.identifier.identifier];
        [encoder writeUUID:repositoryObject.objectId];
        [encoder writeLong:repositoryObject.modificationDate]; // TODO BKP: creation date
        [encoder writeLong:repositoryObject.modificationDate];
        //TODO BKP: flags?
        [encoder writeAttributes:[repositoryObject attributesWithAll:YES]];
        
        [self addStatWithSchemaId:repositoryObject.identifier.schemaId];
        
        DDLogVerbose(@"%@ Backed up repository object schemaId=%@ objectId=%@", LOG_TAG, repositoryObject.identifier.schemaId.UUIDString, repositoryObject.objectId.UUIDString);
    }
}

- (nullable NSDictionary<NSUUID *,NSNumber *> *)getBackupStats {
    DDLogVerbose(@"%@ getRestoreStats", LOG_TAG);
    
    return self.stats;
}

- (void)addStatWithSchemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ addStatWithSchemaId:%@", LOG_TAG, schemaId.UUIDString);
    
    NSNumber *counter = self.stats[schemaId];
    
    if (!counter) {
        counter = @1;
    } else {
        counter = [NSNumber numberWithInt:(counter.intValue + 1)];
    }
    
    self.stats[schemaId] = counter;
}

@end


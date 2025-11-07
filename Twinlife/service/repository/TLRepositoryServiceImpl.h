/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import "TLRepositoryService.h"
#import "TLBaseServiceImpl.h"

@class TLRepositoryObjectFactoryImpl;
@class TLDataOutputStream;

//
// Interface: TLRepositoryPendingRequest
//

@interface TLRepositoryPendingRequest : NSObject

@end

//
// Interface: TLCreateObjectRepositoryPendingRequest
//
typedef void (^TLCreateObjectComplete) (TLBaseServiceErrorCode status, id<TLRepositoryObject> _Nullable object);

@interface TLCreateObjectRepositoryPendingRequest : TLRepositoryPendingRequest

@property (readonly, nonnull) TLRepositoryObjectFactoryImpl *factory;
@property (readonly) BOOL immutable;
@property (readonly, nonnull) NSArray<TLAttributeNameValue *> *attributes;
@property (readonly, nullable) NSUUID *objectKey;
@property (readonly, nonnull) TLCreateObjectComplete complete;

-(nonnull instancetype)initWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory immutable:(BOOL)immutable attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes objectKey:(nullable NSUUID *)objectKey complete:(nonnull TLCreateObjectComplete)complete;

@end

//
// Interface: TLGetObjectRepositoryPendingRequest
//
typedef void (^TLGetObjectComplete) (TLBaseServiceErrorCode status, id<TLRepositoryObject> _Nullable object);

@interface TLGetObjectRepositoryPendingRequest : TLRepositoryPendingRequest

@property (readonly, nonnull) NSUUID *objectId;
@property (readonly, nonnull) TLRepositoryObjectFactoryImpl *factory;
@property (readonly, nonnull) TLGetObjectComplete complete;

-(nonnull instancetype)initWithObjectId:(nonnull NSUUID *)objectId factory:(nonnull TLRepositoryObjectFactoryImpl *)factory complete:(nonnull TLGetObjectComplete)complete;

@end

//
// Interface: TLUpdateObjectRepositoryPendingRequest
//

@interface TLUpdateObjectRepositoryPendingRequest : TLRepositoryPendingRequest

@property (readonly, nonnull) id<TLRepositoryObject> object;
@property (readonly, nonnull) TLGetObjectComplete complete;

-(nonnull instancetype)initWithObject:(nonnull id<TLRepositoryObject>)object complete:(nonnull TLGetObjectComplete)complete;

@end

//
// Interface: TLListObjectRepositoryPendingRequest
//
typedef void (^TLListObjectComplete) (TLBaseServiceErrorCode status, NSArray<NSUUID *> * _Nullable objectIds);

@interface TLListObjectRepositoryPendingRequest : TLRepositoryPendingRequest

@property (readonly, nonnull) TLListObjectComplete complete;

-(nonnull instancetype)initWithComplete:(nonnull TLListObjectComplete)complete;

@end

//
// Interface: TLDeleteObjectRepositoryPendingRequest
//
typedef void (^TLDeleteObjectComplete) (TLBaseServiceErrorCode status, NSUUID * _Nullable object);

@interface TLDeleteObjectRepositoryPendingRequest : TLRepositoryPendingRequest

@property (readonly, nonnull) id<TLRepositoryObject> object;
@property (readonly, nonnull) TLDeleteObjectComplete complete;

-(nonnull instancetype)initWithObject:(nonnull id<TLRepositoryObject>)object complete:(nonnull TLDeleteObjectComplete)complete;

@end

//
// Interface: TLObjectStatImpl
//

@interface TLObjectStatImpl : NSObject

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property double score;
@property double scale;
@property double points;
@property int64_t lastMessageDate;
@property (nonnull, readonly) int *statCounters;
@property (nonnull, readonly) int *referenceCounters;

- (nonnull instancetype)initWithId:(nonnull TLDatabaseIdentifier *)identifier;

- (nonnull instancetype)initWithId:(nonnull TLDatabaseIdentifier *)identifier score:(double)score scale:(double)scale points:(double)points statCounters:(nonnull int *)statCounters referenceCounters:(nonnull int*)referenceCounters lastMessageDate:(int64_t)lastMessageDate;

- (void)incrementWithStatType:(TLRepositoryServiceStatType)statType weights:(nullable NSArray<TLObjectWeight *> *)weights;

- (void)incrementWithStatType:(TLRepositoryServiceStatType)statType weights:(nullable NSArray<TLObjectWeight *> *)weights value:(long)value;

- (BOOL)updateScoreWithScale:(double)scale;

- (BOOL)needReport;

- (nonnull TLObjectStatReport *)reportWithId:(nonnull TLDatabaseIdentifier *)objectId;

- (void)serialize:(nonnull TLDataOutputStream *)dataOutputStream;

+ (void)initialize;

+ (nullable TLObjectStatImpl *)deserializeWithDatabaseId:(nonnull TLDatabaseIdentifier *)databaseId data:(nonnull NSData *)data;

@end

//
// Interface: TLObjectStatQueue
//

@interface TLObjectStatQueue : NSObject

@property (nonnull, readonly) id<TLRepositoryObject> object;
@property (readonly) long value;
@property (readonly) TLRepositoryServiceStatType kind;

- (nonnull instancetype)initWithObject:(nonnull id<TLRepositoryObject>)object statType:(TLRepositoryServiceStatType)statType value:(long)value;

@end

//
// Interface: TLFindResult
//

@interface TLFindResult ()

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object;

@end

//
// Interface: TLRepositoryService
//
@interface TLRepositoryService ()

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration factories:(nonnull NSArray<id<TLRepositoryObjectFactory>> *)factories;

- (nonnull NSArray<TLAttributeNameValue *> *)deserializeWithContent:(nonnull NSString *)content;

- (void)notifyInvalidWithObject:(nonnull id<TLRepositoryObject>)object;

/// Find the repository object which is associated with the twincode inbound key.
- (nullable id<TLRepositoryObject>)findObjectWithKey:(nonnull NSUUID *)key;

@end


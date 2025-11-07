/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBaseService.h"
#import "TLDatabase.h"

@class TLAttributeNameValue;
@class TLTwincodeInbound;
@class TLTwincodeOutbound;
@class TLDatabaseIdentifier;
@class TLFilter;

typedef enum {
    TLRepositoryServiceAccessRightsPrivate,
    TLRepositoryServiceAccessRightsPublic,
    TLRepositoryServiceAccessRightsExclusive
} TLRepositoryServiceAccessRights;

/// Statistics collected for a contact or group.
typedef enum {
    TLRepositoryServiceStatTypeNbMessageSent,
    TLRepositoryServiceStatTypeNbFileSent,
    TLRepositoryServiceStatTypeNbImageSent,
    TLRepositoryServiceStatTypeNbVideoSent,
    TLRepositoryServiceStatTypeNbAudioSent,
    TLRepositoryServiceStatTypeNbGeolocationSent,
    TLRepositoryServiceStatTypeNbTwincodeSent,
    TLRepositoryServiceStatTypeNbMessageReceived,
    TLRepositoryServiceStatTypeNbFileReceived,
    TLRepositoryServiceStatTypeNbImageReceived,
    TLRepositoryServiceStatTypeNbVideoReceived,
    TLRepositoryServiceStatTypeNbAudioReceived,
    TLRepositoryServiceStatTypeNbGeolocationReceived,
    TLRepositoryServiceStatTypeNbTwincodeReceived,
    TLRepositoryServiceStatTypeNbAudioCallSent,
    TLRepositoryServiceStatTypeNbVideoCallSent,
    TLRepositoryServiceStatTypeNbAudioCallReceived,
    TLRepositoryServiceStatTypeNbVideoCallReceived,
    TLRepositoryServiceStatTypeNbAudioCallMissed,
    TLRepositoryServiceStatTypeNbVideoCallMissed,
    TLRepositoryServiceStatTypeAudioCallSentDuration,
    TLRepositoryServiceStatTypeVideoCallSentDuration,
    TLRepositoryServiceStatTypeAudioCallReceivedDuration,
    TLRepositoryServiceStatTypeVideoCallReceivedDuration,
    TLRepositoryServiceStatTypeLast
} TLRepositoryServiceStatType;

//
// Interface: TLObjectWeight
//

@interface TLObjectWeight : NSObject

@property (readonly) double points;
@property (readonly) double scale;

- (nonnull instancetype)initWithScale:(double)scale points:(double)points;

@end

//
// Interface: TLObjectStatReport
//

@interface TLObjectStatReport : NSObject

@property (nonnull, readonly) TLDatabaseIdentifier *objectId;
@property (nonnull, readonly) int *statCounters;

@end

//
// Interface: TLStatReport
//

@interface TLStatReport : NSObject

@property (nonnull, readonly) NSArray<TLObjectStatReport *> *stats;
@property (readonly) int objectCount;
@property (readonly) int certifiedCount;
@property (readonly) int invitationCodeCount;

- (nonnull instancetype)initWithStats:(nonnull NSArray<TLObjectStatReport *> *)stats objectCount:(int)objectCount certifiedCount:(int)certifiedCount invitationCodeCount:(int)invitationCodeCount;

@end

//
// Interface: TLRepositoryObject
//

/**
 * Repository object interface that should be implemented by SpaceSettings, Space, Profile, Contact, Group, ...
 *
 * When the object is loaded from the database or imported from the server, the repository service will
 * automatically load the associated twincodeInbound, twincodeOutbound, peerTwincodeOutbound and owner object instance.
 * It will then call `isValid()` to verify that the object can still be used.  When an object becomes invalid,
 * it is passed through the `onInvalidObject()` observer.
 */
@protocol TLRepositoryObject <TLDatabaseObject>

@property (nullable) id<TLRepositoryObject> owner;
@property (nullable) TLTwincodeInbound *twincodeInbound;
@property (nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property int64_t modificationDate;

- (nonnull NSString *)name;

- (nonnull NSString *)objectDescription;

- (nonnull NSArray<TLAttributeNameValue *> *)attributesWithAll:(BOOL)exportAll;

/// Check whether the object instance is valid.  After creating an instance with the RepositoryObjectFactory,
/// the RepositoryService will verify the validity of the object.  If it becomes invalid, it will notify
/// through the observer that the repository object is invalid and the twinme framework must destroy the
/// object with appropriate methods.
/// @return true if the object is valid.
- (BOOL)isValid;

/// Check whether it is possible to make a P2P connection to this contact by using the peer twincode.
- (BOOL)canCreateP2P;

@end

//
// Protocol: TLRepositoryImportService
//

/**
 * Interface used when importing a RepositoryObject from the server or from a previous database version.
 */
@protocol TLRepositoryImportService

- (void)importWithObject:(nonnull id<TLRepositoryObject>)object twincodeFactoryId:(nullable NSUUID *)twincodeFactoryId twincodeInboundId:(nullable NSUUID *)twincodeInboundId twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId peerTwincodeOutboundId:(nullable NSUUID *)peerTwincodeOutboundId ownerId:(nullable NSUUID *)ownerId;

@end

#define TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND       0x01
#define TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND      0x02
#define TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND 0x04
#define TL_REPOSITORY_OBJECT_FACTORY_USE_ALL           (TL_REPOSITORY_OBJECT_FACTORY_USE_INBOUND | TL_REPOSITORY_OBJECT_FACTORY_USE_OUTBOUND | TL_REPOSITORY_OBJECT_FACTORY_USE_PEER_OUTBOUND)

/**
 * Factory interface used by the repository service to create high level objects (Profile, Contact, Group, Space, ...)
 *
 * - `createObject` is called when the repository service must create an instance after loading the object from
 *   the database for the first time.  Once created, the object is put in a cache when `isValid()` has returned true.
 * - `loadObject` is called to update an object with a new content.
 * - `importObject` is called in three situations:
 *   - when the old repository database is migrated to the new implementation,
 *   - when we ask the server to create an object,
 *   - when we retrieve an object from the server.
 */
@protocol TLRepositoryObjectFactory

/// The schema ID identifies the object factory in the database.
- (nonnull NSUUID *)schemaId;

/// The schema version identifies a specific version of the object representation.
- (int)schemaVersion;

/// A bitmap of flags which indicates whether inbound, outbound and peer outbound twincodes are used.
- (int)twincodeUsage;

/// Objects created and managed by the factory are local only and must not be sent to the server.
- (BOOL)isLocal;

/// Objects are immutable or not.
- (BOOL)isImmutable;

/// Get the factory object that manages the optional owner object.  In many cases, this will
/// be the space object factory and this will be null if there is no owner.
- (nullable id<TLRepositoryObjectFactory>)ownerFactory;

/// Create an object instance (Profile, Contact, Group, Space, ...) and initialize it with the
/// values passed as parameter.
- (nonnull id<TLRepositoryObject>)createObjectWithId:(nonnull TLDatabaseIdentifier *)identifier uuid:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

/// Update the object attributes with the parameters.
- (void)loadObjectWithObject:(nonnull id<TLRepositoryObject>)object name:(nullable NSString *)name description:(nullable NSString *)description attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes modificationDate:(int64_t)modificationDate;

/// Create an object instance (Profile, Contact, Group, Space, ...) to import either from
/// the old repository implementation or from the server.
- (nonnull id<TLRepositoryObject>)importObjectWithId:(nonnull TLDatabaseIdentifier *)identifier importService:(nonnull id<TLRepositoryImportService>)importService uuid:(nonnull NSUUID *)uuid key:(nullable NSUUID *)key creationDate:(int64_t)creationDate attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes;

@end

//
// Interface: TLRepositoryServiceConfiguration
//

@interface TLRepositoryServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Interface: TLRepositoryServiceDelegate
//

@protocol TLRepositoryServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onUpdateWithObject:(nonnull id<TLRepositoryObject>)object;

- (void)onDeleteObjectWithObjectId:(nonnull NSUUID *)objectId;

/// Called by the repository service when it detects that an object is now invalid (isValid() returns false).
///
/// Note: in most cases, an object becomes invalid when the inbound twincode (private identity) was not found.
/// This could occur when the deletion of Profile/Contact/Group object is stopped in the middle.
- (void)onInvalidObjectWithObject:(nonnull id<TLRepositoryObject>)object;

@end

//
// Interface: TLFindResult
//

@interface TLFindResult : NSObject

@property (readonly, nonatomic) TLBaseServiceErrorCode errorCode;
@property (readonly, nonatomic, nullable) id<TLRepositoryObject> object;

+ (nonnull TLFindResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

+ (nonnull TLFindResult *)initWithObject:(nonnull id<TLRepositoryObject>)object;

@end

//
// Interface: TLRepositoryService
//

@interface TLRepositoryService:TLBaseService

+ (nonnull NSString *)VERSION;

- (void)getObjectWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory objectId:(nonnull NSUUID *)objectId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))block;

- (void)listObjectsWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory filter:(nullable TLFilter *)filter withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *_Nullable list))block;

- (nonnull TLFindResult *)findObjectWithInboundId:(BOOL)withInboundId uuid:(nonnull NSUUID *)uuid factories:(nonnull NSArray<id<TLRepositoryObjectFactory>>*)factories;

- (nonnull TLFindResult *)findObjectWithSignature:(nonnull NSString *)signature factories:(nonnull NSArray<id<TLRepositoryObjectFactory>>*)factories;

- (void)createObjectWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory accessRights:(TLRepositoryServiceAccessRights)accessRights withInitializer:(nonnull void (^)(id<TLRepositoryObject> _Nonnull object))initializer withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))block;

- (void)updateObjectWithObject:(nonnull id<TLRepositoryObject>)object localOnly:(BOOL)localOnly withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))block;

- (void)deleteObjectWithObject:(nonnull id<TLRepositoryObject>)object withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable uuid))block;

- (BOOL)hasObjectsWithSchemaId:(nonnull NSUUID *)schemaId;

- (void)incrementStatWithObject:(nonnull id<TLRepositoryObject>)object statType:(TLRepositoryServiceStatType)statType;

- (void)incrementStatWithObject:(nonnull id<TLRepositoryObject>)object statType:(TLRepositoryServiceStatType)statType value:(long)value;

- (void)updateStatsWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory updateScore:(BOOL)updateScore withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *_Nonnull objects))block;

- (nullable TLStatReport *)reportStatsWithSchemaId:(nonnull NSUUID *)schemaId;

- (void)checkpointStats;

- (void)setWeightTableWithSchemaId:(nonnull NSUUID *)schemaId weights:(nonnull NSArray<TLObjectWeight *> *)weights;

@end

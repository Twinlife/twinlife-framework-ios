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

#import <CocoaLumberjack.h>

#import <MobileCoreServices/MobileCoreServices.h>
#include <CommonCrypto/CommonDigest.h>
#import <KissXML.h>

#import "TLRepositoryService.h"
#import "TLRepositoryServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLManagementService.h"
#import "TLTwincodeInboundService.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLAttributeNameValue.h"
#import "TLDataImpl.h"
#import "TLArrayData.h"
#import "TLRepositoryServiceProvider.h"
#import "TLDataInputStream.h"
#import "TLDataOutputStream.h"
#import "TLCreateObjectIQ.h"
#import "TLGetObjectIQ.h"
#import "TLListObjectIQ.h"
#import "TLUpdateObjectIQ.h"
#import "TLOnCreateObjectIQ.h"
#import "TLOnGetObjectIQ.h"
#import "TLOnListObjectIQ.h"
#import "TLOnUpdateObjectIQ.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLBinaryCompactEncoder.h"
#import "TLBinaryCompactDecoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define REPOSITORY_SERVICE_VERSION @"3.1.0"

#define CREATE_OBJECT_SCHEMA_ID      @"cc1de051-04c9-49c2-827d-2d8c8545ff41"
#define ON_CREATE_OBJECT_SCHEMA_ID   @"fde9aa2f-c0e3-437a-a1d1-0121e72e43bd"
#define UPDATE_OBJECT_SCHEMA_ID      @"3bfed52d-0173-4f0d-bfd9-f5d63454ca59"
#define ON_UPDATE_OBJECT_SCHEMA_ID   @"0890ec66-0560-4b41-8e65-227119d0b008"
#define GET_OBJECT_SCHEMA_ID         @"6dc2169c-1ec8-4c4a-9842-ab26b8484813"
#define ON_GET_OBJECT_SCHEMA_ID      @"5fdf06d0-513f-4858-b416-73721f2ce309"
#define LIST_OBJECT_SCHEMA_ID        @"7d9baa6c-635e-4bda-b31a-a416322e4eec"
#define ON_LIST_OBJECT_SCHEMA_ID     @"76b7a7e2-cd6d-40da-b556-bcbf7eb56da4"
#define DELETE_OBJECT_SCHEMA_ID      @"837145fe-2656-41ec-9910-cda6f114ac9a"
#define ON_DELETE_OBJECT_SCHEMA_ID   @"64c4f4dd-b7bc-4547-849d-84f5eba047d8"

static TLBinaryPacketIQSerializer *IQ_CREATE_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_UPDATE_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_UPDATE_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_GET_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_GET_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_LIST_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_LIST_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_OBJECT_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_OBJECT_SERIALIZER = nil;

//
// Implementation: TLObjectWeight
//

@implementation TLObjectWeight : NSObject

- (nonnull instancetype)initWithScale:(double)scale points:(double)points {
    
    self = [super init];
    _scale = scale;
    _points = points;
    return self;
}

@end

//
// Implementation: TLObjectStatImpl
//

#undef LOG_TAG
#define LOG_TAG @"TLObjectStatImpl"

// Order in which the stats are serialized and de-serialized (for version 3).
// - new stats TLRepositoryServiceStatTypeNbTwincodeSent and TLRepositoryServiceStatTypeNbTwincodeReceived
static const TLRepositoryServiceStatType OBJECT_STAT_SERIALIZE_ORDER_LIST[] = {
    TLRepositoryServiceStatTypeNbMessageSent,
    TLRepositoryServiceStatTypeNbFileSent,
    TLRepositoryServiceStatTypeNbImageSent,
    TLRepositoryServiceStatTypeNbVideoSent,
    TLRepositoryServiceStatTypeNbAudioSent,
    TLRepositoryServiceStatTypeNbGeolocationSent,
    TLRepositoryServiceStatTypeNbMessageReceived,
    TLRepositoryServiceStatTypeNbFileReceived,
    TLRepositoryServiceStatTypeNbImageReceived,
    TLRepositoryServiceStatTypeNbVideoReceived,
    TLRepositoryServiceStatTypeNbAudioReceived,
    TLRepositoryServiceStatTypeNbGeolocationReceived,
    TLRepositoryServiceStatTypeNbAudioCallSent,
    TLRepositoryServiceStatTypeNbVideoCallSent,
    TLRepositoryServiceStatTypeNbAudioCallReceived,
    TLRepositoryServiceStatTypeNbVideoCallReceived,
    TLRepositoryServiceStatTypeNbAudioCallMissed,
    TLRepositoryServiceStatTypeNbVideoCallMissed,
    TLRepositoryServiceStatTypeAudioCallSentDuration,
    TLRepositoryServiceStatTypeVideoCallSentDuration,
    TLRepositoryServiceStatTypeAudioCallReceivedDuration
};
static const int OBJECT_STAT_SERIALIZE_COUNT = sizeof(OBJECT_STAT_SERIALIZE_ORDER_LIST) / sizeof(OBJECT_STAT_SERIALIZE_ORDER_LIST[0]);

// Order in which the stats are serialized and de-serialized (for version 2).
// - new stats TLRepositoryServiceStatTypeNbGeolocationSent and TLRepositoryServiceStatTypeNbGeolocationReceived
static const TLRepositoryServiceStatType OBJECT_STAT_SERIALIZE_2_ORDER_LIST[] = {
    TLRepositoryServiceStatTypeNbMessageSent,
    TLRepositoryServiceStatTypeNbFileSent,
    TLRepositoryServiceStatTypeNbImageSent,
    TLRepositoryServiceStatTypeNbVideoSent,
    TLRepositoryServiceStatTypeNbAudioSent,
    TLRepositoryServiceStatTypeNbGeolocationSent,
    TLRepositoryServiceStatTypeNbMessageReceived,
    TLRepositoryServiceStatTypeNbFileReceived,
    TLRepositoryServiceStatTypeNbImageReceived,
    TLRepositoryServiceStatTypeNbVideoReceived,
    TLRepositoryServiceStatTypeNbAudioReceived,
    TLRepositoryServiceStatTypeNbGeolocationReceived,
    TLRepositoryServiceStatTypeNbAudioCallSent,
    TLRepositoryServiceStatTypeNbVideoCallSent,
    TLRepositoryServiceStatTypeNbAudioCallReceived,
    TLRepositoryServiceStatTypeNbVideoCallReceived,
    TLRepositoryServiceStatTypeNbAudioCallMissed,
    TLRepositoryServiceStatTypeNbVideoCallMissed,
    TLRepositoryServiceStatTypeAudioCallSentDuration,
    TLRepositoryServiceStatTypeVideoCallSentDuration,
    TLRepositoryServiceStatTypeAudioCallReceivedDuration
};
static const int OBJECT_STAT_SERIALIZE_2_COUNT = sizeof(OBJECT_STAT_SERIALIZE_2_ORDER_LIST) / sizeof(OBJECT_STAT_SERIALIZE_2_ORDER_LIST[0]);

// Order in which the stats are serialized and de-serialized (for version 1).
static const TLRepositoryServiceStatType OBJECT_STAT_SERIALIZE_1_ORDER_LIST[] = {
    TLRepositoryServiceStatTypeNbMessageSent,
    TLRepositoryServiceStatTypeNbFileSent,
    TLRepositoryServiceStatTypeNbImageSent,
    TLRepositoryServiceStatTypeNbVideoSent,
    TLRepositoryServiceStatTypeNbAudioSent,
    TLRepositoryServiceStatTypeNbMessageReceived,
    TLRepositoryServiceStatTypeNbFileReceived,
    TLRepositoryServiceStatTypeNbImageReceived,
    TLRepositoryServiceStatTypeNbVideoReceived,
    TLRepositoryServiceStatTypeNbAudioReceived,
    TLRepositoryServiceStatTypeNbAudioCallSent,
    TLRepositoryServiceStatTypeNbVideoCallSent,
    TLRepositoryServiceStatTypeNbAudioCallReceived,
    TLRepositoryServiceStatTypeNbVideoCallReceived,
    TLRepositoryServiceStatTypeNbAudioCallMissed,
    TLRepositoryServiceStatTypeNbVideoCallMissed,
    TLRepositoryServiceStatTypeAudioCallSentDuration,
    TLRepositoryServiceStatTypeVideoCallSentDuration,
    TLRepositoryServiceStatTypeAudioCallReceivedDuration
};
static const int OBJECT_STAT_SERIALIZE_1_COUNT = sizeof(OBJECT_STAT_SERIALIZE_1_ORDER_LIST) / sizeof(OBJECT_STAT_SERIALIZE_1_ORDER_LIST[0]);

static const int OBJECT_STAT_SCHEMA_VERSION = 3;
static const int OBJECT_STAT_SCHEMA_VERSION_2 = 2;
static const int OBJECT_STAT_SCHEMA_VERSION_1 = 1;
static NSUUID *OBJECT_STAT_SCHEMA_ID = nil;

#pragma mark - TLRepositoryPendingRequest

//
// Implementation: TLRepositoryPendingRequest
//

@implementation TLRepositoryPendingRequest

@end

#undef LOG_TAG
#define LOG_TAG @"TLStatReport"

//
// Implementation: TLStatReport
//

@implementation TLStatReport

- (nonnull instancetype)initWithStats:(nonnull NSArray<TLObjectStatReport *> *)stats objectCount:(int)objectCount certifiedCount:(int)certifiedCount invitationCodeCount:(int)invitationCodeCount {
    DDLogVerbose(@"%@ initWithStats: %@ objectCount: %d certifiedCount: %d invitationCodeCount: %d", LOG_TAG, stats, objectCount, certifiedCount, invitationCodeCount);

    self = [super init];
    if (self) {
        _stats = stats;
        _objectCount = objectCount;
        _certifiedCount = certifiedCount;
        _invitationCodeCount = invitationCodeCount;
    }
    return self;
}

@end

//
// Implementation: TLCreateObjectRepositoryPendingRequest
//

@implementation TLCreateObjectRepositoryPendingRequest

-(nonnull instancetype)initWithFactory:(nonnull TLRepositoryObjectFactoryImpl *)factory immutable:(BOOL)immutable attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes objectKey:(nullable NSUUID *)objectKey complete:(nonnull TLCreateObjectComplete)complete {
    DDLogVerbose(@"%@ initWithFactory: %@ immutable: %d attributes: %@ objectKey: %@", LOG_TAG, factory, immutable, attributes, objectKey);

    self = [super init];
    if (self) {
        _factory = factory;
        _attributes = attributes;
        _immutable = immutable;
        _objectKey = objectKey;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLGetObjectRepositoryPendingRequest
//

@implementation TLGetObjectRepositoryPendingRequest

-(nonnull instancetype)initWithObjectId:(nonnull NSUUID *)objectId factory:(nonnull TLRepositoryObjectFactoryImpl *)factory complete:(nonnull TLGetObjectComplete)complete {
    DDLogVerbose(@"%@ initWithObjectId: %@ factory: %@", LOG_TAG, objectId, factory);

    self = [super init];
    if (self) {
        _objectId = objectId;
        _factory = factory;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLUpdateObjectRepositoryPendingRequest
//

@implementation TLUpdateObjectRepositoryPendingRequest

-(nonnull instancetype)initWithObject:(nonnull id<TLRepositoryObject>)object complete:(nonnull TLGetObjectComplete)complete {
    DDLogVerbose(@"%@ initWithObjectId: %@", LOG_TAG, object);

    self = [super init];
    if (self) {
        _object = object;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLListObjectRepositoryPendingRequest
//

@implementation TLListObjectRepositoryPendingRequest

-(nonnull instancetype)initWithComplete:(nonnull TLListObjectComplete)complete {
    DDLogVerbose(@"%@ initWithComplete: %@", LOG_TAG, complete);

    self = [super init];
    if (self) {
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLDeleteObjectRepositoryPendingRequest
//

@implementation TLDeleteObjectRepositoryPendingRequest

-(nonnull instancetype)initWithObject:(nonnull id<TLRepositoryObject>)object complete:(nonnull TLDeleteObjectComplete)complete {
    DDLogVerbose(@"%@ initWithObject: %@", LOG_TAG, object);

    self = [super init];
    if (self) {
        _object = object;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLObjectStatReport
//

#undef LOG_TAG
#define LOG_TAG @"TLObjectStatReport"

@implementation TLObjectStatReport

- (nonnull instancetype)initWithId:(nonnull TLDatabaseIdentifier *)objectId {
    DDLogVerbose(@"%@ initWithId: %@", LOG_TAG, objectId);

    self = [super init];
    if (self) {
        _objectId = objectId;
        _statCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
    }
    return self;
}

- (void)dealloc {
    DDLogVerbose(@"%@ dealloc", LOG_TAG);

    free(_statCounters);
}

@end

//
// Implementation: TLObjectStatImpl
//

@implementation TLObjectStatImpl : NSObject

#undef LOG_TAG
#define LOG_TAG @"TLObjectStatImpl"

+ (void)initialize {
    
    OBJECT_STAT_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"859eee5f-8fb4-44a2-acf2-e14d3c12c160"];
}

- (nonnull instancetype)initWithId:(nonnull TLDatabaseIdentifier *)identifier {
    DDLogVerbose(@"%@ initWithId: %@", LOG_TAG, identifier);
    
    self = [super init];
    if (self) {
        _databaseId = identifier;
        _statCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
        _referenceCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
        _score = 0.0;
        _scale = 1.0;
        _points = 0.0;
    }
    return self;
}

- (nonnull instancetype)initWithId:(nonnull TLDatabaseIdentifier *)databaseId score:(double)score scale:(double)scale points:(double)points statCounters:(nonnull int *)statCounters referenceCounters:(nonnull int*)referenceCounters  lastMessageDate:(int64_t)lastMessageDate {
    DDLogVerbose(@"%@ initWithId: %@ score: %f %f %f %lld", LOG_TAG, databaseId, score, scale, points, lastMessageDate);
    
    self = [super init];
    if (self) {
        _databaseId = databaseId;
        _score = score;
        _scale = scale;
        _points = points;
        _statCounters = statCounters;
        _referenceCounters = referenceCounters;
        _lastMessageDate = lastMessageDate;
    }
    return self;
}

- (void)dealloc {
    DDLogVerbose(@"%@ dealloc", LOG_TAG);
    
    free(_statCounters);
    free(_referenceCounters);
}

- (void)incrementWithStatType:(TLRepositoryServiceStatType)statType weights:(nullable NSArray<TLObjectWeight *> *)weights {
    DDLogVerbose(@"%@ incrementWithStatType: %d weights: %@", LOG_TAG, statType, weights);
    
    self.statCounters[statType]++;
    self.lastMessageDate = [[NSDate date] timeIntervalSince1970] * 1000;
    if (weights && statType < weights.count) {
        TLObjectWeight *w = weights[statType];
        if (w) {
            self.points = self.points + w.points;
            self.scale = self.scale * w.scale;
        }
    }
}

- (void)incrementWithStatType:(TLRepositoryServiceStatType)statType weights:(nullable NSArray<TLObjectWeight *> *)weights value:(long)value {
    DDLogVerbose(@"%@ incrementWithStatType: %d weights: %@ value: %ld", LOG_TAG, statType, weights, value);
    
    switch (statType) {
        case TLRepositoryServiceStatTypeAudioCallSentDuration:
            [self incrementWithStatType:TLRepositoryServiceStatTypeNbAudioCallSent weights:weights];
            self.statCounters[statType] += value;
            break;
            
        case TLRepositoryServiceStatTypeAudioCallReceivedDuration:
            [self incrementWithStatType:TLRepositoryServiceStatTypeNbAudioCallReceived weights:weights];
            self.statCounters[statType] += value;
            break;
            
        case TLRepositoryServiceStatTypeVideoCallSentDuration:
            [self incrementWithStatType:TLRepositoryServiceStatTypeNbVideoCallSent weights:weights];
            self.statCounters[statType] += value;
            break;
            
        case TLRepositoryServiceStatTypeVideoCallReceivedDuration:
            [self incrementWithStatType:TLRepositoryServiceStatTypeNbVideoCallReceived weights:weights];
            self.statCounters[statType] += value;
            break;
            
        default:
            // Refuse other stats.
            break;
    }
}

- (BOOL)updateScoreWithScale:(double)scale {
    DDLogVerbose(@"%@ updateScoreWithScale: %f", LOG_TAG, scale);
    
    double oldScore = self.score;
    self.score = self.score * scale + self.points;
    self.points = 0.0;
    self.scale = 1.0;
    return oldScore != self.score;
}

- (BOOL)needReport {
    DDLogVerbose(@"%@ needReport", LOG_TAG);
    
    for (int i = 0; i < TLRepositoryServiceStatTypeLast; i++) {
        if (self.statCounters[i] != self.referenceCounters[i]) {
            return YES;
        }
    }
    return NO;
}

- (nonnull TLObjectStatReport *)reportWithId:(nonnull TLDatabaseIdentifier *)objectId {
    DDLogVerbose(@"%@ needReport", LOG_TAG);
    
    TLObjectStatReport *result = [[TLObjectStatReport alloc] initWithId:objectId];
    for (int i = 0; i < TLRepositoryServiceStatTypeLast; i++) {
        result.statCounters[i] = self.statCounters[i] - self.referenceCounters[i];
    }
    return result;
}

- (BOOL)checkpoint {
    DDLogVerbose(@"%@ checkpoint", LOG_TAG);
    
    BOOL result = NO;
    for (int i = 0; i < TLRepositoryServiceStatTypeLast; i++) {
        if (self.statCounters[i] != self.referenceCounters[i]) {
            self.referenceCounters[i] = self.statCounters[i];
            result = YES;
        }
    }
    return result;
}

- (void)serialize:(nonnull TLDataOutputStream *)dataOutputStream {
    DDLogVerbose(@"%@ serialize: %@", LOG_TAG, dataOutputStream);
    
    [dataOutputStream writeUUID:OBJECT_STAT_SCHEMA_ID];
    [dataOutputStream writeInt:OBJECT_STAT_SCHEMA_VERSION];
    [dataOutputStream writeDouble:self.score];
    [dataOutputStream writeDouble:self.scale];
    [dataOutputStream writeDouble:self.points];
    [dataOutputStream writeInt64:self.lastMessageDate];
    
    for (int i = 0; i < OBJECT_STAT_SERIALIZE_COUNT; i++) {
        [dataOutputStream writeInt:self.statCounters[OBJECT_STAT_SERIALIZE_ORDER_LIST[i]]];
    }
    for (int i = 0; i < OBJECT_STAT_SERIALIZE_COUNT; i++) {
        [dataOutputStream writeInt:self.referenceCounters[OBJECT_STAT_SERIALIZE_ORDER_LIST[i]]];
    }
}

+ (nullable TLObjectStatImpl *)deserializeWithDatabaseId:(nonnull TLDatabaseIdentifier *)databaseId data:(nonnull NSData *)data {
    DDLogVerbose(@"%@ deserializeWithDatabaseId: %@", LOG_TAG, databaseId);

    TLDataInputStream *dataInputStream = [[TLDataInputStream alloc] initWithData:data];
    NSUUID* schemaId = [dataInputStream readUUID];
    if (![OBJECT_STAT_SCHEMA_ID isEqual:schemaId]) {
        return nil;
    }
    int schemaVersion = [dataInputStream readInt];
    if (schemaVersion == OBJECT_STAT_SCHEMA_VERSION_1) {
        double score = [dataInputStream readDouble];
        double scale = [dataInputStream readDouble];
        double points = [dataInputStream readDouble];
        int64_t lastMessageDate = [dataInputStream readInt64];

        int *statCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
        int *referenceCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
        for (int i = 0; i < OBJECT_STAT_SERIALIZE_1_COUNT; i++) {
            statCounters[OBJECT_STAT_SERIALIZE_1_ORDER_LIST[i]] = [dataInputStream readInt];
        }
        for (int i = 0; i < OBJECT_STAT_SERIALIZE_1_COUNT; i++) {
            referenceCounters[OBJECT_STAT_SERIALIZE_1_ORDER_LIST[i]] = [dataInputStream readInt];
        }

        if ([dataInputStream isCompleted]) {
            return [[TLObjectStatImpl alloc] initWithId:databaseId score:score scale:scale points:points statCounters:statCounters referenceCounters:referenceCounters lastMessageDate:lastMessageDate];
        } else {
            free(statCounters);
            free(referenceCounters);
            return nil;
        }
    }
    if (schemaVersion == OBJECT_STAT_SCHEMA_VERSION_2) {
        double score = [dataInputStream readDouble];
        double scale = [dataInputStream readDouble];
        double points = [dataInputStream readDouble];
        int64_t lastMessageDate = [dataInputStream readInt64];
        
        int *statCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
        int *referenceCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
        for (int i = 0; i < OBJECT_STAT_SERIALIZE_2_COUNT; i++) {
            statCounters[OBJECT_STAT_SERIALIZE_2_ORDER_LIST[i]] = [dataInputStream readInt];
        }
        for (int i = 0; i < OBJECT_STAT_SERIALIZE_2_COUNT; i++) {
            referenceCounters[OBJECT_STAT_SERIALIZE_2_ORDER_LIST[i]] = [dataInputStream readInt];
        }
        
        if ([dataInputStream isCompleted]) {
            return [[TLObjectStatImpl alloc] initWithId:databaseId score:score scale:scale points:points statCounters:statCounters referenceCounters:referenceCounters lastMessageDate:lastMessageDate];
        } else {
            free(statCounters);
            free(referenceCounters);
            return nil;
        }
    }
    if (schemaVersion != OBJECT_STAT_SCHEMA_VERSION) {
        return nil;
    }
    double score = [dataInputStream readDouble];
    double scale = [dataInputStream readDouble];
    double points = [dataInputStream readDouble];
    int64_t lastMessageDate = [dataInputStream readInt64];
    
    int *statCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
    int *referenceCounters = (int*) calloc(TLRepositoryServiceStatTypeLast, sizeof(int));
    for (int i = 0; i < OBJECT_STAT_SERIALIZE_COUNT; i++) {
        statCounters[OBJECT_STAT_SERIALIZE_ORDER_LIST[i]] = [dataInputStream readInt];
    }
    for (int i = 0; i < OBJECT_STAT_SERIALIZE_COUNT; i++) {
        referenceCounters[OBJECT_STAT_SERIALIZE_ORDER_LIST[i]] = [dataInputStream readInt];
    }
    
    if ([dataInputStream isCompleted]) {
        return [[TLObjectStatImpl alloc] initWithId:databaseId score:score scale:scale points:points statCounters:statCounters referenceCounters:referenceCounters lastMessageDate:lastMessageDate];
    } else {
        free(statCounters);
        free(referenceCounters);
        return nil;
    }
}

@end

//
// Implementation: TLObjectStatQueue
//

#undef LOG_TAG
#define LOG_TAG @"TLObjectStatQueue"

@implementation TLObjectStatQueue

- (nonnull instancetype)initWithObject:(nonnull id<TLRepositoryObject>)object statType:(TLRepositoryServiceStatType)statType value:(long)value {
    DDLogVerbose(@"%@ initWithObject: %@ statType: %d value: %ld", LOG_TAG, object, statType, value);
    
    self = [super init];
    _object = object;
    _kind = statType;
    _value = value;
    return self;
}

@end

//
// Implementation: TLFindResult
//
#undef LOG_TAG
#define LOG_TAG @"TLFindResult"

@implementation TLFindResult

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode object:(nullable id<TLRepositoryObject>)object {
    
    self = [super init];
    if (self) {
        _errorCode = errorCode;
        _object = object;
    }
    return self;
}

+ (nonnull TLFindResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogError(@"%@ errorWithErrorCode: %d", LOG_TAG, errorCode);

    return [[TLFindResult alloc] initWithErrorCode:errorCode object:nil];
}

+ (nonnull TLFindResult *)initWithObject:(nonnull id<TLRepositoryObject>)object {

    return [[TLFindResult alloc] initWithErrorCode:TLBaseServiceErrorCodeSuccess object:object];
}

@end

//
// Implementation: TLRepositoryServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLRepositoryServiceConfiguration"

@implementation TLRepositoryServiceConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdRepositoryService version:[TLRepositoryService VERSION] serviceOn:NO];
}

@end

//
// Interface: TLRepositoryService
//

@interface TLRepositoryService ()

@property (readonly, nonnull) TLRepositoryServiceProvider *serviceProvider;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLRepositoryPendingRequest *> *pendingRequests;
@property (nullable) NSMutableArray<TLObjectStatQueue *> *statQueue;
@property (readonly, nonnull) NSMutableDictionary<NSUUID *, NSArray<TLObjectWeight *> *> *weights;
@property (readonly, nonnull) NSMutableDictionary<TLDatabaseIdentifier *, TLObjectStatImpl *> *objectStats;

@end

//
// Implementation: TLRepositoryService
//

#undef LOG_TAG
#define LOG_TAG @"TLRepositoryService"

@implementation TLRepositoryService

+ (void)initialize {

    IQ_CREATE_OBJECT_SERIALIZER = [[TLCreateObjectIQSerializer alloc] initWithSchema:CREATE_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_ON_CREATE_OBJECT_SERIALIZER = [[TLOnCreateObjectIQSerializer alloc] initWithSchema:ON_CREATE_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_UPDATE_OBJECT_SERIALIZER = [[TLUpdateObjectIQSerializer alloc] initWithSchema:UPDATE_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_ON_UPDATE_OBJECT_SERIALIZER = [[TLOnUpdateObjectIQSerializer alloc] initWithSchema:ON_UPDATE_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_GET_OBJECT_SERIALIZER = [[TLGetObjectIQSerializer alloc] initWithSchema:GET_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_ON_GET_OBJECT_SERIALIZER = [[TLOnGetObjectIQSerializer alloc] initWithSchema:ON_GET_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_LIST_OBJECT_SERIALIZER = [[TLListObjectIQSerializer alloc] initWithSchema:LIST_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_ON_LIST_OBJECT_SERIALIZER = [[TLOnListObjectIQSerializer alloc] initWithSchema:ON_LIST_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_DELETE_OBJECT_SERIALIZER = [[TLGetObjectIQSerializer alloc] initWithSchema:DELETE_OBJECT_SCHEMA_ID schemaVersion:1];
    IQ_ON_DELETE_OBJECT_SERIALIZER = [[TLBinaryPacketIQSerializer alloc] initWithSchema:ON_DELETE_OBJECT_SCHEMA_ID schemaVersion:1];
}

+ (nonnull NSString *)VERSION {
    
    return REPOSITORY_SERVICE_VERSION;
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    if (self) {
        _serializerFactory = twinlife.serializerFactory;
        _pendingRequests = [[NSMutableDictionary alloc] init];
        _serviceProvider = [[TLRepositoryServiceProvider alloc] initWithService:self database:twinlife.databaseService];
        _weights = [[NSMutableDictionary alloc] init];
        _objectStats = [[NSMutableDictionary alloc] init];

        // Register the binary IQ handlers for the responses.
        [twinlife addPacketListener:IQ_ON_CREATE_OBJECT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onCreateObjectWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_GET_OBJECT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onGetObjectWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_UPDATE_OBJECT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onUpdateObjectWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_LIST_OBJECT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onListObjectWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_DELETE_OBJECT_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onDeleteObjectWithIQ:iq];
        }];
    }
    return self;
}

#pragma mark - BaseServiceImpl

- (void)addDelegate:(nonnull id<TLBaseServiceDelegate>)delegate {
    
    if ([delegate conformsToProtocol:@protocol(TLRepositoryServiceDelegate)]) {
        [super addDelegate:delegate];
    }
}

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration factories:(nonnull NSArray<id<TLRepositoryObjectFactory>> *)factories {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLRepositoryServiceConfiguration* repositoryServiceConfiguration = [[TLRepositoryServiceConfiguration alloc] init];
    TLRepositoryServiceConfiguration* serviceConfiguration = (TLRepositoryServiceConfiguration *) baseServiceConfiguration;
    repositoryServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    [self.serviceProvider configureWithFactories:factories];
    self.configured = YES;
    self.serviceConfiguration = repositoryServiceConfiguration;
    self.serviceOn = repositoryServiceConfiguration.isServiceOn;
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);
    
    // Clear the object stats cache because they could be changed while we are suspended.
    @synchronized (self) {
        [self.objectStats removeAllObjects];
    }
}

#pragma mark - TLRepositoryService

- (void)getObjectWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory objectId:(nonnull NSUUID *)objectId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))block {
    DDLogVerbose(@"%@ getObjectWithFactory: %@ objectId: %@", LOG_TAG, factory, objectId);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSUUID *schemaId = factory.schemaId;
    TLRepositoryObjectFactoryImpl *dbFactory = [self.serviceProvider factoryWithSchemaId:schemaId];
    if (!dbFactory) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }

    id<TLRepositoryObject> object = [self.serviceProvider loadObjectWithFactory:dbFactory dbId:0 uuid:objectId];
    if (object) {
        block(TLBaseServiceErrorCodeSuccess, object);
        return;
    }

    if (factory.isLocal) {
        block(TLBaseServiceErrorCodeItemNotFound, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLGetObjectRepositoryPendingRequest alloc] initWithObjectId:objectId factory:dbFactory complete:block];
    }

    TLGetObjectIQ *iq = [[TLGetObjectIQ alloc] initWithSerializer:IQ_GET_OBJECT_SERIALIZER requestId:requestId.longLongValue objectSchemaId:schemaId objectId:objectId];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)listObjectsWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory filter:(nullable TLFilter *)filter withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *_Nullable list))block {
    DDLogVerbose(@"%@ listObjectsWithFactory: %@ filter: %@", LOG_TAG, factory, filter);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSUUID *schemaId = factory.schemaId;
    TLRepositoryObjectFactoryImpl *dbFactory = [self.serviceProvider factoryWithSchemaId:schemaId];
    if (!dbFactory) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }

    NSArray<id<TLRepositoryObject>> *objects = [self.serviceProvider listObjectsWithFactory:dbFactory filter:filter];
    block(TLBaseServiceErrorCodeSuccess, objects);
}

- (nonnull TLFindResult *)findObjectWithInboundId:(BOOL)withInboundId uuid:(nonnull NSUUID *)uuid factories:(nonnull NSArray<id<TLRepositoryObjectFactory>>*)factories {
    DDLogVerbose(@"%@ findObjectWithInboundId: %d uuid: %@ factories: %@", LOG_TAG, withInboundId, uuid, factories);
    
    if (!self.serviceOn) {
        return [TLFindResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }
    
    NSMutableArray<TLRepositoryObjectFactoryImpl *> *dbFactories = [[NSMutableArray alloc] initWithCapacity:factories.count];
    for (id<TLRepositoryObjectFactory> factory in factories) {
        TLRepositoryObjectFactoryImpl *dbFactory = [self.serviceProvider factoryWithSchemaId:factory.schemaId];
        if (!dbFactory) {
            return [TLFindResult errorWithErrorCode:TLBaseServiceErrorCodeBadRequest];
        }
        [dbFactories addObject:dbFactory];
    }
    
    id<TLRepositoryObject> object = [self.serviceProvider findObjectWithInboundId:withInboundId uuid:uuid factories:dbFactories];
    if (!object) {
        return [TLFindResult errorWithErrorCode:TLBaseServiceErrorCodeItemNotFound];
    }
    return [TLFindResult initWithObject:object];
}

- (nonnull TLFindResult *)findObjectWithSignature:(nonnull NSString *)signature factories:(nonnull NSArray<id<TLRepositoryObjectFactory>>*)factories {
    DDLogVerbose(@"%@ findObjectWithSignature: %@", LOG_TAG, signature);
    
    if (!self.serviceOn) {
        return [TLFindResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }
    
    NSMutableArray<TLRepositoryObjectFactoryImpl *> *dbFactories = [[NSMutableArray alloc] initWithCapacity:factories.count];
    for (id<TLRepositoryObjectFactory> factory in factories) {
        TLRepositoryObjectFactoryImpl *dbFactory = [self.serviceProvider factoryWithSchemaId:factory.schemaId];
        if (!dbFactory) {
            return [TLFindResult errorWithErrorCode:TLBaseServiceErrorCodeBadRequest];
        }
        [dbFactories addObject:dbFactory];
    }
    
    TLVerifyAuthenticateResult *result = [[self.twinlife getCryptoService] verifyAuthenticateWithSignature:signature];
    if (result.errorCode != TLBaseServiceErrorCodeSuccess) {
        return [TLFindResult errorWithErrorCode:result.errorCode];
    }

    id<TLRepositoryObject> object = [self.serviceProvider findObjectWithInboundId:NO uuid:result.subjectId factories:dbFactories];
    if (!object) {
        return [TLFindResult errorWithErrorCode:TLBaseServiceErrorCodeItemNotFound];
    }
    return [TLFindResult initWithObject:object];
}

- (nullable id<TLRepositoryObject>)findObjectWithKey:(nonnull NSUUID *)key {
    DDLogVerbose(@"%@ findObjectWithKey: %@", LOG_TAG, key);
    
    if (!self.serviceOn) {
        return nil;
    }

    return [self.serviceProvider findObjectWithInboundId:YES uuid:key factories:[self.serviceProvider getFactories]];
}

- (void)createObjectWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory accessRights:(TLRepositoryServiceAccessRights)accessRights withInitializer:(nonnull void (^)(id<TLRepositoryObject> _Nonnull object))initializer withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))block {
    DDLogVerbose(@"%@ createObjectWithFactory: %@", LOG_TAG, factory);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    NSUUID *schemaId = factory.schemaId;
    TLRepositoryObjectFactoryImpl *dbFactory = [self.serviceProvider factoryWithSchemaId:schemaId];
    if (!dbFactory) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }
    
    if (factory.isLocal) {
        id<TLRepositoryObject> object = [self.serviceProvider createObjectWithFactory:dbFactory uuid:[NSUUID UUID] withInitializer:initializer];
        block(object ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeNoStorageSpace, object);
        return;
    }

    int createOptions;
    switch (accessRights) {
        case TLRepositoryServiceAccessRightsPublic:
            createOptions = CREATE_OBJECT_PUBLIC;
            break;

        case TLRepositoryServiceAccessRightsPrivate:
        default:
            createOptions = CREATE_OBJECT_PRIVATE;
            break;

        case TLRepositoryServiceAccessRightsExclusive:
            createOptions = CREATE_OBJECT_EXCLUSIVE;
            break;
    }
    BOOL immutable = factory.isImmutable;
    if (immutable) {
        createOptions |= CREATE_OBJECT_IMMUTABLE;
    }

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    TLDatabaseIdentifier *tmp = [[TLDatabaseIdentifier alloc] initWithIdentifier:0 factory:dbFactory];
    id<TLRepositoryObject> object = [factory createObjectWithId:tmp uuid:[NSUUID UUID] creationDate:now name:nil description:nil attributes:nil modificationDate:now];
    initializer(object);

    NSArray<TLAttributeNameValue *> *attributes = [object attributesWithAll:YES];
    TLTwincodeInbound *twincodeInbound = [object twincodeInbound];
    NSUUID *key = twincodeInbound ? twincodeInbound.uuid : nil;
    NSString *content = [self serializeWithAttributes:attributes];
    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLCreateObjectRepositoryPendingRequest alloc] initWithFactory:dbFactory immutable:immutable attributes:attributes objectKey:key complete:block];
    }

    TLCreateObjectIQ *iq = [[TLCreateObjectIQ alloc] initWithSerializer:IQ_CREATE_OBJECT_SERIALIZER requestId:requestId.longLongValue createOptions:createOptions objectSchemaId:schemaId objectSchemaVersion:factory.schemaVersion objectKey:key objectData:content exclusiveContents:nil];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (BOOL)hasObjectsWithSchemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@ hasObjectsWithSchemaId: %@", LOG_TAG, schemaId);
    
    if (!self.serviceOn) {
        return false;
    }
    
    return [self.serviceProvider hasObjectsWithSchemaId:schemaId];
}

- (void)updateObjectWithObject:(nonnull id<TLRepositoryObject>)object localOnly:(BOOL)localOnly withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))block {
    DDLogVerbose(@"%@: updateObjectWithObject: %@ localOnly: %d", LOG_TAG, object, localOnly);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    // When the object is local only, update its instance now.
    TLDatabaseIdentifier *identifier = [object identifier];
    if ([identifier isLocal] || localOnly) {
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        [self onUpdateObjectWithObject:object modificationDate:now complete:block];
        return;
    }

    int updateOptions = 0;
    NSArray<TLAttributeNameValue *> *attributes = [object attributesWithAll:YES];
    TLTwincodeInbound *twincodeInbound = [object twincodeInbound];
    NSUUID *key = twincodeInbound ? twincodeInbound.uuid : nil;
    NSString *content = [self serializeWithAttributes:attributes];
    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLUpdateObjectRepositoryPendingRequest alloc] initWithObject:object complete:block];
    }

    TLUpdateObjectIQ *iq = [[TLUpdateObjectIQ alloc] initWithSerializer:IQ_UPDATE_OBJECT_SERIALIZER requestId:requestId.longLongValue updateOptions:updateOptions objectId:[object objectId] objectSchemaId:[identifier schemaId] objectSchemaVersion:[identifier schemaVersion] objectKey:key objectData:content exclusiveContents:nil];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)deleteObjectWithObject:(nonnull id<TLRepositoryObject>)object withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable uuid))block {
    DDLogVerbose(@"%@: deleteObjectWithObject: %@", LOG_TAG, object);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    // When the object is local only, delete its instance now.
    TLDatabaseIdentifier *identifier = [object identifier];
    if ([identifier isLocal]) {

        [self onDeleteObjectWithObject:object complete:block];
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLDeleteObjectRepositoryPendingRequest alloc] initWithObject:object complete:block];
    }

    TLGetObjectIQ *iq = [[TLGetObjectIQ alloc] initWithSerializer:IQ_DELETE_OBJECT_SERIALIZER requestId:requestId.longLongValue objectSchemaId:[identifier schemaId] objectId:[object objectId]];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)incrementStatWithObject:(nonnull id<TLRepositoryObject>)object statType:(TLRepositoryServiceStatType)statType {
    DDLogVerbose(@"%@: incrementStatWithObject: %@ statType: %d", LOG_TAG, object, statType);
    
    if (!self.serviceOn) {
        return;
    }

    TLObjectStatImpl *stats;
    TLDatabaseIdentifier *objectId = [object identifier];
    @synchronized(self) {
        // Stats are frozen, remember the new item in the queue.
        if (self.statQueue) {
            [self.statQueue addObject:[[TLObjectStatQueue alloc] initWithObject:object statType:statType value:1]];
            return;
        }
        stats = self.objectStats[objectId];
    }
    
    if (!stats) {
        stats = [self.serviceProvider loadStatWithObject:object];
        @synchronized (self) {
            TLObjectStatImpl *lStats = self.objectStats[objectId];
            if (!lStats && stats) {
                [self.objectStats setObject:stats forKey:objectId];
            } else {
                stats = lStats;
            }
        }
    }

    if (stats) {
        NSArray<TLObjectWeight *> *weights = self.weights[objectId.schemaId];
        @synchronized(self) {
            [stats incrementWithStatType:statType weights:weights];
        }
        [self.serviceProvider updateObjectWithStat:stats];
    }
}

- (void)incrementStatWithObject:(nonnull id<TLRepositoryObject>)object statType:(TLRepositoryServiceStatType)statType value:(long)value {
    DDLogVerbose(@"%@: incrementStatWithObject: %@ statType: %d value: %ld", LOG_TAG, object, statType, value);
    
    if (!self.serviceOn) {
        return;
    }

    TLObjectStatImpl *stats;
    TLDatabaseIdentifier *objectId = [object identifier];
    @synchronized(self) {
        // Stats are frozen, remember the new item in the queue.
        if (self.statQueue) {
            [self.statQueue addObject:[[TLObjectStatQueue alloc] initWithObject:object statType:statType value:1]];
            return;
        }
        stats = self.objectStats[objectId];
    }
    
    if (!stats) {
        stats = [self.serviceProvider loadStatWithObject:object];
        @synchronized (self) {
            TLObjectStatImpl *lStats = self.objectStats[objectId];
            if (!lStats && stats) {
                [self.objectStats setObject:stats forKey:objectId];
            } else {
                stats = lStats;
            }
        }
    }

    if (stats) {
        NSArray<TLObjectWeight *> *weights = self.weights[objectId.schemaId];
        @synchronized(self) {
            [stats incrementWithStatType:statType weights:weights value:value];
        }
        [self.serviceProvider updateObjectWithStat:stats];
    }
}

- (void)updateStatsWithFactory:(nonnull id<TLRepositoryObjectFactory>)factory updateScore:(BOOL)updateScore withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSArray<id<TLRepositoryObject>> *_Nonnull objects))block {
    DDLogVerbose(@"%@: updateStatsWithFactory: %@ updateScore: %d", LOG_TAG, factory, updateScore);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, [[NSMutableArray alloc] init]);
        return;
    }

    // Step 1: freeze the stats and collect the objects of the given schema with their corresponding computed scale factor.
    // NSMutableDictionary<NSUUID *, NSNumber *> *objectScales = [[NSMutableDictionary alloc] init];
    @synchronized(self) {
        if (!self.statQueue) {
            self.statQueue = [[NSMutableArray alloc] init];
        }
    }

    NSMutableArray<id<TLRepositoryObject>> *result = [[NSMutableArray alloc] initWithCapacity:0];
    /*for (TLObjectImpl *object1Impl in objectList) {

        // If there is no weights, the score value does not change (the accessTime could changed).
        if (self.weights[schemaId] && updateScore) {

            // Step 2: compute the scale to apply to this object (product of all scales excluding the current object).
            NSNumber *scale = objectScales[object1Impl.uuid];
            double newScale = scale.doubleValue;
            for (TLObjectImpl *object2Impl in objectList) {
                if (object1Impl != object2Impl) {
                    NSNumber *scale2 = objectScales[object2Impl.uuid];
                    newScale = newScale * scale2.doubleValue;
                }
            }

            // Step 3: update the score with the scale for the object and save the results.
            TLObjectStatImpl *objectStats = object1Impl.objectStats;
            if ([objectStats updateScoreWithScale:newScale]) {
                [self.serviceProvider updateObjectStatWithObjectId:object1Impl.uuid objectStats:objectStats];
            }
        }
        [result addObject:[[TLObject alloc] initWithObjectImpl:object1Impl]];
    }*/

    // Now take into account stats we have queued.
    [self flushQueueStats];

    block(TLBaseServiceErrorCodeSuccess, result);
}

- (nullable TLStatReport *)reportStatsWithSchemaId:(nonnull NSUUID *)schemaId {
    DDLogVerbose(@"%@: reportStatsWithSchemaId: %@", LOG_TAG, schemaId);
    
    if (!self.serviceOn) {
        return nil;
    }

    // Step 1: get the object stats from the database.
    NSDictionary<TLDatabaseIdentifier *, TLRepositoryStatInfo *> *stats = [self.serviceProvider loadStatsWithSchemaId:schemaId];

    // Step 2: freeze the stats and collect the objects that have stats since the last report.
    int count = 0;
    int certifiedCount = 0;
    int invitationCodeCount = 0;
    NSMutableArray<TLObjectStatReport *> *reports = [[NSMutableArray alloc] init];
    @synchronized(self) {
        // Freeze the stats and queue them.
        if (!self.statQueue) {
            self.statQueue = [[NSMutableArray alloc] init];
        }

        for (TLDatabaseIdentifier *objectId in stats) {
            TLObjectStatImpl *cachedStat = self.objectStats[objectId];
            TLRepositoryStatInfo *statInfo = stats[objectId];
            TLObjectStatImpl *objectStats = cachedStat == nil ? statInfo.stats : cachedStat;

            if (objectStats && [objectStats needReport]) {
                [reports addObject:[objectStats reportWithId:objectId]];
 
                // The stat is reported but it was not part of the cache,
                // add it so that the checkpointStats() will clear the counters correctly.
                if (!cachedStat) {
                    [self.objectStats setObject:objectStats forKey:objectId];
                }
            }
            if ((statInfo.peerTwincodeFlags & FLAG_CERTIFIED) != 0) {
                certifiedCount++;
            } else if ([TLTwincodeOutbound toTrustMethodWithFlags:statInfo.peerTwincodeFlags] == TLTrustMethodInvitationCode) {
                invitationCodeCount++;
            } else {
                count++;
            }
        }
    }

    return [[TLStatReport alloc] initWithStats:reports objectCount:count certifiedCount:certifiedCount invitationCodeCount:invitationCodeCount];
}

- (void)checkpointStats {
    DDLogVerbose(@"%@: checkpointStats", LOG_TAG);
    
    if (!self.serviceOn) {
        return;
    }

    // Step 1: make a new reference for every object and collect the objects that have new references.
    NSMutableArray<TLObjectStatImpl *> *updateStats = [[NSMutableArray alloc] init];
    @synchronized(self) {
        for (TLDatabaseIdentifier *objectId in self.objectStats) {
            TLObjectStatImpl *objectStat = self.objectStats[objectId];

            if (objectStat && [objectStat checkpoint]) {
                [updateStats addObject:objectStat];
            }
        }
    }

    // Step 2: update the objects that have new stat references.
    [self.serviceProvider updateWithStats:updateStats];

    // Now take into account stats we have queued.
    [self flushQueueStats];
}

- (void)setWeightTableWithSchemaId:(nonnull NSUUID *)schemaId weights:(nonnull NSArray<TLObjectWeight *> *)weights {
    DDLogVerbose(@"%@: setWeightTableWithSchemaId: %@ weights: %@", LOG_TAG, schemaId, weights);

    // Always allow to set the weight.
    @synchronized(self) {
        self.weights[schemaId] = weights;
    }
}

- (nonnull NSString *)serializeWithAttributes:(nonnull NSArray <TLAttributeNameValue *> *)attributes {
    
    TLArrayData *arrayData = [[TLArrayData alloc] init];
    [arrayData addAttributes:attributes];
    return [arrayData.toXml XMLString];
}

- (nonnull NSArray<TLAttributeNameValue *> *)deserializeWithContent:(nonnull NSString *)content {
    
    TLArrayData *arrayData = [[TLArrayData alloc] init];
    DDXMLElement *xmlContent = [[DDXMLElement alloc] initWithXMLString:content error:nil];
    [arrayData parse:xmlContent];
    return arrayData.attributes;
}

- (void)notifyInvalidWithObject:(nonnull id<TLRepositoryObject>)object {
    DDLogVerbose(@"%@ notifyInvalidWithObject: %@", LOG_TAG, object);

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onInvalidObjectWithObject:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLRepositoryServiceDelegate>)delegate onInvalidObjectWithObject:object];
            });
        }
    }
}

#pragma mark - TLRepositoryServiceImpl

- (void)onGetObjectWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGetObjectWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnGetObjectIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnGetObjectIQ *onGetObjectIQ = (TLOnGetObjectIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLGetObjectRepositoryPendingRequest *request;
    @synchronized (self) {
        request = (TLGetObjectRepositoryPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    // BOOL immutable = (onGetObjectIQ.objectFlags & CREATE_OBJECT_IMMUTABLE) != 0;
    NSArray<TLAttributeNameValue *> *attributes = [self deserializeWithContent:onGetObjectIQ.objectData];
    if (!attributes) {
        attributes = [[NSArray alloc] init];
    }
    id<TLRepositoryObject> object = [self.serviceProvider importObjectWithFactory:request.factory uuid:request.objectId creationDate:onGetObjectIQ.creationDate attributes:attributes objectKey:onGetObjectIQ.objectKey];

    request.complete(object ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeNoStorageSpace, object);
}

- (void)onCreateObjectWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCreateObjectWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnCreateObjectIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnCreateObjectIQ *onCreateObjectIQ = (TLOnCreateObjectIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLCreateObjectRepositoryPendingRequest *request;
    @synchronized (self) {
        request = (TLCreateObjectRepositoryPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    id<TLRepositoryObject> object = [self.serviceProvider importObjectWithFactory:request.factory uuid:onCreateObjectIQ.objectId creationDate:onCreateObjectIQ.creationDate attributes:request.attributes objectKey:request.objectKey];

    request.complete(object ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeNoStorageSpace, object);
}

- (void)onUpdateObjectWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onUpdateObjectWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnUpdateObjectIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnUpdateObjectIQ *onUpdateObjectIQ = (TLOnUpdateObjectIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLUpdateObjectRepositoryPendingRequest *request;
    @synchronized (self) {
        request = (TLUpdateObjectRepositoryPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    [self onUpdateObjectWithObject:request.object modificationDate:onUpdateObjectIQ.modificationDate complete:request.complete];
}

- (void)onListObjectWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onListObjectWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnListObjectIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnListObjectIQ *onListObjectIQ = (TLOnListObjectIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLListObjectRepositoryPendingRequest *request;
    @synchronized (self) {
        request = (TLListObjectRepositoryPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    request.complete(TLBaseServiceErrorCodeSuccess, onListObjectIQ.objectIds);
}

- (void)onDeleteObjectWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onDeleteObjectWithIQ: %@", LOG_TAG, iq);

    [self receivedBinaryIQ:iq];

    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLDeleteObjectRepositoryPendingRequest *request;
    @synchronized (self) {
        request = (TLDeleteObjectRepositoryPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    
    [self onDeleteObjectWithObject:request.object complete:request.complete];
}

- (void)onDeleteObjectWithObject:(nonnull id<TLRepositoryObject>)object complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable uuid))complete {
    DDLogVerbose(@"%@ onDeleteObjectWithObject: %@", LOG_TAG, object);
    
    [self.serviceProvider deleteObject:object];

    NSUUID *objectId = [object objectId];
    complete(TLBaseServiceErrorCodeSuccess, objectId);
    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteObjectWithObjectId:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLRepositoryServiceDelegate>)delegate onDeleteObjectWithObjectId:objectId];
            });
        }
    }
}

- (void)onUpdateObjectWithObject:(nonnull id<TLRepositoryObject>)object modificationDate:(int64_t)modificationDate complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, id<TLRepositoryObject> _Nullable object))complete{
    DDLogVerbose(@"%@ onUpdateObjectWithObject: %@", LOG_TAG, object);

    [self.serviceProvider updateWithObject:object modificationDate:modificationDate];
    
    complete(TLBaseServiceErrorCodeSuccess, object);

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateWithObject:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLRepositoryServiceDelegate>)delegate onUpdateWithObject:object];
            });
        }
    }
}

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);
    
    int64_t requestId = errorPacketIQ.requestId;
    TLBaseServiceErrorCode errorCode = errorPacketIQ.errorCode;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    TLRepositoryPendingRequest *request;

    [self receivedBinaryIQ:errorPacketIQ];
    @synchronized(self) {
        request = self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    // The object no longer exists on the server, remove it from our local database.
    if ([request isKindOfClass:[TLGetObjectRepositoryPendingRequest class]]) {
        TLGetObjectRepositoryPendingRequest *getPendingRequest = (TLGetObjectRepositoryPendingRequest *)request;

        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self.serviceProvider deleteWithUUID:getPendingRequest.objectId];
        }
        getPendingRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLUpdateObjectRepositoryPendingRequest class]]) {
        TLUpdateObjectRepositoryPendingRequest *updatePendingRequest = (TLUpdateObjectRepositoryPendingRequest *)request;

        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self.serviceProvider deleteWithObject:updatePendingRequest.object];
        }
        updatePendingRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLDeleteObjectRepositoryPendingRequest class]]) {
        TLDeleteObjectRepositoryPendingRequest *deletePendingRequest = (TLDeleteObjectRepositoryPendingRequest *)request;

        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self.serviceProvider deleteWithObject:deletePendingRequest.object];
        }
        deletePendingRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLListObjectRepositoryPendingRequest class]]) {
        TLListObjectRepositoryPendingRequest *listPendingRequest = (TLListObjectRepositoryPendingRequest *)request;

        listPendingRequest.complete(errorCode, nil);
    }
}

#pragma mark - Private methods

- (void)flushQueueStats {
    DDLogVerbose(@"%@ flushQueueStats", LOG_TAG);

    NSMutableArray<TLObjectStatQueue *> *queue;
    @synchronized (self) {
        queue = self.statQueue;
        self.statQueue = nil;
    }
    if (queue) {
        for (TLObjectStatQueue *item in queue) {
            if (item.value > 0) {
                [self incrementStatWithObject:item.object statType:item.kind value:item.value];
            } else {
                [self incrementStatWithObject:item.object statType:item.kind];
            }
        }
    }
}

@end

/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import "TLSecureRosterServiceImpl.h"

#import "TLTwinlifeImpl.h"
#import "TLServerConnection.h"
#import "TLSecureRosterService.h"
#import "TLTwincodeOutboundService.h"
#import "TLConversationServiceImpl.h"
#import "TLRepositoryService.h"
#import "TLCryptoService.h"

#import "TLBinaryCompactEncoder.h"

#import "TLCreateRosterIQ.h"
#import "TLListRosterIQ.h"
#import "TLAddRosterMemberIQ.h"
#import "TLAddRosterPublicKeyIQ.h"
#import "TLDeleteRosterMemberIQ.h"
#import "TLSecureRosterIQ.h"
#import "TLOnCreateRosterIQ.h"
#import "TLOnListRosterIQ.h"
#import "TLMemberInfo.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLGroupProtocol.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define SECURE_ROSTER_SERVICE_VERSION    @"1.0.0"

const int TLSecureRosterServiceAllowEmptyKey = 0x01;

// Schema IDs
static NSUUID *CREATE_ROSTER_SCHEMA_ID = nil;
static NSUUID *ON_CREATE_ROSTER_SCHEMA_ID = nil;
static NSUUID *LIST_ROSTER_SCHEMA_ID = nil;
static NSUUID *ON_LIST_ROSTER_SCHEMA_ID = nil;
static NSUUID *ADD_ROSTER_MEMBER_SCHEMA_ID = nil;
static NSUUID *ON_ADD_ROSTER_MEMBER_SCHEMA_ID = nil;
static NSUUID *DELETE_ROSTER_MEMBER_SCHEMA_ID = nil;
static NSUUID *ON_DELETE_ROSTER_MEMBER_SCHEMA_ID = nil;
static NSUUID *ADD_ROSTER_PUBLIC_KEY_SCHEMA_ID = nil;
static NSUUID *ON_ADD_ROSTER_PUBLIC_KEY_SCHEMA_ID = nil;
static NSUUID *DELETE_ROSTER_SCHEMA_ID = nil;
static NSUUID *ON_DELETE_ROSTER_SCHEMA_ID = nil;

// Serializers
static TLBinaryPacketIQSerializer *IQ_CREATE_ROSTER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_ROSTER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_LIST_ROSTER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_LIST_ROSTER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ADD_ROSTER_MEMBER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_ROSTER_MEMBER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ADD_ROSTER_PUBLIC_KEY_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_ADD_ROSTER_MEMBER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_ROSTER_MEMBER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_ADD_ROSTER_PUBLIC_KEY_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_ROSTER_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_ROSTER_SERIALIZER = nil;

//
// Class TLSecureRosterPendingRequest
//

@interface TLSecureRosterPendingRequest : NSObject

@end

//
// Class TLSecureRosterPendingRequest
//

@implementation TLSecureRosterPendingRequest

@end

//
// Class TLCreateRosterPendingRequest
//

@interface TLCreateRosterPendingRequest : TLSecureRosterPendingRequest

@property (readonly, nonnull) NSUUID *schemaId;
@property (readonly, nonnull) void (^complete)(TLBaseServiceErrorCode errorCode, TLRosterId * _Nullable rosterId);

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLRosterId * _Nullable rosterId))complete;

@end

@implementation TLCreateRosterPendingRequest

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLRosterId * _Nullable rosterId))complete {
    self = [super init];
    if (self) {
        _schemaId = schemaId;
        _complete = complete;
    }
    return self;
}

@end

//
// Class TLListRosterPendingRequest
//

@interface TLListRosterPendingRequest : TLSecureRosterPendingRequest

@property (readonly, nonnull) TLRosterId *rosterId;
@property (readonly, nonnull) void (^complete)(TLBaseServiceErrorCode errorCode, TLSecureRoster * _Nullable keys);

- (nonnull instancetype)initWithRosterId:(nonnull TLRosterId *)rosterId complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSecureRoster * _Nullable keys))complete;

@end

@implementation TLListRosterPendingRequest

- (nonnull instancetype)initWithRosterId:(nonnull TLRosterId *)rosterId complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSecureRoster * _Nullable keys))complete {
    self = [super init];
    if (self) {
        _rosterId = rosterId;
        _complete = complete;
    }
    return self;
}

@end

//
// Class TLRosterPendingRequest
//

@interface TLRosterPendingRequest : TLSecureRosterPendingRequest

@property (readonly, nonnull) void (^complete)(TLBaseServiceErrorCode errorCode);

- (nonnull instancetype)initWithComplete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

@end

@implementation TLRosterPendingRequest

- (nonnull instancetype)initWithComplete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    self = [super init];
    if (self) {
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLRosterId
//

@implementation TLRosterId

- (nonnull instancetype)initWithId:(nonnull NSUUID *)rosterId schemaId:(nonnull NSUUID *)schemaId {
    self = [super init];
    if (self) {
        _rosterId = rosterId;
        _schemaId = schemaId;
    }
    return self;
}

- (nonnull instancetype)initWithValue:(nonnull NSString *)value {
    self = [super init];
    if (self) {
        NSArray<NSString *> *parts = [value componentsSeparatedByString:@":"];
        if (parts.count == 2) {
            _rosterId = [[NSUUID alloc] initWithUUIDString:parts[0]];
            _schemaId = [[NSUUID alloc] initWithUUIDString:parts[1]];
        } else {
            [NSException raise:@"InvalidArgumentException" format:@"Invalid RosterId value: %@", value];
        }
    }
    return self;
}

@end

//
// Implementation: TLRosterMember
//

@implementation TLRosterMember

- (nonnull instancetype)initWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId
                              creationDate:(int64_t)creationDate
                         modificationDate:(int64_t)modificationDate
                               permissions:(int64_t)permissions
                                publicKey:(nonnull TLPublicKeyData *)publicKey
                                       signature:(nonnull NSData *)signature {

    self = [super init];
    if (self) {
        _memberTwincodeId = memberTwincodeId;
        _permissions = permissions;
        _publicKey = publicKey;
        _signature = signature;
        _creationDate = creationDate;
        _modificationDate = modificationDate;
        _verified = NO;
    }
    return self;
}

- (BOOL)hasPermission:(int64_t)permission {
    return (_permissions & permission) == permission;
}

@end

//
// Implementation: TLSignedRosterGroup
//

@implementation TLSignedRosterGroup

- (nonnull instancetype)initWithKeyId:(nonnull NSUUID *)keyId
                     signingKeyId:(nonnull NSUUID *)signingKeyId
                      publicKey:(nonnull TLPublicKeyData *)publicKey
                       signature:(nonnull NSData *)signature
                              members:(nonnull NSArray<TLRosterMember *> *)members {

    self = [super init];
    if (self) {
        _keyId = keyId;
        _publicKey = publicKey;
        _signature = signature;
        _signingKeyId = signingKeyId;
        _members = members;
        _verified = NO;
    }
    return self;
}

@end

//
// Implementation: TLSecureRoster
//

@implementation TLSecureRoster : NSObject

- (nonnull instancetype)initWithRosterId:(nonnull TLRosterId *)rosterId maxMemberCount:(int)maxMemberCount groups:(nonnull NSArray<TLSignedRosterGroup *> *)groups {
    
    self = [super init];
    if (self) {
        _rosterId = rosterId;
        _maxMemberCount = maxMemberCount;
        _groups = groups;
    }
    return self;
}

@end

//
// Implementation: TLMemberToAdd
//

@implementation TLMemberToAdd

- (nonnull instancetype)initWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId
                                memberPermission:(int64_t)memberPermission
                               memberPublicKey:(nonnull NSData *)memberPublicKey {
    self = [super init];
    if (self) {
        _memberTwincodeId = memberTwincodeId;
        _memberPermission = memberPermission;
        _memberPublicKey = memberPublicKey;
    }
    return self;
}

@end

//
// Implementation: TLSecureRosterServiceConfiguration
//

@implementation TLSecureRosterServiceConfiguration

- (nonnull instancetype)init {
    return [super initWithBaseServiceId:TLBaseServiceIdSecureRosterService version:[TLSecureRosterService VERSION] serviceOn:NO];
}

@end

//
// Implementation: TLSecureRosterService (Private)
//

@interface TLSecureRosterService ()

@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLSecureRosterPendingRequest *> *pendingRequests;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;

@end

#undef LOG_TAG
#define LOG_TAG @"TLSecureRosterService"

//
// Implementation: TLSecureRosterService
//

@implementation TLSecureRosterService

+ (nonnull NSString *)VERSION {

    return SECURE_ROSTER_SERVICE_VERSION;
}

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CREATE_ROSTER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"74a4430b-9910-4fad-bba3-85c92dc99c9e"];
        ON_CREATE_ROSTER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"796995be-2ec5-44c4-b016-7a277e3e9bd3"];
        LIST_ROSTER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"8da99a60-25e5-49f6-acc9-93c28c1d3314"];
        ON_LIST_ROSTER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"299b036c-2589-4367-8df3-3f61ef5b2268"];
        ADD_ROSTER_MEMBER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"abf52b69-e9d4-47c1-864c-9f94cbfa5096"];
        ON_ADD_ROSTER_MEMBER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"4ceec7bb-0ae9-462d-bd9f-cc84f33232b7"];
        DELETE_ROSTER_MEMBER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"e10bbf8e-cab3-4817-9e22-2a8664135ab8"];
        ON_DELETE_ROSTER_MEMBER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"721ab261-9259-437e-bd2c-efe11b7eec8b"];
        ADD_ROSTER_PUBLIC_KEY_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"a0c5183a-062e-412d-b31b-1a6c79b4c6f6"];
        ON_ADD_ROSTER_PUBLIC_KEY_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"6e72fc01-d779-4872-b59e-0d387d3a2a88"];
        DELETE_ROSTER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"1ddcdf5c-c810-4b04-bbdb-4b9f14d41483"];
        ON_DELETE_ROSTER_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"d400c87a-05c3-4354-9849-75160a107041"];

        IQ_CREATE_ROSTER_SERIALIZER = [[TLCreateRosterIQSerializer alloc] initWithSchema:CREATE_ROSTER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ON_CREATE_ROSTER_SERIALIZER = [[TLOnCreateRosterIQSerializer alloc] initWithSchema:ON_CREATE_ROSTER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_LIST_ROSTER_SERIALIZER = [[TLListRosterIQSerializer alloc] initWithSchema:LIST_ROSTER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ON_LIST_ROSTER_SERIALIZER = [[TLOnListRosterIQSerializer alloc] initWithSchema:ON_LIST_ROSTER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ADD_ROSTER_MEMBER_SERIALIZER = [[TLAddRosterMemberIQSerializer alloc] initWithSchema:ADD_ROSTER_MEMBER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_DELETE_ROSTER_MEMBER_SERIALIZER = [[TLDeleteRosterMemberIQSerializer alloc] initWithSchema:DELETE_ROSTER_MEMBER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ADD_ROSTER_PUBLIC_KEY_SERIALIZER = [[TLAddRosterPublicKeyIQSerializer alloc] initWithSchema:ADD_ROSTER_PUBLIC_KEY_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ON_ADD_ROSTER_MEMBER_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_ADD_ROSTER_MEMBER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ON_DELETE_ROSTER_MEMBER_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_DELETE_ROSTER_MEMBER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ON_ADD_ROSTER_PUBLIC_KEY_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_ADD_ROSTER_PUBLIC_KEY_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_DELETE_ROSTER_SERIALIZER = [[TLSecureRosterIQSerializer alloc] initWithSchema:DELETE_ROSTER_SCHEMA_ID.UUIDString schemaVersion:1];
        IQ_ON_DELETE_ROSTER_SERIALIZER = [[TLBinaryErrorPacketIQSerializer alloc] initWithSchema:ON_DELETE_ROSTER_SCHEMA_ID.UUIDString schemaVersion:1];
    });
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);

    self = [super initWithTwinlife:twinlife];
    if (self) {
        [[self class] initialize];
        [self setServiceConfiguration:[[TLSecureRosterServiceConfiguration alloc] init]];

        // Register the binary IQ handlers for the responses.
        [twinlife addPacketListener:IQ_ON_CREATE_ROSTER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onCreateRosterWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_LIST_ROSTER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onListRosterWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_ADD_ROSTER_MEMBER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onAddMemberRosterWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_DELETE_ROSTER_MEMBER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onDeleteRosterMemberWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_ADD_ROSTER_PUBLIC_KEY_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onAddRosterPublicKeyWithIQ:iq];
        }];
        [twinlife addPacketListener:IQ_ON_DELETE_ROSTER_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
            [self onDeleteRosterWithIQ:iq];
        }];

        _pendingRequests = [NSMutableDictionary dictionary];
        _serializerFactory = twinlife.serializerFactory;
    }
    return self;
}

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);

    if (![baseServiceConfiguration isKindOfClass:[TLSecureRosterServiceConfiguration class]]) {
        [self setConfigured:NO];
        return;
    }
    [self setServiceConfiguration:baseServiceConfiguration];
    [self setServiceOn:baseServiceConfiguration.serviceOn];
    [self setConfigured:YES];
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);

    [super onTwinlifeOnline];
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);

    [super onSignOut];
    @synchronized(self.pendingRequests) {
        [self.pendingRequests removeAllObjects];
    }
}

- (void)createRosterWithCreateOptions:(int)createOptions rosterSchemaId:(nonnull NSUUID *)rosterSchemaId publicKeyId:(nonnull NSUUID *)publicKeyId publicKey:(nonnull TLPublicKeyData *)publicKey complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLRosterId * _Nullable rosterId))complete {
    DDLogVerbose(@"%@ createRosterWithCreateOptions: %d rosterSchemaId: %@ publicKeyId: %@", LOG_TAG, createOptions, rosterSchemaId, publicKeyId);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestId] = [[TLCreateRosterPendingRequest alloc] initWithSchemaId:rosterSchemaId complete:complete];
    }

    TLCreateRosterIQ *createRosterIQ = [[TLCreateRosterIQ alloc] initWithSerializer:IQ_CREATE_ROSTER_SERIALIZER requestId:requestId.longLongValue createOptions:createOptions rosterSchemaId:rosterSchemaId publicKeyId:publicKeyId publicKey:[publicKey publicKey]];
    [self sendBinaryIQ:createRosterIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)createRosterWithCreateOptions:(int)createOptions rosterSchemaId:(nonnull NSUUID *)rosterSchemaId signingTwincode:(nonnull TLTwincodeOutbound *)signingTwincode complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLRosterId * _Nullable rosterId))complete {
    DDLogVerbose(@"%@ createRosterWithCreateOptions: %d rosterSchemaId: %@ signingTwincode: %@", LOG_TAG, createOptions, rosterSchemaId, signingTwincode);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    TLPublicKeyData *publicKey = [self.twinlife.cryptoService getRawPublicKeyWithTwincode:signingTwincode];
    if (!publicKey) {
        complete(TLBaseServiceErrorCodeNoPublicKey, nil);
        return;
    }

    [self createRosterWithCreateOptions:createOptions rosterSchemaId:rosterSchemaId publicKeyId:signingTwincode.uuid publicKey:publicKey complete:complete];
}

- (void)listRosterWithRosterId:(nonnull TLRosterId *)rosterId afterCreationTime:(int64_t)afterCreationTime complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSecureRoster * _Nullable keys))complete {
    DDLogVerbose(@"%@ listRosterWithRosterId: %@ afterCreationTime: %lld", LOG_TAG, rosterId, afterCreationTime);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestId] = [[TLListRosterPendingRequest alloc] initWithRosterId:rosterId complete:complete];
    }

    TLListRosterIQ *listRosterIQ = [[TLListRosterIQ alloc] initWithSerializer:IQ_LIST_ROSTER_SERIALIZER requestId:requestId.longLongValue rosterId:rosterId.rosterId minimumCreationTime:afterCreationTime];
    [self sendBinaryIQ:listRosterIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)addMemberWithRosterId:(nonnull TLRosterId *)rosterId signingMember:(nonnull TLTwincodeOutbound *)signingMember newMemberTwincodeId:(nonnull NSUUID *)newMemberTwincodeId newMemberPermission:(int64_t)newMemberPermission newMemberPublicKey:(nonnull TLPublicKeyData *)newMemberPublicKey complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ addMemberWithRosterId: %@ signingMember: %@", LOG_TAG, rosterId, signingMember);

    TLMemberToAdd *member = [[TLMemberToAdd alloc] initWithMemberTwincodeId:newMemberTwincodeId memberPermission:newMemberPermission memberPublicKey:[newMemberPublicKey publicKey]];
    [self addMembersWithRosterId:rosterId signingMember:signingMember members:@[member] complete:complete];
}

- (void)addMemberWithRosterId:(nonnull TLRosterId *)rosterId signingMember:(nonnull TLTwincodeOutbound *)signingMember newMemberTwincode:(nonnull TLTwincodeOutbound *)newMemberTwincode newMemberPermission:(int64_t)newMemberPermission complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ addMemberWithRosterId: %@ signingMember: %@", LOG_TAG, rosterId, signingMember);

    TLPublicKeyData *publicKey = [self.twinlife.cryptoService getRawPublicKeyWithTwincode:newMemberTwincode];
    if (!publicKey) {
        complete(TLBaseServiceErrorCodeNoPublicKey);
        return;
    }
    [self addMemberWithRosterId:rosterId signingMember:signingMember newMemberTwincodeId:newMemberTwincode.uuid newMemberPermission:newMemberPermission newMemberPublicKey:publicKey complete:complete];
}

- (void)addMembersWithRosterId:(nonnull TLRosterId *)rosterId signingMember:(nonnull TLTwincodeOutbound *)signingMember members:(nonnull NSArray<TLMemberToAdd *> *)membersToAdd complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ addMemberWithRosterId: %@ signingMember: %@", LOG_TAG, rosterId, signingMember);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable);
        return;
    }

    NSMutableArray<TLMemberInfo *> *addMembers = [NSMutableArray arrayWithCapacity:membersToAdd.count];
    TLCryptoService *cryptoService = self.twinlife.cryptoService;

    for (TLMemberToAdd *member in membersToAdd) {
        int64_t permissions = member.memberPermission;
        NSData *rawPublicKey = member.memberPublicKey;

        NSMutableData *contentData = [NSMutableData data];
        TLBinaryCompactEncoder *encoder = [[TLBinaryCompactEncoder alloc] initWithData:contentData];
        [encoder writeUUID:rosterId.rosterId];
        [encoder writeUUID:rosterId.schemaId];
        [encoder writeUUID:member.memberTwincodeId];
        [encoder writeLong:permissions];
        [encoder writeData:rawPublicKey];

        NSData *content = [NSData dataWithData:contentData];

        NSData *signature = [cryptoService signContentRawWithTwincode:signingMember content:content];
        if (!signature) {
            complete(TLBaseServiceErrorCodeLibraryError);
            return;
        }

        // If this member can invite other members, we also have to provide a valid signature
        // to verify that member's public key to sign other members.
        NSData *rosterKeySignature = nil;
        if ([TLPermissions hasPermission:TLPermissionTypeInviteMember permissions:permissions]) {
            NSData *keyFingerPrint = [self createKeyFingerprintWithRosterId:rosterId newKeyId:member.memberTwincodeId newPublicKey:rawPublicKey];
            if (!keyFingerPrint) {
                complete(TLBaseServiceErrorCodeLibraryError);
                return;
            }
            rosterKeySignature = [cryptoService signContentRawWithTwincode:signingMember content:keyFingerPrint];
            if (!rosterKeySignature) {
                complete(TLBaseServiceErrorCodeLibraryError);
                return;
            }
        }

        TLMemberInfo *memberInfo = [[TLMemberInfo alloc] initWithNewMemberTwincodeId:member.memberTwincodeId newMemberPermission:permissions newMemberPublicKey:rawPublicKey signature:signature rosterKeySignature:rosterKeySignature];
        [addMembers addObject:memberInfo];
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestId] = [[TLRosterPendingRequest alloc] initWithComplete:complete];
    }

    TLAddRosterMemberIQ *addRosterMemberIQ = [[TLAddRosterMemberIQ alloc] initWithSerializer:IQ_ADD_ROSTER_MEMBER_SERIALIZER requestId:requestId.longLongValue rosterId:rosterId.rosterId signingKeyId:signingMember.uuid members:addMembers];
    [self sendBinaryIQ:addRosterMemberIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)addMembersWithRosterId:(nonnull TLRosterId *)rosterId signingMember:(nonnull TLTwincodeOutbound *)signingMember groupConversation:(nonnull id<TLGroupConversation>)groupConversation complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ addMemberWithRosterId: %@ signingMember: %@", LOG_TAG, rosterId, signingMember);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable);
        return;
    }

    NSMutableArray<TLMemberToAdd *> *addMembers = [NSMutableArray array];
    TLCryptoService *cryptoService = self.twinlife.cryptoService;

    // Add the group owner (ie, ourselves).
    TLTwincodeOutbound *ownerTwincode = [groupConversation.subject twincodeOutbound];
    if (ownerTwincode) {
        int64_t permissions = TL_RESTRICT_PERMISSIONS([groupConversation permissions], TL_ALL_PERMISSIONS);
        TLPublicKeyData *publicKey = [cryptoService getRawPublicKeyWithTwincode:ownerTwincode];
        if (publicKey) {
            [addMembers addObject:[[TLMemberToAdd alloc] initWithMemberTwincodeId:ownerTwincode.uuid memberPermission:permissions memberPublicKey:[publicKey publicKey]]];
        } else if ([rosterId.schemaId isEqual:[TLGroupProtocol LEGACY_SCHEMA_ID]]) {
            // If this is a legacy secure roster group, add this member with an empty public key.
            // We must also remove the right for that member to invite other members because it would not be able
            // to create a valid member signature.
            if ([TLPermissions hasPermission:TLPermissionTypeInviteMember permissions:permissions]) {
                permissions = [TLPermissions removePermission:TLPermissionTypeInviteMember permissions:permissions];
                [[self.twinlife getConversationService] setPermissionsWithSubject:groupConversation.subject memberTwincodeId:ownerTwincode.uuid permissions:permissions];
            }
            [addMembers addObject:[[TLMemberToAdd alloc] initWithMemberTwincodeId:ownerTwincode.uuid memberPermission:permissions memberPublicKey:[[NSData alloc] init]]];
        }
    }

    // Add group members
    NSArray<id<TLGroupMemberConversation>> *memberConversations = [groupConversation groupMembersWithFilter:TLGroupMemberFilterTypeJoinedMembers];
    for (id<TLGroupMemberConversation> memberConversation in memberConversations) {
        TLTwincodeOutbound *memberTwincode = [memberConversation peerTwincodeOutbound];
        if (memberTwincode) {
            int64_t permissions = TL_RESTRICT_PERMISSIONS([memberConversation permissions], TL_ALL_PERMISSIONS);
            TLPublicKeyData *publicKey = [cryptoService getRawPublicKeyWithTwincode:memberTwincode];
            if (publicKey) {
                [addMembers addObject:[[TLMemberToAdd alloc] initWithMemberTwincodeId:memberTwincode.uuid memberPermission:permissions memberPublicKey:[publicKey publicKey]]];
            } else if ([rosterId.schemaId isEqual:[TLGroupProtocol LEGACY_SCHEMA_ID]]) {
                // If this is a legacy secure roster group, add this member with an empty public key.
                // We must also remove the right for that member to invite other members because it would not be able
                // to create a valid member signature.
                if ([TLPermissions hasPermission:TLPermissionTypeInviteMember permissions:permissions]) {
                    permissions = [TLPermissions removePermission:TLPermissionTypeInviteMember permissions:permissions];
                    [[self.twinlife getConversationService] setPermissionsWithSubject:groupConversation.subject memberTwincodeId:memberTwincode.uuid permissions:permissions];
                }
                [addMembers addObject:[[TLMemberToAdd alloc] initWithMemberTwincodeId:memberTwincode.uuid memberPermission:permissions memberPublicKey:[[NSData alloc] init]]];
            }
        }
    }

    [self addMembersWithRosterId:rosterId signingMember:signingMember members:addMembers complete:complete];
}

- (void)deleteMemberWithRosterId:(nonnull NSUUID *)rosterId memberId:(nonnull NSUUID *)memberId complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ deleteMemberWithRosterId: %@ memberId: %@", LOG_TAG, rosterId, memberId);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestId] = [[TLRosterPendingRequest alloc] initWithComplete:complete];
    }

    TLDeleteRosterMemberIQ *deleteRosterMemberIQ = [[TLDeleteRosterMemberIQ alloc] initWithSerializer:IQ_DELETE_ROSTER_MEMBER_SERIALIZER requestId:requestId.longLongValue rosterId:rosterId memberId:memberId];
    [self sendBinaryIQ:deleteRosterMemberIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)setRosterPublicKeyWithRosterId:(nonnull TLRosterId *)rosterId signingMember:(nonnull TLTwincodeOutbound *)signingMember newKeyId:(nonnull NSUUID *)newKeyId newPublicKey:(nonnull TLPublicKeyData *)newPublicKey complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ setRosterPublicKeyWithRosterId: %@ signingMember: %@", LOG_TAG, rosterId, signingMember);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable);
        return;
    }

    NSData *rawPublicKey = [newPublicKey publicKey];
    NSData *keyFingerprint = [self createKeyFingerprintWithRosterId:rosterId newKeyId:newKeyId newPublicKey:rawPublicKey];
    if (!keyFingerprint) {
        complete(TLBaseServiceErrorCodeLibraryError);
        return;
    }

    NSData *signature = [self.twinlife.cryptoService signContentRawWithTwincode:signingMember content:keyFingerprint];
    if (!signature) {
        complete(TLBaseServiceErrorCodeLibraryError);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestId] = [[TLRosterPendingRequest alloc] initWithComplete:complete];
    }

    TLAddRosterPublicKeyIQ *addRosterPublicKeyIQ = [[TLAddRosterPublicKeyIQ alloc] initWithSerializer:IQ_ADD_ROSTER_PUBLIC_KEY_SERIALIZER requestId:requestId.longLongValue rosterId:rosterId.rosterId signingKeyId:signingMember.uuid newKeyId:newKeyId newPublicKey:rawPublicKey signature:signature];
    [self sendBinaryIQ:addRosterPublicKeyIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)setRosterPublicKeyWithRosterId:(nonnull TLRosterId *)rosterId signingMember:(nonnull TLTwincodeOutbound *)signingMember newSigningTwincode:(nonnull TLTwincodeOutbound *)newSigningTwincode complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ setRosterPublicKeyWithRosterId: %@ signingMember: %@", LOG_TAG, rosterId, signingMember);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable);
        return;
    }

    TLPublicKeyData *publicKey = [self.twinlife.cryptoService getRawPublicKeyWithTwincode:newSigningTwincode];
    if (!publicKey) {
        complete(TLBaseServiceErrorCodeNoPublicKey);
        return;
    }
    [self setRosterPublicKeyWithRosterId:rosterId signingMember:signingMember newKeyId:newSigningTwincode.uuid newPublicKey:publicKey complete:complete];
}

- (void)deleteRosterWithRosterId:(nonnull TLRosterId *)rosterId complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete {
    DDLogVerbose(@"%@ deleteRosterWithRosterId: %@", LOG_TAG, rosterId);

    if (![self isServiceOn]) {
        complete(TLBaseServiceErrorCodeServiceUnavailable);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self.pendingRequests) {
        self.pendingRequests[requestId] = [[TLRosterPendingRequest alloc] initWithComplete:complete];
    }

    TLSecureRosterIQ *deleteRosterIQ = [[TLSecureRosterIQ alloc] initWithSerializer:IQ_DELETE_ROSTER_SERIALIZER requestId:requestId.longLongValue rosterId:rosterId.rosterId];
    [self sendBinaryIQ:deleteRosterIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (nullable NSData *)createKeyFingerprintWithRosterId:(nonnull TLRosterId *)rosterId newKeyId:(nonnull NSUUID *)newKeyId newPublicKey:(nonnull NSData *)newPublicKey {
    DDLogVerbose(@"%@ createKeyFingerprintWithRosterId: %@ newKeyId: %@", LOG_TAG, rosterId, newKeyId);

    NSMutableData *outputStream = [NSMutableData data];
    TLBinaryCompactEncoder *encoder = [[TLBinaryCompactEncoder alloc] initWithData:outputStream];
    [encoder writeUUID:rosterId.rosterId];
    [encoder writeUUID:rosterId.schemaId];
    [encoder writeUUID:newKeyId];
    [encoder writeData:newPublicKey];
    return [NSData dataWithData:outputStream];
}

- (void)onCreateRosterWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCreateRosterWithIQ: %@", LOG_TAG, iq);

    TLOnCreateRosterIQ *onCreateRosterIQ = (TLOnCreateRosterIQ *)iq;

    TLSecureRosterPendingRequest *request;
    @synchronized(self.pendingRequests) {
        request = self.pendingRequests[@(iq.requestId)];
        [self.pendingRequests removeObjectForKey:@(iq.requestId)];
    }

    if (![request isKindOfClass:[TLCreateRosterPendingRequest class]]) {
        return;
    }

    TLCreateRosterPendingRequest *createRequest = (TLCreateRosterPendingRequest *)request;
    TLRosterId *rosterId = [[TLRosterId alloc] initWithId:onCreateRosterIQ.rosterId schemaId:createRequest.schemaId];
    createRequest.complete(TLBaseServiceErrorCodeSuccess, rosterId);
}

- (void)onListRosterWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onListRosterWithIQ: %@", LOG_TAG, iq);

    TLOnListRosterIQ *onListRosterIQ = (TLOnListRosterIQ *)iq;

    TLSecureRosterPendingRequest *request;
    @synchronized(self.pendingRequests) {
        request = self.pendingRequests[@(iq.requestId)];
        [self.pendingRequests removeObjectForKey:@(iq.requestId)];
    }

    if (![request isKindOfClass:[TLListRosterPendingRequest class]]) {
        return;
    }

    TLListRosterPendingRequest *listRequest = (TLListRosterPendingRequest *)request;
    [self verifyRosterSignaturesWithRosterId:listRequest.rosterId keys:onListRosterIQ.keys];
    listRequest.complete(TLBaseServiceErrorCodeSuccess, [[TLSecureRoster alloc] initWithRosterId:listRequest.rosterId maxMemberCount:onListRosterIQ.maxMemberCount groups:onListRosterIQ.keys]);
}

- (void)verifyRosterSignaturesWithRosterId:(nonnull TLRosterId *)rosterId keys:(nonnull NSArray<TLSignedRosterGroup *> *)keys {
    DDLogVerbose(@"%@ verifyRosterSignaturesWithRosterId: %@", LOG_TAG, rosterId);

    TLCryptoService *cryptoService = self.twinlife.cryptoService;

    NSMutableDictionary<NSUUID *, TLPublicKeyData *> *validatedKeys = [NSMutableDictionary dictionary];

    for (TLSignedRosterGroup *key in keys) {
        TLPublicKeyData *publicKey;
        if (validatedKeys.count == 0 && [key.keyId isEqual:key.signingKeyId]) {
            publicKey = key.publicKey;
        } else {
            publicKey = validatedKeys[key.signingKeyId];
        }

        // Step 1: Verify the signature of the roster signature key itself
        if (publicKey) {
            NSMutableData *contentData = [NSMutableData data];
            TLBinaryCompactEncoder *encoder = [[TLBinaryCompactEncoder alloc] initWithData:contentData];
            [encoder writeUUID:rosterId.rosterId];
            [encoder writeUUID:rosterId.schemaId];
            [encoder writeUUID:key.keyId];
            [encoder writeData:[key.publicKey publicKey]];
            NSData *content = [NSData dataWithData:contentData];

            TLBaseServiceErrorCode errorCode = [cryptoService verifyContentWithPublicKey:publicKey keyId:key.signingKeyId content:content signature:key.signature];
            key.verified = errorCode == TLBaseServiceErrorCodeSuccess;

            if (key.verified) {
                validatedKeys[key.keyId] = publicKey;
            }
        } else {
            key.verified = NO;
        }

        // Step 2: Verify the signature of each member signed by this key
        for (TLRosterMember *member in key.members) {
            if (key.verified) {
                NSMutableData *contentData = [NSMutableData data];
                TLBinaryCompactEncoder *encoder = [[TLBinaryCompactEncoder alloc] initWithData:contentData];
                [encoder writeUUID:rosterId.rosterId];
                [encoder writeUUID:rosterId.schemaId];
                [encoder writeUUID:member.memberTwincodeId];
                [encoder writeLong:member.permissions];
                [encoder writeData:[member.publicKey publicKey]];
                NSData *content = [NSData dataWithData:contentData];
                
                TLBaseServiceErrorCode errorCode = [cryptoService verifyContentWithPublicKey:publicKey keyId:key.keyId content:content signature:member.signature];
                member.verified = errorCode == TLBaseServiceErrorCodeSuccess;
            } else {
                member.verified = NO;
            }
        }
    }
}

- (void)onAddMemberRosterWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAddMemberRosterWithIQ: %@", LOG_TAG, iq);

    TLBinaryErrorPacketIQ *response = (TLBinaryErrorPacketIQ *)iq;

    TLSecureRosterPendingRequest *request;
    @synchronized(self.pendingRequests) {
        request = self.pendingRequests[@(iq.requestId)];
        [self.pendingRequests removeObjectForKey:@(iq.requestId)];
    }

    if (![request isKindOfClass:[TLRosterPendingRequest class]]) {
        return;
    }

    TLRosterPendingRequest *rosterRequest = (TLRosterPendingRequest *)request;
    rosterRequest.complete(response.errorCode);
}

- (void)onDeleteRosterMemberWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onDeleteRosterMemberWithIQ: %@", LOG_TAG, iq);

    TLBinaryErrorPacketIQ *response = (TLBinaryErrorPacketIQ *)iq;

    TLSecureRosterPendingRequest *request;
    @synchronized(self.pendingRequests) {
        request = self.pendingRequests[@(iq.requestId)];
        [self.pendingRequests removeObjectForKey:@(iq.requestId)];
    }

    if (![request isKindOfClass:[TLRosterPendingRequest class]]) {
        return;
    }

    TLRosterPendingRequest *rosterRequest = (TLRosterPendingRequest *)request;
    rosterRequest.complete(response.errorCode);
}

- (void)onAddRosterPublicKeyWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onAddRosterPublicKeyWithIQ: %@", LOG_TAG, iq);

    TLBinaryErrorPacketIQ *response = (TLBinaryErrorPacketIQ *)iq;

    TLSecureRosterPendingRequest *request;
    @synchronized(self.pendingRequests) {
        request = self.pendingRequests[@(iq.requestId)];
        [self.pendingRequests removeObjectForKey:@(iq.requestId)];
    }

    if (![request isKindOfClass:[TLRosterPendingRequest class]]) {
        return;
    }

    TLRosterPendingRequest *rosterRequest = (TLRosterPendingRequest *)request;
    rosterRequest.complete(response.errorCode);
}

- (void)onDeleteRosterWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onDeleteRosterWithIQ: %@", LOG_TAG, iq);

    TLBinaryErrorPacketIQ *response = (TLBinaryErrorPacketIQ *)iq;

    TLSecureRosterPendingRequest *request;
    @synchronized(self.pendingRequests) {
        request = self.pendingRequests[@(iq.requestId)];
        [self.pendingRequests removeObjectForKey:@(iq.requestId)];
    }

    if (![request isKindOfClass:[TLRosterPendingRequest class]]) {
        return;
    }

    TLRosterPendingRequest *rosterRequest = (TLRosterPendingRequest *)request;
    rosterRequest.complete(response.errorCode);
}

- (void)onErrorPacketWithIQ:(nonnull TLBinaryErrorPacketIQ *)iq {
    DDLogVerbose(@"%@ onErrorPacketWithIQ: %@", LOG_TAG, iq);

    TLSecureRosterPendingRequest *request;
    @synchronized(self.pendingRequests) {
        request = self.pendingRequests[@(iq.requestId)];
        [self.pendingRequests removeObjectForKey:@(iq.requestId)];
    }

    if (!request) {
        return;
    }

    if ([request isKindOfClass:[TLCreateRosterPendingRequest class]]) {
        TLCreateRosterPendingRequest *createRequest = (TLCreateRosterPendingRequest *)request;
        createRequest.complete(iq.errorCode, nil);
    } else if ([request isKindOfClass:[TLListRosterPendingRequest class]]) {
        TLListRosterPendingRequest *listRequest = (TLListRosterPendingRequest *)request;
        listRequest.complete(iq.errorCode, nil);
    } else if ([request isKindOfClass:[TLRosterPendingRequest class]]) {
        TLRosterPendingRequest *rosterRequest = (TLRosterPendingRequest *)request;
        rosterRequest.complete(iq.errorCode);
    }
}

@end

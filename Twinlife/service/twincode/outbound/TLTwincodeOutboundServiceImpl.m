/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>
#include <netdb.h>
#include <arpa/inet.h>

#import "NSUUID+Extensions.h"
#import "NSURL+Extensions.h"

#import "TLTwinlife.h"
#import "TLBaseServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLTwincodeInboundServiceImpl.h"
#import "TLImageService.h"
#import "TLManagementServiceImpl.h"
#import "TLTwincodeOutboundServiceProvider.h"
#import "TLCryptoServiceImpl.h"
#import "TLJobService.h"
#import "TLAttributeNameValue.h"
#import "TLGetTwincodeIQ.h"
#import "TLOnGetTwincodeIQ.h"
#import "TLUpdateTwincodeIQ.h"
#import "TLOnUpdateTwincodeIQ.h"
#import "TLRefreshTwincodeIQ.h"
#import "TLOnRefreshTwincodeIQ.h"
#import "TLInvokeTwincodeIQ.h"
#import "TLInvocationIQ.h"
#import "TLCreateInvitationCodeIQ.h"
#import "TLOnCreateInvitationCodeIQ.h"
#import "TLGetInvitationCodeIQ.h"
#import "TLOnGetInvitationCodeIQ.h"
#import "TLBinaryErrorPacketIQ.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLInvitationCode.h"
#import "TLProxyDescriptor.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define TWINCODE_OUTBOUND_SERVICE_VERSION @"2.2.0"

#define MAX_REFRESH_TWINCODES    20

#define TWINLIFE_NAME                       @"twincode"
#define TWINLIFE_SERVICE_NAME               @"outbound"

#define GET_TWINCODE_SCHEMA_ID              @"4d06f636-6327-4c1d-b044-08227f4aa7cb"
#define ON_GET_TWINCODE_SCHEMA_ID           @"76bdf639-65a3-41b9-9af9-87d622473d3f"
#define UPDATE_TWINCODE_SCHEMA_ID           @"8efcb2a1-6607-4b06-964c-ec65ed459ffc"
#define ON_UPDATE_TWINCODE_SCHEMA_ID        @"2b0ff6f7-75bb-44a6-9fac-0a9b28fc84dd"
#define REFRESH_TWINCODE_SCHEMA_ID          @"e8028e21-e657-4240-b71a-21ea1367ebf2"
#define ON_REFRESH_TWINCODE_SCHEMA_ID       @"2dc1c0bc-f4a1-4904-ac55-680ce11e43f8"
#define INVOKE_TWINCODE_SCHEMA_ID           @"c74e79e6-5157-4fb4-bad8-2de545711fa0"
#define ON_INVOKE_TWINCODE_SCHEMA_ID        @"35d11e72-84d7-4a3b-badd-9367ef8c9e43"
#define CREATE_INVITATION_CODE_SCHEMA_ID    @"8dcfcba5-b8c0-4375-a501-d24534ed4a3b"
#define ON_CREATE_INVITATION_CODE_SCHEMA_ID @"93cf2a0c-82cb-43ea-98c6-43563807fadf"
#define GET_INVITATION_CODE_SCHEMA_ID       @"95335487-91fa-4cdc-939b-e047a068e94d"
#define ON_GET_INVITATION_CODE_SCHEMA_ID    @"a16cf169-81dd-4a47-8787-5856f409e017"

static TLBinaryPacketIQSerializer *IQ_GET_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_GET_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_UPDATE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_UPDATE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_REFRESH_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_REFRESH_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_INVOKE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_INVOKE_TWINCODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CREATE_INVITATION_CODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_INVITATION_CODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_GET_INVITATION_CODE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_GET_INVITATION_CODE_SERIALIZER = nil;

//
// Interface: TLTwincodeOutboundJob
//
@interface TLTwincodeOutboundJob : NSObject <TLJob>

@property (weak, readonly) TLTwincodeOutboundService *service;

- (nonnull instancetype)initWithService:(nonnull TLTwincodeOutboundService *)service;

@end

//
// Interface: TLTwincodeOutboundService ()
//

@interface TLTwincodeOutboundService ()

@property (readonly, nonnull) TLTwincodeOutboundJob *twincodeJob;
@property (readonly, nonnull) TLTwincodeOutboundServiceProvider *serviceProvider;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLTwincodePendingRequest *> *pendingRequests;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) TLCryptoService *cryptoService;
@property BOOL enableTwincodeRefresh;
@property (weak) TLJobId *refreshJobId;

- (void)runRefreshJob;

@end

//
// Implementation: TLTwincodeOutboundJob
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeOutboundJob"

@implementation TLTwincodeOutboundJob

- (nonnull instancetype)initWithService:(nonnull TLTwincodeOutboundService *)service {

    self = [super init];
    if (self) {
        _service = service;
    }

    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);

    [self.service runRefreshJob];
}

@end

//
// Implementation: TLTwincodeOutbound
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeOutbound"

@implementation TLTwincodeOutbound

+ (int)toFlagsWithTrustMethod:(TLTrustMethod)trustMethod {
    
    switch (trustMethod) {
        case TLTrustMethodNone:
            return 0;
        case TLTrustMethodOwner:
            return (0x01 << TRUST_METHOD_SHIFT) | FLAG_TRUSTED;
        case TLTrustMethodQrCode:
            return (0x02 << TRUST_METHOD_SHIFT) | FLAG_TRUSTED;
        case TLTrustMethodVideo:
            return (0x04 << TRUST_METHOD_SHIFT) | FLAG_TRUSTED;
        case TLTrustMethodLink:
            return (0x08 << TRUST_METHOD_SHIFT) | FLAG_TRUSTED;
        case TLTrustMethodPeer:
            return (0x10 << TRUST_METHOD_SHIFT) | FLAG_TRUSTED;
        case TLTrustMethodAuto:
            return (0x20 << TRUST_METHOD_SHIFT) | FLAG_TRUSTED;
        case TLTrustMethodInvitationCode:
            return (0x40 << TRUST_METHOD_SHIFT); // The public key cannot be trusted for the invitation code.
    }
}

+ (TLTrustMethod)toTrustMethodWithFlags:(int)flags {
    
    if ((flags & FLAG_TRUSTED) == 0) {
        if ((flags & 0x4000) != 0) {
            return TLTrustMethodInvitationCode;
        }
        return TLTrustMethodNone;
    }
    // Several trust method flags can be set, check according to the highest trust method.
    if ((flags & 0x0100) != 0) {
        return TLTrustMethodOwner;
    }
    if ((flags & 0x0200) != 0) {
        return TLTrustMethodQrCode;
    }
    if ((flags & 0x0400) != 0) {
        return TLTrustMethodVideo;
    }
    if ((flags & 0x0800) != 0) {
        return TLTrustMethodLink;
    }
    if ((flags & 0x1000) != 0) {
        return TLTrustMethodPeer;
    }
    if ((flags & 0x2000) != 0) {
        return TLTrustMethodAuto;
    }
    if ((flags & 0x4000) != 0) {
        return TLTrustMethodInvitationCode;
    }
    
    return TLTrustMethodNone;
}

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId name:(nullable NSString *)name description:(nullable NSString *)description avatarId:(nullable TLImageId *)avatarId capabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate flags:(int)flags {
    DDLogVerbose(@"%@ initWithIdentifier: %@ twincodeId: %@ capabilities: %@", LOG_TAG, identifier, twincodeId, capabilities);
    
    self = [super initWithUUID:twincodeId modificationDate:modificationDate attributes:nil];
    if (self) {
        _databaseId = identifier;
        _name = name;
        _twincodeDescription = description;
        _avatarId = avatarId;
        _capabilities = capabilities;
        [self updateWithName:name description:description avatarId:avatarId capabilities:capabilities content:content modificationDate:modificationDate flags:flags];
    }
    return self;
}

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes flags:(int)flags modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ initWithIdentifier: %@ twincodeId: %@ attributes: %@", LOG_TAG, identifier, twincodeId, attributes);
    
    self = [super initWithUUID:twincodeId modificationDate:modificationDate attributes:nil];
    if (self) {
        _databaseId = identifier;
        _flags = flags;
        [self importWithAttributes:attributes previousAttributes:nil modificationDate:modificationDate];
    }
    return self;
}

- (void)updateWithName:(nullable NSString*)name description:(nullable NSString *)description avatarId:(nullable TLImageId *)avatarId capabilities:(nullable NSString *)capabilities content:(nullable NSData *)content modificationDate:(int64_t)modificationDate flags:(int)flags {
    DDLogVerbose(@"%@ updateWithName: %@ description: %@ avatarId: %@ capabilities: %@ modificationDate: %lld", LOG_TAG, name, description, avatarId, capabilities, modificationDate);

    NSMutableArray<TLAttributeNameValue *> *attributes = [TLBinaryCompactDecoder deserializeWithData:content];
    @synchronized (self) {
        self.name = name;
        self.twincodeDescription = description;
        self.avatarId = avatarId;
        self.capabilities = capabilities;
        self.attributes = attributes;
        self.flags = flags;
        self.modificationDate = modificationDate;
    }
}

- (void)importWithAttributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes previousAttributes:(nullable NSMutableArray<TLAttributeNameValue *> *)previousAttributes modificationDate:(int64_t)modificationDate {
    DDLogVerbose(@"%@ importWithAttributes: %@ modificationDate: %lld", LOG_TAG, attributes, modificationDate);

    @synchronized (self) {
        self.modificationDate = modificationDate;
        self.flags &= ~(FLAG_NEED_FETCH);
        for (TLAttributeNameValue *attribute in attributes) {
            if ([attribute.name isEqualToString:TL_TWINCODE_NAME]) {
                NSString *newName = (NSString *)((TLAttributeNameStringValue*)attribute.value);
                if (previousAttributes && ![newName isEqual:self.name]) {
                    [previousAttributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TL_TWINCODE_NAME stringValue:self.name]];
                }
                self.name = newName;
            } else if ([attribute.name isEqualToString:TL_TWINCODE_DESCRIPTION]) {
                NSString *newDescription = (NSString *)((TLAttributeNameStringValue*)attribute.value);
                if (previousAttributes && ![newDescription isEqual:self.twincodeDescription]) {
                    [previousAttributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TL_TWINCODE_DESCRIPTION stringValue:self.twincodeDescription]];
                }
                self.twincodeDescription = newDescription;
            } else if ([attribute.name isEqualToString:TL_TWINCODE_AVATAR_ID]) {
                // Ignore this attribute: it was handled by storeTwincodeOutbound() with a relation to the image table;
            } else if ([attribute.name isEqualToString:TL_TWINCODE_CAPABILITIES]) {
                NSString *newCapabilities = (NSString *)((TLAttributeNameStringValue*)attribute.value);
                if (previousAttributes && ![newCapabilities isEqual:self.capabilities]) {
                    [previousAttributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TL_TWINCODE_CAPABILITIES stringValue:self.capabilities]];
                }
                self.capabilities = newCapabilities;
            } else {
                BOOL found = NO;
                if (self.attributes) {
                    for (TLAttributeNameValue *existingAttr in self.attributes) {
                        if ([attribute.name isEqualToString:existingAttr.name]) {
                            if (previousAttributes && ![attribute.value isEqual:existingAttr.value]) {
                                [previousAttributes addObject:existingAttr];
                            }
                            [self.attributes removeObject:existingAttr];
                            [self.attributes addObject:attribute];
                            found = YES;
                            break;
                        }
                    }
                }
                if (!found) {
                    if (!self.attributes) {
                        self.attributes = [[NSMutableArray alloc] init];
                    }
                    [self.attributes addObject:attribute];
                }
            }
        }
    }
}

- (nonnull NSMutableArray<TLAttributeNameValue *> *)getAttributes:(nullable NSArray<TLAttributeNameValue *> *)update deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames {
    DDLogVerbose(@"%@ getAttributes: %@ modificationDate: %@", LOG_TAG, update, deleteAttributeNames);
    
    NSMutableArray<TLAttributeNameValue *> *attributes;
    @synchronized (self) {
        if (self.attributes) {
            attributes = [[NSMutableArray alloc] initWithArray:self.attributes];
        } else {
            attributes = [[NSMutableArray alloc] init];
        }
        if (self.name) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TL_TWINCODE_NAME stringValue:self.name]];
        }
        if (self.twincodeDescription) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TL_TWINCODE_DESCRIPTION stringValue:self.twincodeDescription]];
        }
        if (self.capabilities) {
            [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TL_TWINCODE_CAPABILITIES stringValue:self.capabilities]];
        }
    }

    if (deleteAttributeNames) {
        for (NSString *name in deleteAttributeNames) {
            [TLAttributeNameStringValue removeAttributeWithName:name list:attributes];
        }
    }
    for (TLAttributeNameValue *attribute in update) {
        [TLAttributeNameValue removeAttributeWithName:attribute.name list:attributes];
        [attributes addObject:attribute];
    }
    return attributes;
}

- (nullable NSData *)serialize {

    @synchronized (self) {
        return [TLBinaryCompactEncoder serializeWithAttributes:self.attributes];
    }
}

- (TLTwincodeFacet)getFacet {
    
    return TWINCODE_OUTBOUND;
}

- (BOOL)isTwincodeOutbound {
    
    return YES;
}

- (BOOL)isKnown {
    
    return (self.flags & FLAG_NEED_FETCH) == 0;
}

- (BOOL)isSigned {

    return (self.flags & FLAG_SIGNED) != 0;
}

- (BOOL)isEncrypted {
    
    return (self.flags & FLAG_ENCRYPT) != 0;
}

- (BOOL)isTrusted {
    
    return (self.flags & FLAG_TRUSTED) != 0;
}

- (BOOL)isVerified {
    
    return (self.flags & FLAG_VERIFIED) != 0;
}

- (BOOL)isCertified {
    
    return (self.flags & FLAG_CERTIFIED) != 0;
}

- (void)needFetch {
    
    self.flags |= FLAG_NEED_FETCH;
}

- (BOOL)isOwner {
    
    return self.flags & FLAG_OWNER;
}

- (TLTrustMethod)trustMethod {
    
    return [TLTwincodeOutbound toTrustMethodWithFlags:self.flags];
}

- (nonnull TLDatabaseIdentifier *)identifier {
    
    return self.databaseId;
}

- (nonnull NSUUID *)objectId {
    
    return self.uuid;
}

- (BOOL)isEqual:(nullable id)object {
    
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLTwincodeOutbound class]]) {
        return NO;
    }
    TLTwincodeOutbound* twincodeOutbound = (TLTwincodeOutbound *)object;
    return [twincodeOutbound.uuid isEqual:self.uuid] && twincodeOutbound.modificationDate == self.modificationDate;
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    result = 31 * result + self.uuid.hash;
    return result;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"TLTwincodeOutbound[%@ %@ flags=%x time=%lld", self.databaseId, self.uuid, self.flags, self.modificationDate];
    if (self.attributes.count > 0) {
        for (TLAttributeNameValue* attribute in self.attributes) {
            [string appendFormat:@" %@=%@", attribute.name, attribute.value];
        }
    }
    [string appendString:@"]"];
    return string;
}

@end

#pragma mark - PendingRequests

//
// Implementation: TLGetTwincodePendingRequest
//

@implementation TLGetTwincodePendingRequest

-(nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId refreshPeriod:(int64_t)refreshPeriod publicKey:(nullable NSString *)publicKey keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey trustMethod:(TLTrustMethod)trustMethod complete:(nonnull TLTwincodeConsumer)complete {
    DDLogVerbose(@"%@ initWithTwincodeId: %@ refreshPeriod: %lld publicKey: %@ keyIndex: %d trustMethod: %ld", LOG_TAG, twincodeId, refreshPeriod, publicKey, keyIndex, trustMethod);

    self = [super init];
    if (self) {
        _twincodeId = twincodeId;
        _refreshPeriod = refreshPeriod;
        _publicKey = publicKey;
        _keyIndex = keyIndex;
        _secretKey = secretKey;
        _trustMethod = trustMethod;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLRefreshTwincodePendingRequest
//

@implementation TLRefreshTwincodePendingRequest

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode complete:(nonnull TLTwincodeRefreshConsumer)complete {
    DDLogVerbose(@"%@ initWithTwincode: %@", LOG_TAG, twincode);

    self = [super init];
    if (self) {
        _twincodeOutbound = twincode;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLInvokeTwincodePendingRequest
//

@implementation TLInvokeTwincodePendingRequest

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode complete:(nonnull TLInvokeTwincodeComplete)complete {
    DDLogVerbose(@"%@ initWithTwincode: %@", LOG_TAG, twincode);

    self = [super init];
    if (self) {
        _twincode = twincode;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLUpdateTwincodePendingRequest
//

@implementation TLUpdateTwincodePendingRequest

-(nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes isSigned:(BOOL)isSigned complete:(nonnull TLTwincodeConsumer)complete {
    DDLogVerbose(@"%@ initWithTwincode: %@ attributes: %@ signed: %d", LOG_TAG, twincode, attributes, isSigned);

    self = [super init];
    if (self) {
        _twincode = twincode;
        _attributes = attributes;
        _isSigned = isSigned;
        _complete = complete;
    }
    return self;
}

@end

//
// Implementation: TLRefreshTwincodesPendingRequest
//

@implementation TLRefreshTwincodesPendingRequest

-(nonnull instancetype)initWithRefreshList:(nonnull NSMutableDictionary<NSUUID *, NSNumber *> *)refreshList {
    DDLogVerbose(@"%@ initWithRefreshList: %@", LOG_TAG, refreshList);

    self = [super init];
    if (self) {
        _refreshList = refreshList;
    }
    return self;
}

@end

//
// Implementation: TLCreateInvitationCodePendingRequest
//

@implementation TLCreateInvitationCodePendingRequest

-(nonnull instancetype)initWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound consumer:(nonnull TLCreateInvitationCodeConsumer)consumer {
    DDLogVerbose(@"%@ initWithTwincodeOutbound: %@", LOG_TAG, twincodeOutbound);

    self = [super init];
    if (self) {
        _twincodeOutbound = twincodeOutbound;
        _consumer = consumer;
    }
    return self;
}

@end

//
// Implementation: TLGetInvitationCodePendingRequest
//

@implementation TLGetInvitationCodePendingRequest

-(nonnull instancetype)initWithCode:(nonnull NSString *)code consumer:(nonnull TLGetInvitationCodeConsumer)consumer {
    DDLogVerbose(@"%@ initWithCode: %@", LOG_TAG, code);

    self = [super init];
    if (self) {
        _code = code;
        _consumer = consumer;
    }
    return self;
}

@end

//
// Implementation: TLTwincodeOutboundServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeOutboundServiceConfiguration"

@implementation TLTwincodeOutboundServiceConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdTwincodeOutboundService version:[TLTwincodeOutboundService VERSION] serviceOn:NO];
}

@end

//
// Implementation: TLTwincodeOutboundService
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeOutboundService"

@implementation TLTwincodeOutboundService

+ (void)initialize {
    
    IQ_GET_TWINCODE_SERIALIZER = [[TLGetTwincodeIQSerializer alloc] initWithSchema:GET_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_GET_TWINCODE_SERIALIZER = [[TLOnGetTwincodeIQSerializer alloc] initWithSchema:ON_GET_TWINCODE_SCHEMA_ID schemaVersion:2];

    IQ_UPDATE_TWINCODE_SERIALIZER = [[TLUpdateTwincodeIQSerializer alloc] initWithSchema:UPDATE_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_UPDATE_TWINCODE_SERIALIZER = [[TLOnUpdateTwincodeIQSerializer alloc] initWithSchema:ON_UPDATE_TWINCODE_SCHEMA_ID schemaVersion:1];

    IQ_REFRESH_TWINCODE_SERIALIZER = [[TLRefreshTwincodeIQSerializer alloc] initWithSchema:REFRESH_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_REFRESH_TWINCODE_SERIALIZER = [[TLOnRefreshTwincodeIQSerializer alloc] initWithSchema:ON_REFRESH_TWINCODE_SCHEMA_ID schemaVersion:2];

    IQ_INVOKE_TWINCODE_SERIALIZER = [[TLInvokeTwincodeIQSerializer alloc] initWithSchema:INVOKE_TWINCODE_SCHEMA_ID schemaVersion:2];
    IQ_ON_INVOKE_TWINCODE_SERIALIZER = [[TLInvocationIQSerializer alloc] initWithSchema:ON_INVOKE_TWINCODE_SCHEMA_ID schemaVersion:1];

    
    IQ_CREATE_INVITATION_CODE_SERIALIZER = [[TLCreateInvitationCodeIQSerializer alloc] initWithSchema:CREATE_INVITATION_CODE_SCHEMA_ID schemaVersion:1];
    IQ_ON_CREATE_INVITATION_CODE_SERIALIZER = [[TLOnCreateInvitationCodeIQSerializer alloc] initWithSchema:ON_CREATE_INVITATION_CODE_SCHEMA_ID schemaVersion:1];
    
    IQ_GET_INVITATION_CODE_SERIALIZER = [[TLGetInvitationCodeIQSerializer alloc] initWithSchema:GET_INVITATION_CODE_SCHEMA_ID schemaVersion:1];
    IQ_ON_GET_INVITATION_CODE_SERIALIZER = [[TLOnGetInvitationCodeIQSerializer alloc] initWithSchema:ON_GET_INVITATION_CODE_SCHEMA_ID schemaVersion:1];
}

+ (nonnull NSString *)VERSION {
    
    return TWINCODE_OUTBOUND_SERVICE_VERSION;
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    _serviceProvider = [[TLTwincodeOutboundServiceProvider alloc] initWithService:self database:twinlife.databaseService];
    _twincodeJob = [[TLTwincodeOutboundJob alloc] initWithService:self];
    _pendingRequests = [[NSMutableDictionary alloc] init];
    _serializerFactory = twinlife.serializerFactory;
    _cryptoService = [twinlife getCryptoService];
    _serviceJid = [NSString stringWithFormat:@"%@.%@.twinlife", TWINLIFE_SERVICE_NAME, TWINLIFE_NAME];

    // Register the binary IQ handlers for the responses.
    [twinlife addPacketListener:IQ_ON_GET_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onGetTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_UPDATE_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onUpdateTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_REFRESH_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onRefreshTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_INVOKE_TWINCODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onInvokeTwincodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_CREATE_INVITATION_CODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onCreateInvitationCodeWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_GET_INVITATION_CODE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onGetInvitationCodeWithIQ:iq];
    }];
    
    return self;
}

#pragma mark - TLBaseServiceImpl

- (void)addDelegate:(nonnull id<TLBaseServiceDelegate>)delegate {
    
    if ([delegate conformsToProtocol:@protocol(TLTwincodeOutboundServiceDelegate)]) {
        [super addDelegate:delegate];
    }
}

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLTwincodeOutboundServiceConfiguration* twincodeOutboundServiceConfiguration = [[TLTwincodeOutboundServiceConfiguration alloc] init];
    TLTwincodeOutboundServiceConfiguration* serviceConfiguration = (TLTwincodeOutboundServiceConfiguration *)baseServiceConfiguration;
    twincodeOutboundServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.enableTwincodeRefresh = serviceConfiguration.enableTwincodeRefresh;
    self.serviceConfiguration = twincodeOutboundServiceConfiguration;
    self.serviceOn = twincodeOutboundServiceConfiguration.isServiceOn;
}

- (void)onTwinlifeOnline {
    DDLogVerbose(@"%@ onTwinlifeOnline", LOG_TAG);
    
    [super onTwinlifeOnline];

    [self updateRefreshJob];
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    [super onSignOut];
    
    @synchronized(self) {
        [self.pendingRequests removeAllObjects];
        if (self.refreshJobId) {
            [self.refreshJobId cancel];
            self.refreshJobId = nil;
        }
    }
}

- (void)onDisconnect {
    DDLogVerbose(@"%@ onDisconnect", LOG_TAG);
    
    [super onDisconnect];
    
    @synchronized(self) {
        if (self.refreshJobId) {
            [self.refreshJobId cancel];
            self.refreshJobId = nil;
        }
    }
}

#pragma mark - TLTwincodeOutboundService

- (void)getTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeOutboundId refreshPeriod:(int64_t)refreshPeriod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block {
    DDLogVerbose(@"%@: getTwincodeWithTwincodeId: %@ refreshPeriod: %lld", LOG_TAG, twincodeOutboundId, refreshPeriod);

    if (!self.serviceOn || !twincodeOutboundId) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }
    
    TLTwincodeOutbound *twincodeOutbound = [self.serviceProvider loadTwincodeWithTwincodeId:twincodeOutboundId];
    if (twincodeOutbound && [twincodeOutbound isKnown]) {
        block(TLBaseServiceErrorCodeSuccess, twincodeOutbound);

    } else {
        NSNumber *requestId = [TLBaseService newRequestId];
        @synchronized(self) {
            self.pendingRequests[requestId] = [[TLGetTwincodePendingRequest alloc] initWithTwincodeId:twincodeOutboundId refreshPeriod:refreshPeriod publicKey:nil keyIndex:0 secretKey:nil trustMethod:TLTrustMethodNone complete:block];
        }

        TLGetTwincodeIQ *iq = [[TLGetTwincodeIQ alloc] initWithSerializer:IQ_GET_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeOutboundId];
        [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    }
}

- (void)getSignedTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block {
    DDLogVerbose(@"%@: getSignedTwincodeWithTwincodeId: %@ publicKey: %@ trustMethod: %ld", LOG_TAG, twincodeOutboundId, publicKey, trustMethod);
    
    [self getSignedTwincodeWithTwincodeId:twincodeOutboundId publicKey:publicKey keyIndex:0 secretKey:nil trustMethod:trustMethod withBlock:block];
}

- (void)getSignedTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey trustMethod:(TLTrustMethod)trustMethod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block {
    DDLogVerbose(@"%@: getSignedTwincodeWithTwincodeId: %@ publicKey: %@ keyIndex: %d trustMethod: %ld", LOG_TAG, twincodeOutboundId, publicKey, keyIndex, trustMethod);

    if (!self.serviceOn || !twincodeOutboundId) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLGetTwincodePendingRequest alloc] initWithTwincodeId:twincodeOutboundId refreshPeriod:0 publicKey:publicKey keyIndex:keyIndex secretKey:secretKey trustMethod:trustMethod complete:block];
    }

    TLGetTwincodeIQ *iq = [[TLGetTwincodeIQ alloc] initWithSerializer:IQ_GET_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeOutboundId];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)refreshTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSMutableArray<TLAttributeNameValue *> *_Nullable previousAttributes))block {
    DDLogVerbose(@"%@: refreshTwincodeWithTwincode: %@", LOG_TAG, twincodeOutbound);

    if (!self.serviceOn || !twincodeOutbound) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLRefreshTwincodePendingRequest alloc] initWithTwincode:twincodeOutbound complete:block];
    }

    TLGetTwincodeIQ *iq = [[TLGetTwincodeIQ alloc] initWithSerializer:IQ_GET_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeOutbound.uuid];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)updateTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes deleteAttributeNames:(nullable NSArray<NSString *> *)deleteAttributeNames withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block {
    DDLogVerbose(@"%@: updateTwincodeWithTwincode: %@ attributes: %@ deleteAttributeNames: %@", LOG_TAG, twincodeOutbound, attributes, deleteAttributeNames);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    // If the twincode is signed, build a signature from the final attributes, including
    // the image SHA if there is one.
    NSData *signature;
    BOOL isSigned = [twincodeOutbound isSigned];
    if (isSigned) {
        NSMutableArray<TLAttributeNameValue *> *finalAttributes = [twincodeOutbound getAttributes:attributes deleteAttributeNames:deleteAttributeNames];
        signature = [self.cryptoService signWithTwincode:twincodeOutbound attributes:finalAttributes];
        if (!signature) {
            block(TLBaseServiceErrorCodeBadSignature, nil);
            return;
        }
        attributes = finalAttributes;

    } else {
        signature = nil;
    }
    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLUpdateTwincodePendingRequest alloc] initWithTwincode:twincodeOutbound attributes:attributes isSigned:isSigned complete:block];
    }

    TLUpdateTwincodeIQ *iq = [[TLUpdateTwincodeIQ alloc] initWithSerializer:IQ_UPDATE_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeOutbound.uuid attributes:attributes deleteAttributeNames:nil signature:signature];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)invokeTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound options:(int)options action:(nonnull NSString *)action attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable invocationId))block {
    DDLogVerbose(@"%@: invokeTwincodeWithTwincode: %@ options: %d action: %@ attributes: %@", LOG_TAG, twincodeOutbound, options, action, attributes);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLInvokeTwincodePendingRequest alloc] initWithTwincode:twincodeOutbound complete:block];
    }

    options = options & (TLInvokeTwincodeUrgent | TLInvokeTwincodeWakeup);
    TLInvokeTwincodeIQ *iq = [[TLInvokeTwincodeIQ alloc] initWithSerializer:IQ_INVOKE_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeOutbound.uuid invocationOptions:options invocationId:nil actionName:action attributes:(NSMutableArray<TLAttributeNameValue *> *)attributes data:nil dataLength:0 deadline:0];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)secureInvokeTwincodeWithTwincode:(nonnull TLTwincodeOutbound *)cipherTwincode senderTwincode:(nonnull TLTwincodeOutbound *)senderTwincode receiverTwincode:(nonnull TLTwincodeOutbound *)receiverTwincode options:(int)options action:(nonnull NSString *)action attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable invocationId))block {
    DDLogVerbose(@"%@: secureInvokeTwincodeWithTwincode: %@ senderTwincode: %@ receiverTwincode: %@ options: %d action: %@ attributes: %@", LOG_TAG, cipherTwincode, senderTwincode, receiverTwincode, options, action, attributes);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }

    if (![cipherTwincode isSigned] || ![senderTwincode isSigned] || ![receiverTwincode isSigned]) {
        block(TLBaseServiceErrorCodeNotAuthorizedOperation, nil);
        return;
    }

    TLCipherResult *cipherResult = [self.cryptoService encryptWithTwincode:cipherTwincode senderTwincode:senderTwincode targetTwincode:receiverTwincode options:(options & (TLInvokeTwincodeCreateSecret | TLInvokeTwincodeCreateNewSecret | TLInvokeTwincodeSendSecret)) attributes:attributes];
    if (cipherResult.errorCode != TLBaseServiceErrorCodeSuccess) {
        block(cipherResult.errorCode, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLInvokeTwincodePendingRequest alloc] initWithTwincode:receiverTwincode complete:block];
    }

    options = options & (TLInvokeTwincodeUrgent | TLInvokeTwincodeWakeup);
    TLInvokeTwincodeIQ *iq = [[TLInvokeTwincodeIQ alloc] initWithSerializer:IQ_INVOKE_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:receiverTwincode.uuid invocationOptions:options invocationId:nil actionName:action attributes:nil data:cipherResult.data dataLength:cipherResult.length deadline:0];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (nonnull NSString *)getPeerId:(nonnull NSUUID *)peerTwincodeOutboundId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@: getPeerId: %@ twincodeOutboundId: %@", LOG_TAG, peerTwincodeOutboundId, twincodeOutboundId);
    
    return [NSString stringWithFormat:@"%@@%@.%@/%@", [peerTwincodeOutboundId UUIDString], self.serviceJid, [TLTwinlife TWINLIFE_DOMAIN], [twincodeOutboundId UUIDString]];
}

- (void)evictTwincode:(nonnull NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@: evictTwincode: %@", LOG_TAG, twincodeOutboundId);

    // Remove the twincode from our local database to make sure the next getTwincode()
    // will query the server to retrieve the new information.
    [self.serviceProvider evictTwincode:nil twincodeOutboundId:twincodeOutboundId];
}

- (void)evictWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@: evictWithTwincode: %@", LOG_TAG, twincodeOutbound);

    // Remove the twincode from our local database to make sure the next getTwincode()
    // will query the server to retrieve the new information.
    [self.serviceProvider evictTwincode:twincodeOutbound twincodeOutboundId:nil];
}

- (void)createAuthenticateURIWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block  {
    DDLogVerbose(@"%@ createAuthenticateURIWithTwincode: %@", LOG_TAG, twincodeOutbound);
    
    TLSignResult *result = [self.cryptoService signAuthenticateWithTwincode:twincodeOutbound];
    if (result.errorCode != TLBaseServiceErrorCodeSuccess) {
        block(result.errorCode, nil);
        return;
    }

    // Convert the Base64URL hash to hexadecimal label.
    NSRange pos = [result.signature rangeOfString:@"."];
    NSString *signature = [result.signature substringToIndex:pos.location];
    signature = [[signature stringByReplacingOccurrencesOfString:@"_" withString:@"/"] stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedData:[[signature stringByAppendingString:@"="] dataUsingEncoding:NSUTF8StringEncoding] options:0];

    const unsigned char *dataBuffer = (const unsigned char *)[decodedData bytes];
    if (!dataBuffer) {
        block(TLBaseServiceErrorCodeLibraryError, nil);
        return;
    }

    NSUInteger len = [decodedData length];
    NSMutableString *label = [NSMutableString stringWithCapacity:(len * 3)];
    for (int i = 0; i < len; ++i) {
        if (i > 0 && (i % 2) == 0) {
            [label appendString:@" "];
        }
        [label appendFormat:@"%02X", (int)dataBuffer[i]];
    }

    NSString *uri = [NSString stringWithFormat:@"https://%@/%@", [TLTwincodeURI AUTHENTICATE_ACTION], result.signature];
    TLTwincodeURI *twincodeUri = [[TLTwincodeURI alloc] initWithKind:TLTwincodeURIKindAuthenticate twincodeId:twincodeOutbound.uuid twincodeOptions:nil uri:uri label:label publicKey:result.signature];
    block(TLBaseServiceErrorCodeSuccess, twincodeUri);
}

- (void)createURIWithTwincodeKind:(TLTwincodeURIKind)kind twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block {
    DDLogVerbose(@"%@ createURIWithTwincodeKind: %lu twincodeOutbound: %@", LOG_TAG, (unsigned long)kind, twincodeOutbound);

    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    if (kind == TLTwincodeURIKindAuthenticate) {
        [self createAuthenticateURIWithTwincode:twincodeOutbound withBlock:block];
        return;
    }

    NSUUID *twincodeId = twincodeOutbound.uuid;
    NSString *uri;
    NSString *label;
    NSString *pubKey;
    if (twincodeOutbound.isSigned) {
        pubKey = [self.cryptoService getPublicKeyWithTwincode:twincodeOutbound];
    } else {
        pubKey = nil;
    }
    switch (kind) {
        case TLTwincodeURIKindInvitation:
            label = twincodeId.UUIDString;
            uri = [NSString stringWithFormat:@"%@/%@", TLTwincodeURI.INVITE_ACTION, [NSUUID fromUUID:twincodeId]];
            if (pubKey) {
                uri = [NSString stringWithFormat:@"%@.%@", uri, pubKey];
            }
            break;
            
        case TLTwincodeURIKindCall:
            label = [NSUUID fromUUID:twincodeId];
            uri = [NSString stringWithFormat:@"%@%@%@", TLTwincodeURI.CALL_ACTION, TLTwincodeURI.CALL_PATH,  label];
            break;
            
        case TLTwincodeURIKindTransfer:
            label = [NSUUID fromUUID:twincodeId];
            uri = [NSString stringWithFormat:@"%@%@%@", TLTwincodeURI.TRANSFER_ACTION, TLTwincodeURI.CALL_PATH,  label];
            break;
            
        case TLTwincodeURIKindAccountMigration:
            label = [NSUUID fromUUID:twincodeId];
            uri = [NSString stringWithFormat:@"%@/?id=%@", TLTwincodeURI.ACCOUNT_MIGRATION_ACTION, twincodeId.UUIDString];
            break;
            
        case TLTwincodeURIKindSpaceCard:
            label = [NSUUID fromUUID:twincodeId];
            uri = [NSString stringWithFormat:@"%@/?id=%@", TLTwincodeURI.INVITE_ACTION,  twincodeId.UUIDString];
            break;
            
        default:
            block(TLBaseServiceErrorCodeBadRequest, nil);
            return;
    }
    
    uri = [NSString stringWithFormat:@"https://%@", uri];
    TLTwincodeURI *twincodeUri = [[TLTwincodeURI alloc] initWithKind:kind twincodeId:twincodeId twincodeOptions:nil uri:uri label:label publicKey:pubKey];
    
    block(TLBaseServiceErrorCodeSuccess, twincodeUri);
}

- (BOOL)isValidHostname:(nonnull NSString *)hostname {
    DDLogVerbose(@"%@ isValidHostname: %@", LOG_TAG, hostname);

    const char *host = [hostname UTF8String];
    struct addrinfo hints, *res;

    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;    // IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM;

    int status = getaddrinfo(host, NULL, &hints, &res);
    if (status != 0) {
        return NO;
    }
    freeaddrinfo(res);
    return YES;
}

- (void)parseUriWithUri:(nonnull NSURL *)uri withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeURI *_Nullable twincodeUri))block {
    DDLogVerbose(@"%@ parseUriWithUri: %@", LOG_TAG, uri);

    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    NSString *host = uri.host;
    NSString *path = uri.path;
    
    NSUUID *twincodeId;
    NSString *label;
    NSString *options;
    NSString *publicKey = nil;

    if (!host) {
        if (!path) {
            path = [uri absoluteString];
            if (!path) {
                block(TLBaseServiceErrorCodeBadRequest, nil);
                return;
            }
        }
        
        NSRange range = [path rangeOfString:@"."];
        if (range.length > 0) {
            NSUInteger sep = range.location;
            twincodeId = [NSUUID toUUID:[path substringToIndex:sep]];
            options = [path substringFromIndex:sep+1];
            range = [options rangeOfString:@"."];
            if (range.length > 0) {
                sep = range.location;
                publicKey = [options substringToIndex:sep];
                options = [options substringFromIndex:sep + 1];
            } else if (options.length >= 30) {
                publicKey = options;
                options = nil;
            }
        } else {
            twincodeId = [NSUUID toUUID:path];
        }
        
        label = path;
        TLTwincodeURI *twincodeUri;
        if (!twincodeId) {
            TLSNIProxyDescriptor *proxyDescriptor = [TLSNIProxyDescriptor createWithProxyDescription:path];
            if (!proxyDescriptor) {
                block(TLBaseServiceErrorCodeBadRequest, nil);
                return;
            }
            // Verify the validity of the hostname (it must not be done by create() so we have to do it here).
            if (![self isValidHostname:proxyDescriptor.host]) {
                block(TLBaseServiceErrorCodeItemNotFound, nil);
                return;
            }
            twincodeUri = [[TLTwincodeURI alloc] initWithKind:TLTwincodeURIKindProxy twincodeId:[TLTwincode NOT_DEFINED] twincodeOptions:options uri:[uri absoluteString] label:label publicKey:nil];

        } else {
            twincodeUri = [[TLTwincodeURI alloc] initWithKind:TLTwincodeURIKindInvitation twincodeId:twincodeId twincodeOptions:options uri:[uri absoluteString] label:label publicKey:publicKey];
        }
        block(TLBaseServiceErrorCodeSuccess, twincodeUri);
        return;
    }
    
    TLTwincodeURIKind kind;
    if ([host isEqualToString:TLTwincodeURI.INVITE_ACTION]) {
        kind = TLTwincodeURIKindInvitation;
    } else if ([host isEqualToString:TLTwincodeURI.CALL_ACTION]) {
        kind = TLTwincodeURIKindCall;
    } else if ([host isEqualToString:TLTwincodeURI.TRANSFER_ACTION]) {
        kind = TLTwincodeURIKindTransfer;
    } else if ([host isEqualToString:TLTwincodeURI.ACCOUNT_MIGRATION_ACTION]) {
        kind = TLTwincodeURIKindAccountMigration;
    } else if ([host isEqualToString:TLTwincodeURI.AUTHENTICATE_ACTION]) {
        kind = TLTwincodeURIKindAuthenticate;
    } else if ([host isEqualToString:TLTwincodeURI.PROXY_ACTION]) {
        kind = TLTwincodeURIKindProxy;
    } else {
        block(TLBaseServiceErrorCodeFeatureNotImplemented, nil);
        return;
    }
    
    if (kind == TLTwincodeURIKindAuthenticate) {
        if (!path) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }
        int first = 0;
        while (first < path.length && [path characterAtIndex:first] == '/') {
            first++;
        }
        path = [path substringFromIndex:first];
        NSArray<NSString *> *items = [path componentsSeparatedByString:@"."];
        if (items.count <= 2) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }
        publicKey = path;
        label = items[0];
        twincodeId = [TLTwincode NOT_DEFINED];
        
    } else if (kind == TLTwincodeURIKindProxy) {
        if (!path) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }
        int first = 0;
        while (first < path.length && [path characterAtIndex:first] == '/') {
            first++;
        }
        path = [path substringFromIndex:first];
        label = path;
        if (path.length >= 2 && [path characterAtIndex:1] == '/') {
            path = [path substringFromIndex:2];
        }

        // Verify the format of the proxy description.
        options = path;
        TLSNIProxyDescriptor *proxyDescriptor = [TLSNIProxyDescriptor createWithProxyDescription:options];
        if (!proxyDescriptor) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }

        // Verify the validity of the hostname (it must not be done by create() so we have to do it here).
        if (![self isValidHostname:proxyDescriptor.host]) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }
        twincodeId = [TLTwincode NOT_DEFINED];
        
    } else if (path && [path hasPrefix:TLTwincodeURI.CALL_PATH]) {
        if (kind != TLTwincodeURIKindCall && kind != TLTwincodeURIKindTransfer) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }
        NSString *value = [path substringToIndex:TLTwincodeURI.CALL_PATH.length];
        twincodeId = [NSUUID toUUID:value];
        label = value;
    } else if (path && [path hasPrefix:TLTwincodeURI.SPACE_PATH]) {
        if (kind != TLTwincodeURIKindInvitation) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }
        kind = TLTwincodeURIKindSpaceCard;
        NSString *value = [path substringToIndex:TLTwincodeURI.SPACE_PATH.length];
        twincodeId = [NSUUID toUUID:value];
        label = value;
    } else {
        NSArray<NSString *> *items;

        // Recognize:
        // - https://<site>?param=twincode
        // - https://<site>/?param=twincode
        // - https://<site>/<twincode>.<options>
        // - https://<site>/<twincode>.<pubkey>
        // - https://<site>/<twincode>.<pubkey>.<options>
        // We assume length(options) < 30) and length(pubKey) > 30.
        if (path && ![path isEqual:@"/"] && ![path isEqual:@""]) {
            int first = 0;
            while (first < path.length && [path characterAtIndex:first] == '/') {
                first++;
            }
            path = [path substringFromIndex:first];
            items = [path componentsSeparatedByString:@"."];

        } else {
            NSString *param = [uri queryParamWithName:TLTwincodeURI.PARAM_ID];
            if (!param) {
                param = [uri queryParamWithName:@"id"];
            }
            if (!param) {
                block(TLBaseServiceErrorCodeItemNotFound, nil);
                return;
            }

            items = [param componentsSeparatedByString:@"."];
        }
        if (items.count == 0) {
            block(TLBaseServiceErrorCodeBadRequest, nil);
            return;
        }
        label = items[0];
        twincodeId = [NSUUID toUUID:label];
        if (items.count >= 2) {
            if (items.count >= 3) {
                publicKey = items[1];
                options = items[2];
            } else if (items[1].length < 30) {
                options = items[1];
            } else {
                publicKey = items[1];
            }
        }
    }
    if (!twincodeId) {
        block(TLBaseServiceErrorCodeBadRequest, nil);
        return;
    }
    TLTwincodeURI *twincodeUri = [[TLTwincodeURI alloc] initWithKind:kind twincodeId:twincodeId twincodeOptions:options uri:[uri absoluteString] label:label publicKey:publicKey];

    block(TLBaseServiceErrorCodeSuccess, twincodeUri);
    return;
}

- (void)createPrivateKeyWithTwincode:(nonnull TLTwincodeInbound *)twincodeInbound withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound))block {
    DDLogVerbose(@"%@ createPrivateKeyWithTwincode: %@", LOG_TAG, twincodeInbound);
    
    if (!self.serviceOn) {
        block(TLBaseServiceErrorCodeServiceUnavailable, nil);
        return;
    }
    
    // Create the private keys for the twincode if they don't exist yet.
    TLTwincodeOutbound *twincodeOutbound = twincodeInbound.twincodeOutbound;
    TLBaseServiceErrorCode errorCode = [self.cryptoService createPrivateKeyWithTwincodeInbound:twincodeInbound twincodeOutbound:twincodeOutbound];
    if (errorCode != TLBaseServiceErrorCodeSuccess) {
        block(errorCode, nil);
        return;
    }

    // Build a signature from the final attributes, including the image SHA if there is one.
    // The `signWithTwincode()` method will update finalAttributes to insert the avatarId attribute for the server if there is one.
    NSArray<TLAttributeNameValue *> *attributes = [[NSArray alloc] init];
    NSMutableArray<TLAttributeNameValue *> *finalAttributes = [twincodeOutbound getAttributes:attributes deleteAttributeNames:nil];
    NSData *signature = [self.cryptoService signWithTwincode:twincodeOutbound attributes:finalAttributes];
    if (!signature) {
        block(TLBaseServiceErrorCodeBadSignature, nil);
        return;
    }

    NSNumber *requestId = [TLBaseService newRequestId];
    @synchronized(self) {
        self.pendingRequests[requestId] = [[TLUpdateTwincodePendingRequest alloc] initWithTwincode:twincodeOutbound attributes:finalAttributes isSigned:YES complete:block];
    }

    TLUpdateTwincodeIQ *iq = [[TLUpdateTwincodeIQ alloc] initWithSerializer:IQ_UPDATE_TWINCODE_SERIALIZER requestId:requestId.longLongValue twincodeId:twincodeOutbound.uuid attributes:finalAttributes deleteAttributeNames:nil signature:signature];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)associateTwincodes:(nonnull TLTwincodeOutbound *)twincodeOutbound previousPeerTwincode:(nullable TLTwincodeOutbound *)previousPeerTwincode peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode {
    DDLogVerbose(@"%@ associateTwincodes: %@ previousPeerTwincode: %@ peerTwincode: %@", LOG_TAG, twincodeOutbound, previousPeerTwincode, peerTwincode);

    [self.serviceProvider associateTwincodes:twincodeOutbound previousPeerTwincode:previousPeerTwincode peerTwincode:peerTwincode];
}

- (void)setCertifiedWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode trustMethod:(TLTrustMethod)trustMethod {
    DDLogVerbose(@"%@ setCertifiedWithTwincode: %@ peerTwincode: %@ trustMethod: %lu", LOG_TAG, twincodeOutbound, peerTwincode, trustMethod);

    [self.serviceProvider setCertifiedWithTwincode:twincodeOutbound peerTwincode:peerTwincode trustMethod:trustMethod];
}

- (void)createInvitationCodeWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound validityPeriod:(int)validityPeriod withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLInvitationCode *_Nullable invitationCode))block {
    DDLogVerbose(@"%@ createInvitationCodeWithTwincodeOutbound: %@ validityPeriod:%d", LOG_TAG, twincodeOutbound, validityPeriod);

    int64_t requestId = [TLTwinlife newRequestId];
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self) {
        self.pendingRequests[lRequestId] = [[TLCreateInvitationCodePendingRequest alloc] initWithTwincodeOutbound:twincodeOutbound consumer:block];
    }
    
    NSString *publicKey = [self.cryptoService getPublicKeyWithTwincode:twincodeOutbound];

    TLCreateInvitationCodeIQ *iq = [[TLCreateInvitationCodeIQ alloc] initWithSerializer:IQ_CREATE_INVITATION_CODE_SERIALIZER requestId:requestId twincodeId:twincodeOutbound.uuid validityPeriod:validityPeriod publicKey:publicKey];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    
}

- (void)getInvitationCodeWithCode:(nonnull NSString *)code withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *_Nullable twincodeOutbound, NSString *_Nullable publicKey))block {
    DDLogVerbose(@"%@ getInvitationCodeWithCode: %@", LOG_TAG, code);

    int64_t requestId = [TLTwinlife newRequestId];
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self) {
        self.pendingRequests[lRequestId] = [[TLGetInvitationCodePendingRequest alloc] initWithCode:code consumer:block];
    }
    
    TLGetInvitationCodeIQ *iq = [[TLGetInvitationCodeIQ alloc] initWithSerializer:IQ_GET_INVITATION_CODE_SERIALIZER requestId:requestId code:code];
    
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

#pragma mark - TLTwincodeOutboundService ()

- (void)onGetTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGetTwincodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnGetTwincodeIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];

    TLOnGetTwincodeIQ *onGetTwincodeIQ = (TLOnGetTwincodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLTwincodePendingRequest *request;
    @synchronized (self) {
        request = self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    NSData *signature = onGetTwincodeIQ.signature;
    if ([request isKindOfClass:[TLGetTwincodePendingRequest class]]) {
        TLGetTwincodePendingRequest *getRequest = (TLGetTwincodePendingRequest *) request;
        if (!getRequest.twincodeId) {
            return;
        }
        
        NSData *pubKey = nil;
        NSData *encryptKey = nil;
        if (signature && getRequest.publicKey) {
            TLVerifyResult *result = [self.cryptoService verifyWithPublicKey:getRequest.publicKey twincodeId:getRequest.twincodeId attributes:onGetTwincodeIQ.attributes signature:signature];
            if (result.errorCode != TLBaseServiceErrorCodeSuccess) {
                if (getRequest.complete) {
                    getRequest.complete(result.errorCode, nil);
                }
                return;
            }
            pubKey = result.publicSigningKey;
            encryptKey = result.publicEncryptionKey;
        }
        TLTwincodeOutbound *twincodeOutbound = [self.serviceProvider importTwincodeWithTwincodeId:getRequest.twincodeId attributes:onGetTwincodeIQ.attributes pubSigningKey:pubKey pubEncryptionKey:encryptKey keyIndex:getRequest.keyIndex secretKey:getRequest.secretKey trustMethod:getRequest.trustMethod modificationDate:onGetTwincodeIQ.modificationDate refreshPeriod:getRequest.refreshPeriod];
        
        if (getRequest.complete) {
            getRequest.complete(twincodeOutbound ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeNoStorageSpace, twincodeOutbound);
        }
    } else {
        TLRefreshTwincodePendingRequest *refreshRequest = (TLRefreshTwincodePendingRequest *) request;
        if (!refreshRequest.twincodeOutbound) {
            return;
        }
        if (signature) {
            TLVerifyResult *result = [self.cryptoService verifyWithTwincode:refreshRequest.twincodeOutbound attributes:onGetTwincodeIQ.attributes signature:signature];
            // Ignore TLBaseServiceErrorCodeNoPublicKey: we're just checking for twincode attributes updates, and if we don't have a public key yet we have no way to check the signature.
            if (result.errorCode != TLBaseServiceErrorCodeSuccess && result.errorCode != TLBaseServiceErrorCodeNoPublicKey) {
                if (refreshRequest.complete) {
                    refreshRequest.complete(result.errorCode, nil);
                }
                return;
            }
        }
        
        NSMutableArray<TLAttributeNameValue *> *previousAttributes = [[NSMutableArray alloc] init];
        [self.serviceProvider refreshTwincodeWithTwincode:refreshRequest.twincodeOutbound attributes:onGetTwincodeIQ.attributes previousAttributes:previousAttributes modificationDate:onGetTwincodeIQ.modificationDate];
        
        if (refreshRequest.complete) {
            refreshRequest.complete(TLBaseServiceErrorCodeSuccess, previousAttributes);
        }
    }
}

- (void)onUpdateTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onUpdateTwincodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnUpdateTwincodeIQ class]]) {
        return;
    }

    [self receivedBinaryIQ:iq];

    TLOnUpdateTwincodeIQ *onUpdateTwincodeIQ = (TLOnUpdateTwincodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLUpdateTwincodePendingRequest *request;
    @synchronized (self) {
        request = (TLUpdateTwincodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    if (!request.twincode || !request.attributes) {
        return;
    }

    [self.serviceProvider updateTwincodeWithTwincode:request.twincode attributes:request.attributes modificationDate:onUpdateTwincodeIQ.modificationDate isSigned:request.isSigned];
    
    request.complete(TLBaseServiceErrorCodeSuccess, request.twincode);
}

- (void)onRefreshTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onRefreshTwincodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnRefreshTwincodeIQ class]]) {
        return;
    }

    [self receivedBinaryIQ:iq];

    TLOnRefreshTwincodeIQ *onRefreshTwincodeIQ = (TLOnRefreshTwincodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLRefreshTwincodesPendingRequest *request;
    @synchronized (self) {
        request = (TLRefreshTwincodesPendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    if (!request.refreshList) {
        return;
    }

    // Delete the twincodes.
    NSArray<NSUUID *> *deleteList = onRefreshTwincodeIQ.deleteTwincodeList;
    if (deleteList) {
        for (NSUUID *twincodeId in deleteList) {
            NSNumber *databaseId = request.refreshList[twincodeId];
            if (databaseId != nil) {
                [self.serviceProvider deleteTwincode:databaseId];
            }
            [request.refreshList removeObjectForKey:twincodeId];
        }
    }

    int64_t timestamp = onRefreshTwincodeIQ.timestamp;

    // Update the twincodes.
    NSMutableArray<TLRefreshTwincodeInfo *> *updateList = onRefreshTwincodeIQ.updateTwincodeList;
    if (updateList) {
        for (TLRefreshTwincodeInfo *twincodeId in updateList) {
            NSNumber *databaseId = request.refreshList[twincodeId.twincodeOutboundId];

            [request.refreshList removeObjectForKey:twincodeId.twincodeOutboundId];
            if (databaseId == nil) {
                continue;
            }

            NSMutableArray<TLAttributeNameValue *> *previousAttributes = [[NSMutableArray alloc] init];
            TLTwincodeOutbound *twincodeOutbound = [self.serviceProvider refreshTwincodeWithTwincodeId:databaseId.longValue attributes:twincodeId.attributes previousAttributes:previousAttributes modificationDate:timestamp];
            
            for (id<TLBaseServiceDelegate> delegate in self.delegates) {
                if ([delegate respondsToSelector:@selector(onRefreshTwincodeWithTwincode:previousAttributes:)]) {
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [(id<TLTwincodeOutboundServiceDelegate>)delegate onRefreshTwincodeWithTwincode:twincodeOutbound previousAttributes:previousAttributes];
                    });
                }
            }
        }
    }
    
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    [self.serviceProvider updateRefreshTimestampWithList:[request.refreshList allValues] refreshTimestamp:timestamp currentDate:now];

    [self updateRefreshJob];
}

- (void)onInvokeTwincodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onInvokeTwincodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLInvocationIQ class]]) {
        return;
    }

    [self receivedBinaryIQ:iq];

    TLInvocationIQ *invocationIQ = (TLInvocationIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLInvokeTwincodePendingRequest *request;
    @synchronized (self) {
        request = (TLInvokeTwincodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    request.complete(TLBaseServiceErrorCodeSuccess, invocationIQ.invocationId);
}

- (void)onCreateInvitationCodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCreateInvitationCodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnCreateInvitationCodeIQ class]]) {
        return;
    }

    [self receivedBinaryIQ:iq];

    TLOnCreateInvitationCodeIQ *icIQ = (TLOnCreateInvitationCodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLCreateInvitationCodePendingRequest *request;
    @synchronized (self) {
        request = (TLCreateInvitationCodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    NSString *publicKey = [self.cryptoService getPublicKeyWithTwincode:request.twincodeOutbound];
    
    TLInvitationCode *invitationCode = [[TLInvitationCode alloc] initWithCreationDate:icIQ.creationDate validityPeriod:icIQ.validityPeriod code:icIQ.code publicKey:publicKey];
    
    request.consumer(TLBaseServiceErrorCodeSuccess, invitationCode);
}

- (void)onGetInvitationCodeWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGetInvitationCodeWithIQ: %@", LOG_TAG, iq);

    if (![iq isKindOfClass:[TLOnGetInvitationCodeIQ class]]) {
        return;
    }

    [self receivedBinaryIQ:iq];

    TLOnGetInvitationCodeIQ *icIQ = (TLOnGetInvitationCodeIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLGetInvitationCodePendingRequest *request;
    @synchronized (self) {
        request = (TLGetInvitationCodePendingRequest *)self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }
        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    NSString *publicKey = icIQ.publicKey;

    NSData *signature = icIQ.signature;
    
    TLTrustMethod trustMethod = TLTrustMethodNone;
    NSData *signingKey = nil;
    NSData *encryptionKey = nil;
    
    if (publicKey && signature) {
        TLVerifyResult *result = [self.cryptoService verifyWithPublicKey:publicKey twincodeId:icIQ.twincodeId attributes:icIQ.attributes signature:signature];
        if (result.errorCode != TLBaseServiceErrorCodeSuccess) {
            if (request.consumer) {
                request.consumer(result.errorCode, nil, nil);
            }
            return;
        }

        signingKey = result.publicSigningKey;
        encryptionKey = result.publicEncryptionKey;
        trustMethod = TLTrustMethodInvitationCode;
    }
    
    
    TLTwincodeOutbound *twincodeOutbound = [self.serviceProvider importTwincodeWithTwincodeId:icIQ.twincodeId attributes:icIQ.attributes pubSigningKey:signingKey pubEncryptionKey:encryptionKey keyIndex:0 secretKey:nil trustMethod:trustMethod modificationDate:icIQ.modificationDate refreshPeriod:TL_REFRESH_PERIOD];
    
    request.consumer(twincodeOutbound ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeNoStorageSpace, twincodeOutbound, publicKey);
}

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);
    
    int64_t requestId = errorPacketIQ.requestId;
    TLBaseServiceErrorCode errorCode = errorPacketIQ.errorCode;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    TLTwincodePendingRequest *request;

    [self receivedBinaryIQ:errorPacketIQ];
    @synchronized(self) {
        request = self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
    }

    // The object no longer exists on the server, remove it from our local database.
    if ([request isKindOfClass:[TLGetTwincodePendingRequest class]]) {
        TLGetTwincodePendingRequest *getRequest = (TLGetTwincodePendingRequest *)request;
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self evictTwincode:getRequest.twincodeId];
        }
        getRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLRefreshTwincodePendingRequest class]]) {
        TLRefreshTwincodePendingRequest *refreshRequest = (TLRefreshTwincodePendingRequest *)request;
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self evictWithTwincode:refreshRequest.twincodeOutbound];
        }
        refreshRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLUpdateTwincodePendingRequest class]]) {
        TLUpdateTwincodePendingRequest *updateRequest = (TLUpdateTwincodePendingRequest *)request;
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self evictWithTwincode:updateRequest.twincode];
        }
        updateRequest.complete(errorCode, nil);

    } else if ([request isKindOfClass:[TLRefreshTwincodesPendingRequest class]]) {
        [self updateRefreshJob];

    } else if ([request isKindOfClass:[TLInvokeTwincodePendingRequest class]]) {
        TLInvokeTwincodePendingRequest *invokeRequest = (TLInvokeTwincodePendingRequest *)request;
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self evictWithTwincode:invokeRequest.twincode];
        }
        invokeRequest.complete(errorCode, nil);
    } else if ([request isKindOfClass:[TLGetInvitationCodePendingRequest class]]) {
        TLGetInvitationCodePendingRequest *invitationCodePendingRequest = (TLGetInvitationCodePendingRequest *)request;
        invitationCodePendingRequest.consumer(errorCode, nil, nil);
    }
}

#pragma mark - Private methods

- (void)runRefreshJob {
    DDLogVerbose(@"%@ runRefreshJob", LOG_TAG);

    self.refreshJobId = nil;
    [self refreshTwincodes];
}

- (void)refreshTwincodes {
    DDLogVerbose(@"%@ refreshTwincodes", LOG_TAG);
    
    TLTwincodeRefreshInfo *refreshInfo = [self.serviceProvider getRefreshListWithMaxCount:MAX_REFRESH_TWINCODES];
    if (!refreshInfo || !refreshInfo.twincodes || refreshInfo.twincodes.count == 0) {

        [self updateRefreshJob];
        return;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    @synchronized (self) {
        self.pendingRequests[lRequestId] = [[TLRefreshTwincodesPendingRequest alloc] initWithRefreshList:refreshInfo.twincodes];
    }

    TLRefreshTwincodeIQ *iq = [[TLRefreshTwincodeIQ alloc] initWithSerializer:IQ_REFRESH_TWINCODE_SERIALIZER requestId:requestId timestamp:refreshInfo.timestamp twincodeList:refreshInfo.twincodes];
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)updateRefreshJob {
    DDLogVerbose(@"%@ updateRefreshJob", LOG_TAG);

    if (self.refreshJobId) {
        [self.refreshJobId cancel];
        self.refreshJobId = nil;
    }

    if (!self.isTwinlifeOnline || !self.enableTwincodeRefresh) {
        return;
    }

    int64_t deadline = [self.serviceProvider getRefreshDeadline];
    if (deadline > 0) {
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:deadline / 1000LL];
        self.refreshJobId = [[self.twinlife getJobService] scheduleWithJob:self.twincodeJob deadline:date priority:TLJobPriorityMessage];
    }
}

@end

/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLConversationServiceIQ.h"
#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLAudioDescriptorImpl.h"
#import "TLImageDescriptorImpl.h"
#import "TLObjectDescriptorImpl.h"
#import "TLNamedFileDescriptorImpl.h"
#import "TLGeolocationDescriptorImpl.h"
#import "TLVideoDescriptorImpl.h"
#import "TLConversationServiceImpl.h"
#import "TLTransientObjectDescriptorImpl.h"
#import "TLPushTransientObjectOperation.h"
#import "TLPushTwincodeOperation.h"
#import "TLResetConversationOperation.h"
#import "TLServiceRequestIQ.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLOnJoinGroupIQ.h"
#import "TLResetConversationIQ.h"
#import "TLOnResetConversationIQ.h"
#import "TLPushTwincodeIQ.h"
#import "TLJoinGroupIQ.h"
#import "TLInviteGroupIQ.h"
#import "TLOnInviteGroupIQ.h"
#import "TLPushTransientIQ.h"
#import "TLPushGeolocationIQ.h"
#import "TLOnPushGeolocationIQ.h"
#import "TLPushObjectIQ.h"
#import "TLOnPushObjectIQ.h"
#import "TLPushTwincodeIQ.h"
#import "TLOnPushTwincodeIQ.h"
#import "TLPushFileIQ.h"
#import "TLOnPushFileIQ.h"
#import "TLPushFileChunkIQ.h"
#import "TLOnPushFileChunkIQ.h"
#import "TLUpdateTimestampIQ.h"
#import "TLUpdatePermissionsIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int SERIALIZER_BUFFER_DEFAULT_SIZE = 1024;

static const int CONVERSATION_SERVICE_MINOR_VERSION_10 = 10;
static const int CONVERSATION_SERVICE_MINOR_VERSION_9 = 9;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_8 = 8;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_7 = 7;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_6 = 6;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_5 = 5;
//static const int CONVERSATION_SERVICE_MINOR_VERSION_4 = 4;
//static const int CONVERSATION_SERVICE_MINOR_VERSION_2 = 2;
//static const int CONVERSATION_SERVICE_MINOR_VERSION_1 = 1;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_0 = 0;

@implementation TLUnsupportedException

@end

#pragma mark - TLConversationServiceResetConversationIQ

/**
 * <pre>
 *
 * Schema version 3
 *  Date: 2018/10/01
 *  Add support for group reset conversation
 *
 * {
 *  "schemaId":"412f43fa-bee9-4268-ac6f-98e99e457d03",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"ResetConversationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {"name":"minSequenceId", "type":"long"},
 *   {"name":"peerMinSequenceId", "type":"long"},
 *   {"type":"array","items":
 *    {"type":"record",
 *     "fields":
 *     [
 *      {"name":"memberTwincodeOutboundId","type","uuid"},
 *      {"name":"peerMinSequenceId","type","long"}
 *     ]
 *    }
 *   }
 *  ]
 * }
 *
 * Schema version 2
 *  Date: 2016/09/08
 *
 * {
 *  "schemaId":"412f43fa-bee9-4268-ac6f-98e99e457d03",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"ResetConversationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {"name":"minSequenceId", "type":"long"},
 *   {"name":"peerMinSequenceId", "type":"long"}
 *  ]
 * }
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"412f43fa-bee9-4268-ac6f-98e99e457d03",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ResetConversationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {"name":"minSequenceId", "type":"long"},
 *   {"name":"peerMinSequenceId", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLConversationServiceResetConversationIQ ()
//

@interface TLConversationServiceResetConversationIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(NSMutableArray<TLDescriptorId*> *)resetMembers;

@end

//
// Implementation: TLConversationServiceResetConversationIQSerializer
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceResetConversationIQSerializer"

@implementation TLConversationServiceResetConversationIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLResetConversationIQ.SCHEMA_ID schemaVersion:TLConversationServiceResetConversationIQ.SCHEMA_VERSION class:[TLConversationServiceResetConversationIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServiceResetConversationIQ *resetConversationIQ = (TLConversationServiceResetConversationIQ *)object;
    [encoder writeLong:resetConversationIQ.minSequenceId];
    [encoder writeLong:resetConversationIQ.peerMinSequenceId];
    if (!resetConversationIQ.resetMembers) {
        [encoder writeLong:0];
    } else {
        [encoder writeLong:resetConversationIQ.resetMembers.count];
        for (TLDescriptorId *member in resetConversationIQ.resetMembers) {
            [encoder writeUUID:member.twincodeOutboundId];
            [encoder writeLong:member.sequenceId];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t minSequenceId = [decoder readLong];
    int64_t peerMinSequenceId = [decoder readLong];
    long count = (long)[decoder readLong];
    NSMutableArray<TLDescriptorId*> *resetMembers = nil;
    if (count > 0) {
        resetMembers = [[NSMutableArray alloc] initWithCapacity:count];
        while (count > 0) {
            count--;
            NSUUID *memberTwincodeOutboundId = [decoder readUUID];
            int64_t memberPeerMinSequenceId = [decoder readLong];
            [resetMembers addObject:[[TLDescriptorId alloc] initWithTwincodeOutboundId:memberTwincodeOutboundId sequenceId:memberPeerMinSequenceId]];
        }
    }
    return [[TLConversationServiceResetConversationIQ alloc] initWithServiceRequestIQ:serviceRequestIQ minSequenceId:minSequenceId peerMinSequenceId:peerMinSequenceId resetMembers:resetMembers];
}

@end

//
// Implementation: TLConversationServiceResetConversationIQ
//

static const int RESET_CONVERSATION_SCHEMA_VERSION = 3;
static TLSerializer *RESET_CONVERSATION_SERIALIZER = nil;

@implementation TLConversationServiceResetConversationIQ

+ (void)initialize {
    
    RESET_CONVERSATION_SERIALIZER = [[TLConversationServiceResetConversationIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return RESET_CONVERSATION_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return RESET_CONVERSATION_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(NSArray<TLDescriptorId*> *)resetMembers {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d minSequenceId: %lld peerMinSequenceId: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, minSequenceId, peerMinSequenceId);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:majorVersion == [TLConversationService MAJOR_VERSION_1] ? RESET_CONVERSATION_ACTION_1 : RESET_CONVERSATION_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _minSequenceId = minSequenceId;
        _peerMinSequenceId = peerMinSequenceId;
        _resetMembers = resetMembers;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    if (self.majorVersion == TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 && self.minorVersion >= TLConversationService.CONVERSATION_SERVICE_GROUP_RESET_CONVERSATION_MINOR_VERSION) {
        [[TLConversationServiceResetConversationIQ SERIALIZER] serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    } else {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.0 version at least" userInfo:nil];
    }

    return data;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" minSequenceId:     %lld\n", self.minSequenceId];
    [string appendFormat:@" peerMinSequenceId: %lld\n", self.peerMinSequenceId];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceResetConversationIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(NSMutableArray<TLDescriptorId*> *)resetMembers {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ minSequenceId: %lld peerMinSequenceId: %lld", LOG_TAG, serviceRequestIQ, minSequenceId, peerMinSequenceId);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    if (self) {
        _minSequenceId = minSequenceId;
        _peerMinSequenceId = peerMinSequenceId;
        _resetMembers = resetMembers;
    }
    return self;
}

@end

#pragma mark - TLConversationServiceOnResetConversationIQ

/**
 * <pre>
 *
 * Schema version 2
 *  Date: 2016/10/11
 *
 * {
 *  "schemaId":"09e855f4-61d9-4acf-92ce-8f93c6951fb0",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnResetConversationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  []
 * }
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"09e855f4-61d9-4acf-92ce-8f93c6951fb0",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnResetConversationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  []
 * }
 *
 * </pre>
 */

//
// Interface: TLConversationServiceOnResetConversationIQ ()
//

@interface TLConversationServiceOnResetConversationIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ;

@end

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnResetConversationIQSerializer"

@implementation TLConversationServiceOnResetConversationIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLOnResetConversationIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnResetConversationIQ.SCHEMA_VERSION class:[TLConversationServiceOnResetConversationIQ class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    return [[TLConversationServiceOnResetConversationIQ alloc] initWithServiceResultIQ:serviceResultIQ];
}

@end

//
// Implementation: TLConversationServiceOnResetConversationIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnResetConversationIQ"

static const int ON_RESET_CONVERSATION_SCHEMA_VERSION = 2;
static TLSerializer *ON_RESET_CONVERSATION_SERIALIZER = nil;

@implementation TLConversationServiceOnResetConversationIQ

+ (void)initialize {
    
    ON_RESET_CONVERSATION_SERIALIZER = [[TLConversationServiceOnResetConversationIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_RESET_CONVERSATION_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_RESET_CONVERSATION_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d", LOG_TAG, from, to, requestId, majorVersion, minorVersion);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:majorVersion == [TLConversationService MAJOR_VERSION_1] ? ON_RESET_CONVERSATION_ACTION_1 : ON_RESET_CONVERSATION_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    return self;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnResetConversationIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ {
    DDLogVerbose(@"%@ initWithServiceResultIQ: %@", LOG_TAG, serviceResultIQ);
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    
    return self;
}

@end

#pragma mark - TLConversationServicePushCommandIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2020/04/16
 *
 * {
 *  "schemaId":"e8a69b58-1014-4d3c-9357-8331c19c5f59",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushCommandIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"transientObjectDescriptor",
 *    "type":"org.twinlife.schemas.conversation.TransientObjectDescriptor"
 *   }
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServicePushCommandIQ ()
//

@interface TLConversationServicePushCommandIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ commandDescriptor:(TLTransientObjectDescriptor *)commandDescriptor;

@end

//
// Implementation: TLConversationServicePushCommandIQSerializer ()
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushCommandIQSerializer"

@implementation TLConversationServicePushCommandIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLPushCommandIQ.SCHEMA_ID schemaVersion:TLConversationServicePushCommandIQ.SCHEMA_VERSION class:[TLConversationServicePushCommandIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServicePushCommandIQ *pushCommandIQ = (TLConversationServicePushCommandIQ *)object;
    [TLTransientObjectDescriptor.SERIALIZER serializeWithSerializerFactory:serializerFactory encoder:encoder object:pushCommandIQ.commandDescriptor];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    if ([TLTransientObjectDescriptor.SCHEMA_ID isEqual:schemaId]
        && TLTransientObjectDescriptor.SCHEMA_VERSION == schemaVersion) {
        TLTransientObjectDescriptor *commandDescriptor = (TLTransientObjectDescriptor *)[TLTransientObjectDescriptor.SERIALIZER deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        return [[TLConversationServicePushCommandIQ alloc] initWithServiceRequestIQ:serviceRequestIQ commandDescriptor:commandDescriptor];
    }
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLConversationServicePushCommandIQ
//

static const int PUSH_COMMAND_SCHEMA_VERSION = 1;
static TLSerializer *PUSH_COMMAND_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushCommandIQ"

@implementation TLConversationServicePushCommandIQ

+ (void)initialize {
    
    PUSH_COMMAND_SERIALIZER = [[TLConversationServicePushCommandIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_COMMAND_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return PUSH_COMMAND_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion commandDescriptor:(TLTransientObjectDescriptor *)commandDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d commandDescriptor: %@", LOG_TAG, from, to, requestId, majorVersion, minorVersion, commandDescriptor);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:PUSH_COMMAND_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _commandDescriptor = commandDescriptor;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_PUSH_COMMAND_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.11 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [PUSH_COMMAND_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" commandDescriptor: %@\n", self.commandDescriptor];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServicePushCommandIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ commandDescriptor:(TLTransientObjectDescriptor *)commandDescriptor {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ commandDescriptor: %@", LOG_TAG, serviceRequestIQ, commandDescriptor);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _commandDescriptor = commandDescriptor;
    }
    return self;
}

@end

#pragma mark - TLConversationServiceOnPushCommandIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2020/04/16
 *
 * {
 *  "schemaId":"4453dbf3-1b26-4c13-956c-4b83fc1d0c49",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPushCommandIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  [
 *   {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

@interface TLConversationServiceOnPushCommandIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp;

@end

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushCommandIQSerializer"

@implementation TLConversationServiceOnPushCommandIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLOnPushCommandIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnPushCommandIQ.SCHEMA_VERSION class:[TLConversationServiceOnPushCommandIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServiceOnPushCommandIQ *onPushCommandIQ = (TLConversationServiceOnPushCommandIQ *)object;
    [encoder writeLong:onPushCommandIQ.receivedTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t receivedTimestamp = [decoder readLong];
    return [[TLConversationServiceOnPushCommandIQ alloc] initWithServiceResultIQ:serviceResultIQ receivedTimestamp:receivedTimestamp];
}

@end

//
// Implementation: TLConversationServiceOnPushCommandIQ
//

static const int ON_PUSH_COMMAND_SCHEMA_VERSION = 1;
static TLSerializer *ON_PUSH_COMMAND_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushCommandIQ"

@implementation TLConversationServiceOnPushCommandIQ

+ (void)initialize {
    
    ON_PUSH_COMMAND_SERIALIZER = [[TLConversationServiceOnPushCommandIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_PUSH_COMMAND_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_PUSH_COMMAND_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d receivedTimestamp: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, receivedTimestamp);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:ON_PUSH_COMMAND_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" receivedTimestamp: %lld\n", self.receivedTimestamp];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnPushCommandIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithServiceResultIQ: %@ receivedTimestamp: %lld", LOG_TAG, serviceResultIQ, receivedTimestamp);
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_PUSH_COMMAND_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.11 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [ON_PUSH_COMMAND_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

@end

#pragma mark - TLConversationServicePushGeolocationIQ

/**
 * <pre>
 *
 * Schema version 1
 *  Date: 2019/02/14
 *
 * {
 *  "schemaId":"7a9772c3-5f99-468d-87af-d67fdb181295",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushGeolocationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"geolocationDescriptor",
 *    "type":"org.twinlife.schemas.conversation.GeolocationDescriptor"
 *   }
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServicePushGeolocationIQ ()
//

@interface TLConversationServicePushGeolocationIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ geolocationDescriptor:(TLGeolocationDescriptor *)geolocationDescriptor;

@end

//
// Implementation: TLConversationServicePushGeolocationIQSerializer ()
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushGeolocationIQSerializer"

@implementation TLConversationServicePushGeolocationIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLPushGeolocationIQ.SCHEMA_ID schemaVersion:TLConversationServicePushGeolocationIQ.SCHEMA_VERSION class:[TLConversationServicePushGeolocationIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServicePushGeolocationIQ *pushGeolocationIQ = (TLConversationServicePushGeolocationIQ *)object;
    [TLGeolocationDescriptor.SERIALIZER_1 serializeWithSerializerFactory:serializerFactory encoder:encoder object:pushGeolocationIQ.geolocationDescriptor];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    if ([TLGeolocationDescriptor.SCHEMA_ID isEqual:schemaId]
        && TLGeolocationDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
        TLGeolocationDescriptor *geolocationDescriptor = (TLGeolocationDescriptor *)[TLGeolocationDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        return [[TLConversationServicePushGeolocationIQ alloc] initWithServiceRequestIQ:serviceRequestIQ geolocationDescriptor:geolocationDescriptor];
    }
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLConversationServicePushGeolocationIQ
//

static const int PUSH_GEOLOCATION_SCHEMA_VERSION = 1;
static TLSerializer *PUSH_GEOLOCATION_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushGeolocationIQ"

@implementation TLConversationServicePushGeolocationIQ

+ (void)initialize {
    
    PUSH_GEOLOCATION_SERIALIZER = [[TLConversationServicePushGeolocationIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_GEOLOCATION_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return PUSH_GEOLOCATION_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion geolocationDescriptor:(TLGeolocationDescriptor *)geolocationDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d geolocationDescriptor: %@", LOG_TAG, from, to, requestId, majorVersion, minorVersion, geolocationDescriptor);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:PUSH_GEOLOCATION_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _geolocationDescriptor = geolocationDescriptor;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GEOLOCATION_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.8 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [PUSH_GEOLOCATION_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" geolocationDescriptor: %@\n", self.geolocationDescriptor];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServicePushGeolocationIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ geolocationDescriptor:(TLGeolocationDescriptor *)geolocationDescriptor {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ geolocationDescriptor: %@", LOG_TAG, serviceRequestIQ, geolocationDescriptor);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _geolocationDescriptor = geolocationDescriptor;
    }
    return self;
}

@end

#pragma mark - TLConversationServiceOnPushGeolocationIQ

/**
 * <pre>
 *
 * Schema version 1
 *  Date: 2019/02/14
 *
 * {
 *  "schemaId":"5fd82b6b-5b7f-42c1-976e-f3addf8c5e16",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPushGeolocationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  [
 *   {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

@interface TLConversationServiceOnPushGeolocationIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp;

@end

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushGeolocationIQSerializer"

@implementation TLConversationServiceOnPushGeolocationIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLOnPushGeolocationIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnPushGeolocationIQ.SCHEMA_VERSION class:[TLConversationServiceOnPushGeolocationIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServiceOnPushGeolocationIQ *onPushGeolocationIQ = (TLConversationServiceOnPushGeolocationIQ *)object;
    [encoder writeLong:onPushGeolocationIQ.receivedTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t receivedTimestamp = [decoder readLong];
    return [[TLConversationServiceOnPushGeolocationIQ alloc] initWithServiceResultIQ:serviceResultIQ receivedTimestamp:receivedTimestamp];
}

@end

//
// Implementation: TLConversationServiceOnPushGeolocationIQ
//

static const int ON_PUSH_GEOLOCATION_SCHEMA_VERSION = 1;
static TLSerializer *ON_PUSH_GEOLOCATION_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushGeolocationIQ"

@implementation TLConversationServiceOnPushGeolocationIQ

+ (void)initialize {
    
    ON_PUSH_GEOLOCATION_SERIALIZER = [[TLConversationServiceOnPushGeolocationIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_PUSH_GEOLOCATION_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_PUSH_GEOLOCATION_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d receivedTimestamp: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, receivedTimestamp);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:ON_PUSH_GEOLOCATION_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" receivedTimestamp: %lld\n", self.receivedTimestamp];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnPushGeolocationIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithServiceResultIQ: %@ receivedTimestamp: %lld", LOG_TAG, serviceResultIQ, receivedTimestamp);
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

@end

#pragma mark - TLConversationServicePushObjectIQ

/**
 * <pre>
 *
 * Schema version 4
 *  Date: 2019/03/19
 *
 * {
 *  "schemaId":"26e3a3bd-7db0-4fc5-9857-bbdb2032960e",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"PushObjectIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"objectDescriptor",
 *    "type":"org.twinlife.schemas.conversation.ObjectDescriptor"
 *   }
 *  ]
 * }
 *
 * Schema version 3
 *  Date: 2016/12/29
 *
 * {
 *  "schemaId":"26e3a3bd-7db0-4fc5-9857-bbdb2032960e",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"PushObjectIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"objectDescriptor",
 *    "type":"org.twinlife.schemas.conversation.ObjectDescriptor.3"
 *   }
 *  ]
 * }
 *
 *
 * Schema version 2
 *  Date: 2016/09/08
 *
 * {
 *  "schemaId":"26e3a3bd-7db0-4fc5-9857-bbdb2032960e",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"PushObjectIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"objectDescriptor",
 *    "type":"org.twinlife.schemas.conversation.ObjectDescriptor.2"
 *   }
 *  ]
 * }
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"26e3a3bd-7db0-4fc5-9857-bbdb2032960e",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushObjectIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ.1"
 *  "fields":
 *  [
 *   {
 *    "name":"objectDescriptor",
 *    "type":"org.twinlife.schemas.conversation.ObjectDescriptor.1"
 *   }
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLConversationServicePushObjectIQ ()
//

@interface TLConversationServicePushObjectIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ objectDescriptor:(TLObjectDescriptor *)objectDescriptor;

@end

//
// Implementation: TLConversationServicePushObjectIQSerializer ()
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushObjectIQSerializer"

@implementation TLConversationServicePushObjectIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLPushObjectIQ.SCHEMA_ID schemaVersion:TLConversationServicePushObjectIQ.SCHEMA_VERSION class:[TLConversationServicePushObjectIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServicePushObjectIQ *pushObjectIQ = (TLConversationServicePushObjectIQ *)object;
    [TLObjectDescriptor.SERIALIZER_4 serializeWithSerializerFactory:serializerFactory encoder:encoder object:pushObjectIQ.objectDescriptor];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    if ([TLObjectDescriptor.SCHEMA_ID isEqual:schemaId]
        && TLObjectDescriptor.SCHEMA_VERSION_4 == schemaVersion) {
        TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)[TLObjectDescriptor.SERIALIZER_4 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        return [[TLConversationServicePushObjectIQ alloc] initWithServiceRequestIQ:serviceRequestIQ objectDescriptor:objectDescriptor];
    }
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLConversationServicePushObjectIQ
//

static const int PUSH_OBJECT_SCHEMA_VERSION = 4;
static TLSerializer *PUSH_OBJECT_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushObjectIQ"

@implementation TLConversationServicePushObjectIQ

+ (void)initialize {
    
    PUSH_OBJECT_SERIALIZER = [[TLConversationServicePushObjectIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_OBJECT_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return PUSH_OBJECT_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion objectDescriptor:(TLObjectDescriptor *)objectDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d objectDescriptor: %@", LOG_TAG, from, to, requestId, majorVersion, minorVersion, objectDescriptor);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:majorVersion == [TLConversationService MAJOR_VERSION_1] ? PUSH_OBJECT_ACTION_1 : PUSH_OBJECT_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _objectDescriptor = objectDescriptor;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {

    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];

    if (self.majorVersion == TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 && self.minorVersion >= CONVERSATION_SERVICE_MINOR_VERSION_9) {
        [[TLConversationServicePushObjectIQ SERIALIZER] serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    } else {
        @throw [TLUnsupportedException exceptionWithName:@"TLEncoderException" reason:@"Need 1.0 version at least" userInfo:nil];
    }

    return data;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" objectDescriptor: %@\n", self.objectDescriptor];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServicePushObjectIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ objectDescriptor:(TLObjectDescriptor *)objectDescriptor {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ objectDescriptor: %@", LOG_TAG, serviceRequestIQ, objectDescriptor);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _objectDescriptor = objectDescriptor;
    }
    return self;
}

@end

#pragma mark - TLConversationServiceOnPushObjectIQ

/**
 * <pre>
 *
 * Schema version 2
 *  Date: 2016/09/08
 *
 * {
 *  "schemaId":"f95ac4b5-d20f-4e1f-8204-6d146dd5291e",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnPushObjectIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  [
 *   {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 *
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"f95ac4b5-d20f-4e1f-8204-6d146dd5291e",
 *  "schemaVersion":"1",
 *  "type":"record",
 *  "name":"OnPushObjectIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ.1"
 *  "fields":
 *  [
 *   {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

@interface TLConversationServiceOnPushObjectIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp;

@end

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushObjectIQSerializer"

@implementation TLConversationServiceOnPushObjectIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLOnPushObjectIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnPushObjectIQ.SCHEMA_VERSION class:[TLConversationServiceOnPushObjectIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServiceOnPushObjectIQ *onPushObjectIQ = (TLConversationServiceOnPushObjectIQ *)object;
    [encoder writeLong:onPushObjectIQ.receivedTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t receivedTimestamp = [decoder readLong];
    return [[TLConversationServiceOnPushObjectIQ alloc] initWithServiceResultIQ:serviceResultIQ receivedTimestamp:receivedTimestamp];
}

@end

//
// Implementation: TLConversationServiceOnPushObjectIQ
//

static const int ON_PUSH_OBJECT_SCHEMA_VERSION = 2;
static TLSerializer *ON_PUSH_OBJECT_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushObjectIQ"

@implementation TLConversationServiceOnPushObjectIQ

+ (void)initialize {
    
    ON_PUSH_OBJECT_SERIALIZER = [[TLConversationServiceOnPushObjectIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_PUSH_OBJECT_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_PUSH_OBJECT_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d receivedTimestamp: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, receivedTimestamp);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:majorVersion == [TLConversationService MAJOR_VERSION_1] ? ON_PUSH_OBJECT_ACTION_1 : ON_PUSH_OBJECT_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" receivedTimestamp: %lld\n", self.receivedTimestamp];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnPushObjectIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithServiceResultIQ: %@ receivedTimestamp: %lld", LOG_TAG, serviceResultIQ, receivedTimestamp);
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

@end

#pragma mark - TLConversationServicePushTwincodeIQ

/*
 * <pre>
 * Schema version 1
 *  Date: 2019/04/10
 *
 * {
 *  "schemaId":"72863c61-c0a9-437b-8b88-3b78354e54b8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"twincodeDescriptor",
 *    "type":"org.twinlife.schemas.conversation.TwincodeDescriptor"
 *   }
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServicePushTwincodeIQ ()
//

@interface TLConversationServicePushTwincodeIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ twincodeDescriptor:(TLTwincodeDescriptor *)twincodeDescriptor;

@end

//
// Implementation: TLConversationServicePushTwincodeIQSerializer ()
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushTwincodeIQSerializer"

@implementation TLConversationServicePushTwincodeIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLPushTwincodeIQ.SCHEMA_ID schemaVersion:TLConversationServicePushTwincodeIQ.SCHEMA_VERSION class:[TLConversationServicePushTwincodeIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServicePushTwincodeIQ *pushTwincodeIQ = (TLConversationServicePushTwincodeIQ *)object;
    [TLTwincodeDescriptor.SERIALIZER_1 serializeWithSerializerFactory:serializerFactory encoder:encoder object:pushTwincodeIQ.twincodeDescriptor];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    if ([TLTwincodeDescriptor.SCHEMA_ID isEqual:schemaId]
        && TLTwincodeDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
        TLTwincodeDescriptor *twincodeDescriptor = (TLTwincodeDescriptor *)[TLTwincodeDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        return [[TLConversationServicePushTwincodeIQ alloc] initWithServiceRequestIQ:serviceRequestIQ twincodeDescriptor:twincodeDescriptor];
    }
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLConversationServicePushTwincodeIQ
//

static const int PUSH_TWINCODE_SCHEMA_VERSION = 1;
static TLSerializer *PUSH_TWINCODE_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushTwincodeIQ"

@implementation TLConversationServicePushTwincodeIQ

+ (void)initialize {
    
    PUSH_TWINCODE_SERIALIZER = [[TLConversationServicePushTwincodeIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_TWINCODE_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return PUSH_TWINCODE_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion twincodeDescriptor:(TLTwincodeDescriptor *)twincodeDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d twincodeDescriptor: %@", LOG_TAG, from, to, requestId, majorVersion, minorVersion, twincodeDescriptor);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:PUSH_TWINCODE_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _twincodeDescriptor = twincodeDescriptor;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < CONVERSATION_SERVICE_MINOR_VERSION_10) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.10 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [PUSH_TWINCODE_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" twincodeDescriptor: %@\n", self.twincodeDescriptor];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServicePushTwincodeIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ twincodeDescriptor:(TLTwincodeDescriptor *)twincodeDescriptor {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ twincodeDescriptor: %@", LOG_TAG, serviceRequestIQ, twincodeDescriptor);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _twincodeDescriptor = twincodeDescriptor;
    }
    return self;
}

@end

#pragma mark - TLConversationServiceOnPushTwincodeIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2019/04/10
 *
 * {
 *  "schemaId":"e6726692-8fe6-4d29-ae64-ba321d44a247",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPushTwincodeIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  [
 *   {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

@interface TLConversationServiceOnPushTwincodeIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp;

@end

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushTwincodeIQSerializer"

@implementation TLConversationServiceOnPushTwincodeIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLOnPushTwincodeIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnPushTwincodeIQ.SCHEMA_VERSION class:[TLConversationServiceOnPushTwincodeIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServiceOnPushTwincodeIQ *onPushTwincodeIQ = (TLConversationServiceOnPushTwincodeIQ *)object;
    [encoder writeLong:onPushTwincodeIQ.receivedTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t receivedTimestamp = [decoder readLong];
    return [[TLConversationServiceOnPushTwincodeIQ alloc] initWithServiceResultIQ:serviceResultIQ receivedTimestamp:receivedTimestamp];
}

@end

//
// Implementation: TLConversationServiceOnPushTwincodeIQ
//

static const int ON_PUSH_TWINCODE_SCHEMA_VERSION = 1;
static TLSerializer *ON_PUSH_TWINCODE_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushTwincodeIQ"

@implementation TLConversationServiceOnPushTwincodeIQ

+ (void)initialize {
    
    ON_PUSH_TWINCODE_SERIALIZER = [[TLConversationServiceOnPushTwincodeIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_PUSH_TWINCODE_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_PUSH_TWINCODE_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d receivedTimestamp: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, receivedTimestamp);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:ON_PUSH_TWINCODE_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < CONVERSATION_SERVICE_MINOR_VERSION_10) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.10 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [ON_PUSH_TWINCODE_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" receivedTimestamp: %lld\n", self.receivedTimestamp];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnPushTwincodeIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithServiceResultIQ: %@ receivedTimestamp: %lld", LOG_TAG, serviceResultIQ, receivedTimestamp);
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

@end

#pragma mark - TLConversationServicePushTransientObjectIQ

/**
 * <pre>
 *
 * Schema version 2
 *  Date: 2016/12/29
 *
 * {
 *  "schemaId":"05617876-8419-4240-9945-08bf4106cb72",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"PushTransientObjectIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"transientObjectDescriptor",
 *    "type":"org.twinlife.schemas.conversation.TransientObjectDescriptor"
 *   }
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServicePushTransientObjectIQ ()
//

@interface TLConversationServicePushTransientObjectIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ transientObjectDescriptor:(TLTransientObjectDescriptor *)transientObjectDescriptor;

@end

//
// Implementation: TLConversationServicePushTransientObjectIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushTransientObjectIQ"

@implementation TLConversationServicePushTransientObjectIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLPushTransientIQ.SCHEMA_ID schemaVersion:TLConversationServicePushTransientObjectIQ.SCHEMA_VERSION class:[TLConversationServicePushTransientObjectIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServicePushTransientObjectIQ *pushTransientObjectIQ = (TLConversationServicePushTransientObjectIQ *)object;
    [TLTransientObjectDescriptor.SERIALIZER serializeWithSerializerFactory:serializerFactory encoder:encoder object:pushTransientObjectIQ.transientObjectDescriptor];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *shemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    if ([TLTransientObjectDescriptor.SCHEMA_ID isEqual:shemaId]
        && TLTransientObjectDescriptor.SCHEMA_VERSION == schemaVersion) {
        TLTransientObjectDescriptor *transientObjectDescriptor = (TLTransientObjectDescriptor *)[TLTransientObjectDescriptor.SERIALIZER deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        return [[TLConversationServicePushTransientObjectIQ alloc] initWithServiceRequestIQ:serviceRequestIQ transientObjectDescriptor:transientObjectDescriptor];
    }
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLConversationServicePushTransientObjectIQ
//

static const int PUSH_TRANSIENT_OBJECT_SCHEMA_VERSION = 2;
static TLSerializer *PUSH_TRANSIENT_OBJECT_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushTransientObjectIQ"

@implementation TLConversationServicePushTransientObjectIQ

+ (void)initialize {
    
    PUSH_TRANSIENT_OBJECT_SERIALIZER = [[TLConversationServicePushTransientObjectIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_TRANSIENT_OBJECT_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return PUSH_TRANSIENT_OBJECT_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion transientObjectDescriptor:(TLTransientObjectDescriptor *)transientObjectDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d transientObjectDescriptor: %@", LOG_TAG, from, to, requestId, majorVersion, minorVersion, transientObjectDescriptor);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:PUSH_TRANSIENT_OBJECT_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _transientObjectDescriptor = transientObjectDescriptor;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" transientObjectDescriptor: %@\n", self.transientObjectDescriptor];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServicePushTransientObjectIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ transientObjectDescriptor:(TLTransientObjectDescriptor *)transientObjectDescriptor {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ transientObjectDescriptor: %@", LOG_TAG, serviceRequestIQ, transientObjectDescriptor);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _transientObjectDescriptor = transientObjectDescriptor;
    }
    return self;
}

@end

#pragma mark - TLConversationServicePushFileIQ

/**
 * <pre>
 *
 * Schema version 6
 *  Date: 2019/03/19
 *
 * {
 *  "schemaId":"8359efba-fb7e-4378-a054-c4a9e2d37f8f",
 *  "schemaVersion":"6",
 *
 *  "type":"record",
 *  "name":"PushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"fileDescriptor",
 *    [
 *     "type":"org.twinlife.schemas.conversation.FileDescriptor",      // V3
 *     "type":"org.twinlife.schemas.conversation.ImageDescriptor",     // V3
 *     "type":"org.twinlife.schemas.conversation.AudioDescriptor",     // V2
 *     "type":"org.twinlife.schemas.conversation.VideoDescriptor"      // V2
 *     "type":"org.twinlife.schemas.conversation.NamedFileDescriptor", // V2
 *    ]
 *   }
 *  ]
 * }
 *
 * Schema version 5
 *  Date: 2018/09/17
 *
 * {
 *  "schemaId":"8359efba-fb7e-4378-a054-c4a9e2d37f8f",
 *  "schemaVersion":"5",
 *
 *  "type":"record",
 *  "name":"PushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"fileDescriptor",
 *    [
 *     "type":"org.twinlife.schemas.conversation.FileDescriptor.2",
 *     "type":"org.twinlife.schemas.conversation.ImageDescriptor.2",
 *     "type":"org.twinlife.schemas.conversation.AudioDescriptor.1",
 *     "type":"org.twinlife.schemas.conversation.VideoDescriptor.1"
 *     "type":"org.twinlife.schemas.conversation.NamedFileDescriptor.1",
 *    ]
 *   }
 *  ]
 * }
 *
 *
 * Schema version 4
 *  Date: 2017/01/26
 *
 * {
 *  "schemaId":"8359efba-fb7e-4378-a054-c4a9e2d37f8f",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"PushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"fileDescriptor",
 *    [
 *     "type":"org.twinlife.schemas.conversation.FileDescriptor.2",
 *     "type":"org.twinlife.schemas.conversation.ImageDescriptor.2",
 *     "type":"org.twinlife.schemas.conversation.AudioDescriptor.1",
 *     "type":"org.twinlife.schemas.conversation.VideoDescriptor.1"
 *    ]
 *   }
 *  ]
 * }
 *
 * Schema version 3
 *  Date: 2017/01/26
 *
 * {
 *  "schemaId":"8359efba-fb7e-4378-a054-c4a9e2d37f8f",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"PushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"fileDescriptor",
 *    [
 *     "type":"org.twinlife.schemas.conversation.FileDescriptor.2",
 *     "type":"org.twinlife.schemas.conversation.ImageDescriptor.2",
 *     "type":"org.twinlife.schemas.conversation.AudioDescriptor.1"
 *    ]
 *   }
 *  ]
 * }
 *
 * Schema version 2
 *  Date: 2016/12/29
 *
 * {
 *  "schemaId":"8359efba-fb7e-4378-a054-c4a9e2d37f8f",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"PushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"fileDescriptor",
 *    [
 *     "type":"org.twinlife.schemas.conversation.FileDescriptor.2",
 *     "type":"org.twinlife.schemas.conversation.ImageDescriptor.2"
 *    ]
 *   }
 *  ]
 * }
 *
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"8359efba-fb7e-4378-a054-c4a9e2d37f8f",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {
 *    "name":"fileDescriptor",
 *    [
 *     "type":"org.twinlife.schemas.conversation.FileDescriptor.1",
 *     "type":"org.twinlife.schemas.conversation.ImageDescriptor.1"
 *    ]
 *   }
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLConversationServicePushFileIQ ()
//

@interface TLConversationServicePushFileIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ fileDescriptor:(TLFileDescriptor *)fileDescriptor;

@end

//
// Implementation: TLConversationServicePushFileIQSerializer
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushFileIQSerializer"

@implementation TLConversationServicePushFileIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLPushFileIQ.SCHEMA_ID schemaVersion:TLConversationServicePushFileIQ.SCHEMA_VERSION class:[TLConversationServicePushFileIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServicePushFileIQ *pushFileIQ = (TLConversationServicePushFileIQ *)object;
    TLFileDescriptor *fileDescriptor = pushFileIQ.fileDescriptor;
    switch ([fileDescriptor getType]) {
        case TLDescriptorTypeFileDescriptor:
            [encoder writeEnum:0];
            [TLFileDescriptor.SERIALIZER_3 serializeWithSerializerFactory:serializerFactory encoder:encoder object:fileDescriptor];
            break;
            
        case TLDescriptorTypeImageDescriptor:
            [encoder writeEnum:1];
            [TLImageDescriptor.SERIALIZER_3 serializeWithSerializerFactory:serializerFactory encoder:encoder object:fileDescriptor];
            break;
            
        case TLDescriptorTypeAudioDescriptor:
            [encoder writeEnum:2];
            [TLAudioDescriptor.SERIALIZER_2 serializeWithSerializerFactory:serializerFactory encoder:encoder object:fileDescriptor];
            break;
            
        case TLDescriptorTypeVideoDescriptor:
            [encoder writeEnum:3];
            [TLVideoDescriptor.SERIALIZER_2 serializeWithSerializerFactory:serializerFactory encoder:encoder object:fileDescriptor];
            break;
            
        case TLDescriptorTypeNamedFileDescriptor:
            [encoder writeEnum:4];
            [TLNamedFileDescriptor.SERIALIZER_2 serializeWithSerializerFactory:serializerFactory encoder:encoder object:fileDescriptor];
            break;
            
        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
            break;
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int position = [decoder readEnum];
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    switch (position) {
        case 0:
            if ([TLFileDescriptor.SCHEMA_ID isEqual:schemaId] && TLFileDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[TLFileDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
                return [[TLConversationServicePushFileIQ alloc] initWithServiceRequestIQ:serviceRequestIQ fileDescriptor:fileDescriptor];
            }
            break;
            
        case 1:
            if ([TLImageDescriptor.SCHEMA_ID isEqual:schemaId] && TLImageDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                TLImageDescriptor *imageDescriptor = (TLImageDescriptor *)[TLImageDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
                return [[TLConversationServicePushFileIQ alloc] initWithServiceRequestIQ:serviceRequestIQ fileDescriptor:imageDescriptor];
            }
            break;
            
        case 2:
            if ([TLAudioDescriptor.SCHEMA_ID isEqual:schemaId] && TLAudioDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                TLAudioDescriptor *audioDescriptor = (TLAudioDescriptor *)[TLAudioDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
                return [[TLConversationServicePushFileIQ alloc] initWithServiceRequestIQ:serviceRequestIQ fileDescriptor:audioDescriptor];
            }
            break;
            
        case 3:
            if ([TLVideoDescriptor.SCHEMA_ID isEqual:schemaId] && TLVideoDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                TLVideoDescriptor *videoDescriptor = (TLVideoDescriptor *)[TLVideoDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
                return [[TLConversationServicePushFileIQ alloc] initWithServiceRequestIQ:serviceRequestIQ fileDescriptor:videoDescriptor];
            }
            break;
            
        case 4:
            if ([TLNamedFileDescriptor.SCHEMA_ID isEqual:schemaId] && TLNamedFileDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                TLNamedFileDescriptor *namedFileDescriptor = (TLNamedFileDescriptor *)[TLNamedFileDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
                return [[TLConversationServicePushFileIQ alloc] initWithServiceRequestIQ:serviceRequestIQ fileDescriptor:namedFileDescriptor];
            }
            break;
            
        default:
            break;
    }
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLConversationServicePushFileIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushFileIQ"

static const int PUSH_FILE_SCHEMA_VERSION = 6;
static TLSerializer *PUSH_FILE_SERIALIZER = nil;

@implementation TLConversationServicePushFileIQ

+ (void)initialize {
    
    PUSH_FILE_SERIALIZER = [[TLConversationServicePushFileIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_FILE_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return PUSH_FILE_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion fileDescriptor:(TLFileDescriptor *)fileDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d fileDescriptor: %@", LOG_TAG, from, to, requestId, majorVersion, minorVersion, fileDescriptor);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:PUSH_FILE_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _fileDescriptor = fileDescriptor;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {

    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    if (self.majorVersion == TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 && self.minorVersion >= CONVERSATION_SERVICE_MINOR_VERSION_9) {
        [[TLConversationServicePushFileIQ SERIALIZER] serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    } else {
        @throw [TLUnsupportedException exceptionWithName:@"TLEncoderException" reason:@"Need 2.9 version at least" userInfo:nil];
    }

    return data;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" fileDescriptor: %@\n", self.fileDescriptor];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServicePushFileIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ fileDescriptor:(TLFileDescriptor *)fileDescriptor {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ fileDescriptor: %@", LOG_TAG, serviceRequestIQ, fileDescriptor);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _fileDescriptor = fileDescriptor;
    }
    return self;
}

@end

#pragma mark - TLConversationServiceOnPushFileIQ

/**
 * <pre>
 *
 * Schema version
 *  Date: 2016/09/08
 *
 * {
 *  "schemaId":"3d4e8b77-bca3-477d-a949-5ec4f36e01a3",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  [
 *   {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLConversationServiceOnPushFileIQ ()
//

@interface TLConversationServiceOnPushFileIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp;

@end

//
// Implementation: TLConversationServiceOnPushFileIQSerializer
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushFileIQSerializer"

@implementation TLConversationServiceOnPushFileIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLOnPushFileIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnPushFileIQ.SCHEMA_VERSION class:[TLConversationServiceOnPushFileIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServiceOnPushFileIQ *onPushFile = (TLConversationServiceOnPushFileIQ *)object;
    [encoder writeLong:onPushFile.receivedTimestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceResultIQ *serviceResutIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t receivedTimestamp = [decoder readLong];
    return [[TLConversationServiceOnPushFileIQ alloc]initWithServiceResultIQ:serviceResutIQ receivedTimestamp:receivedTimestamp];
}

@end

//
// Implementation: TLConversationServiceOnPushFileIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushFileIQ"

static const int ON_PUSH_FILE_SCHEMA_VERSION = 1;
static TLSerializer *ON_PUSH_FILE_SERIALIZER = nil;

@implementation TLConversationServiceOnPushFileIQ

+ (void)initialize {
    
    ON_PUSH_FILE_SERIALIZER = [[TLConversationServiceOnPushFileIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_PUSH_FILE_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_PUSH_FILE_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d receivedTimestamp: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, receivedTimestamp);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:ON_PUSH_FILE_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" receivedTimestamp: %lld\n", self.receivedTimestamp];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnPushFileIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ initWithServiceResultIQ: %@ receivedTimestamp: %lld", LOG_TAG, serviceResultIQ, receivedTimestamp);
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
    }
    return self;
}

@end

#pragma mark - TLConversationServicePushFileChunkIQ

/**
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"ae5192f5-f505-4211-84c5-76cb5bf9b147",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushFileChunkIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {"name":"twincodeOutboundId", "type":"uuid"}
 *   {"name":"sequenceId", "type":"long"}
 *   {"name":"chunkStart", "type":"long"}
 *   {"name":"chunk", "type":"bytes"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLConversationServicePushFileChunkIQ ()
//

@interface TLConversationServicePushFileChunkIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ descriptorId:(TLDescriptorId *)descriptorId chunkStart:(int64_t)chunkStart chunk:(NSData *)chunk;

@end

//
// Implementation: TLConversationServicePushFileChunkIQSerializer
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushFileChunkIQSerializer"

@implementation TLConversationServicePushFileChunkIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLPushFileChunkIQ.SCHEMA_ID schemaVersion:TLConversationServicePushFileChunkIQ.SCHEMA_VERSION class:[TLConversationServicePushFileChunkIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServicePushFileChunkIQ *pushChunkFileIQ = (TLConversationServicePushFileChunkIQ *)object;
    [encoder writeUUID:pushChunkFileIQ.descriptorId.twincodeOutboundId];
    [encoder writeLong:pushChunkFileIQ.descriptorId.sequenceId];
    [encoder writeLong:pushChunkFileIQ.chunkStart];
    [encoder writeData:pushChunkFileIQ.chunk];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    int64_t chunkStart = [decoder readLong];
    NSData *chunk = [decoder readData];
    return [[TLConversationServicePushFileChunkIQ alloc]initWithServiceRequestIQ:serviceRequestIQ descriptorId:[[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId] chunkStart:chunkStart chunk:chunk];
}

@end

//
// Implementation: TLConversationServicePushFileChunkIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServicePushFileChunkIQ"

static const int PUSH_FILE_CHUNK_SCHEMA_VERSION = 1;
static TLSerializer *PUSH_FILE_CHUNK_SERIALIZER = nil;

@implementation TLConversationServicePushFileChunkIQ

+ (void)initialize {
    
    PUSH_FILE_CHUNK_SERIALIZER = [[TLConversationServicePushFileChunkIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_FILE_CHUNK_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return PUSH_FILE_CHUNK_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId descriptorId:(TLDescriptorId *)descriptorId majorVersion:(int)majorVersion minorVersion:(int)minorVersion chunkStart:(int64_t)chunkStart chunk:(NSData *)chunk {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld descriptorId: %@ majorVersion: %d minorVersion: %d chunkStart: %lld chunk: %@", LOG_TAG, from, to, requestId, descriptorId, majorVersion, minorVersion, chunkStart, chunk);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:PUSH_FILE_CHUNK_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _descriptorId = descriptorId;
        _chunkStart = chunkStart;
        _chunk = chunk;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" descriptorId:       %@\n", self.descriptorId];
    [string appendFormat:@" chunkStart:         %lld\n", self.chunkStart];
    [string appendFormat:@" chunk:              %@\n", self.chunk];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServicePushFileChunkIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ descriptorId:(TLDescriptorId *)descriptorId chunkStart:(int64_t)chunkStart chunk:(NSData *)chunk {
    DDLogVerbose(@"%@ initWithServiceRequestIQ: %@ descriptorId: %@ chunkStart: %lld chunk: %@", LOG_TAG, serviceRequestIQ, descriptorId, chunkStart, chunk);
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _descriptorId = descriptorId;
        _chunkStart = chunkStart;
        _chunk = chunk;
    }
    return self;
}

@end

#pragma mark - TLConversationServiceOnPushFileChunkIQ

/**
 * <pre>
 *
 * Schema version
 *  Date: 2016/09/08
 *
 * {
 *  "schemaId":"af9e04d2-88c5-4054-8707-ad5f06ce9fc4",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPushFileChunkIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  [
 *   {"name":"receivedTimestamp", "type":"long"}
 *   {"name":"nextChunkStart", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLConversationServiceOnPushFileChunkIQ ()
//

@interface TLConversationServiceOnPushFileChunkIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp nextChunkStart:(int64_t)nextChunkStart;

@end

//
// Implementation: TLConversationServiceOnPushFileChunkIQSerializer
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushFileChunkIQSerializer"

@implementation TLConversationServiceOnPushFileChunkIQSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLOnPushFileChunkIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnPushFileChunkIQ.SCHEMA_VERSION class:[TLConversationServiceOnPushFileChunkIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLConversationServiceOnPushFileChunkIQ *onPushFileChunkIQ = (TLConversationServiceOnPushFileChunkIQ *)object;
    [encoder writeLong:onPushFileChunkIQ.receivedTimestamp];
    [encoder writeLong:onPushFileChunkIQ.nextChunkStart];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLServiceResultIQ *serviceResutIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t receivedTimestamp = [decoder readLong];
    int64_t nextChunkStart = [decoder readLong];
    return [[TLConversationServiceOnPushFileChunkIQ alloc]initWithServiceResultIQ:serviceResutIQ receivedTimestamp:receivedTimestamp nextChunkStart:nextChunkStart];
}

@end

//
// Implementation: TLConversationServiceOnPushFileChunkIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnPushFileChunkIQ"

static const int ON_PUSH_FILE_CHUNK_SCHEMA_VERSION = 1;
static TLSerializer *ON_PUSH_FILE_CHUNK_SERIALIZER = nil;

@implementation TLConversationServiceOnPushFileChunkIQ

+ (void)initialize {
    
    ON_PUSH_FILE_CHUNK_SERIALIZER = [[TLConversationServiceOnPushFileChunkIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_PUSH_FILE_CHUNK_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_PUSH_FILE_CHUNK_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp nextChunkStart:(int64_t)nextChunkStart {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d receivedTimestamp: %lld nextChunkStart: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, receivedTimestamp, nextChunkStart);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:ON_PUSH_FILE_CHUNK_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
        _nextChunkStart = nextChunkStart;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" receivedTimestamp: %lld\n", self.receivedTimestamp];
    [string appendFormat:@" nextChunkStart:    %lld\n", self.nextChunkStart];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnPushFileChunkIQ\n"];
    [self appendTo:string];
    return string;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ receivedTimestamp:(int64_t)receivedTimestamp nextChunkStart:(int64_t)nextChunkStart {
    DDLogVerbose(@"%@ initWithServiceResultIQ: %@ receivedTimestamp: %lld nextChunkStart: %lld", LOG_TAG, serviceResultIQ, receivedTimestamp, nextChunkStart);
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    
    if (self) {
        _receivedTimestamp = receivedTimestamp;
        _nextChunkStart = nextChunkStart;
    }
    return self;
}

@end

#pragma mark - TLUpdateDescriptorTimestampIQ

/**
 * <pre>
 *
 * Schema version 1
 *  Date: 2017/01/13
 *
 * {
 *  "type":"enum",
 *  "name":"UpdateDescriptorTimestampType",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "symbols" : ["READ", "DELETE", "PEER_DELETE"]
 * }
 *
 * {
 *  "schemaId":"b814c454-299b-48c0-aa40-19afa72ccef8",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateDescriptorTimestampIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {"name":"type", "type":"org.twinlife.schemas.conversation.UpdateDescriptorTimestampType"}
 *   {"name":"twincodeOutboundId", "type":"UUID"},
 *   {"name":"sequenceId", "type":"long"}
 *   {"name":"timestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface : TLUpdateDescriptorTimestampIQ
//

@interface TLUpdateDescriptorTimestampIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ type:(TLUpdateDescriptorTimestampType)type descriptorId:(TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp;

@end

//
// Implementation : TLUpdateDescriptorTimestampIQSerializer
//

@implementation TLUpdateDescriptorTimestampIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLUpdateTimestampIQ.SCHEMA_ID schemaVersion:TLUpdateDescriptorTimestampIQ.SCHEMA_VERSION class:[TLUpdateDescriptorTimestampIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
    
    TLUpdateDescriptorTimestampIQ * updateDescriptorTimestampIQ = (TLUpdateDescriptorTimestampIQ*)object;
    switch (updateDescriptorTimestampIQ.timestampType) {
        case TLUpdateDescriptorTimestampTypeRead:
            [encoder writeEnum:0];
            break;
            
        case TLUpdateDescriptorTimestampTypeDelete:
            [encoder writeEnum:1];
            break;
            
        case TLUpdateDescriptorTimestampTypePeerDelete:
            [encoder writeEnum:2];
            break;
            
        default:
            break;
    }
    [encoder writeUUID:updateDescriptorTimestampIQ.descriptorId.twincodeOutboundId];
    [encoder writeLong:updateDescriptorTimestampIQ.descriptorId.sequenceId];
    [encoder writeLong:updateDescriptorTimestampIQ.timestamp];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    TLUpdateDescriptorTimestampType timestampType;
    int value = [decoder readEnum];
    switch (value) {
        case 0:
            timestampType = TLUpdateDescriptorTimestampTypeRead;
            break;
        case 1:
            timestampType = TLUpdateDescriptorTimestampTypeDelete;
            break;
        case 2:
            timestampType = TLUpdateDescriptorTimestampTypePeerDelete;
            break;
            
        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
            break;
    }
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    int64_t timestamp = [decoder readLong];
    return [[TLUpdateDescriptorTimestampIQ alloc] initWithServiceRequestIQ:serviceRequestIQ type:timestampType descriptorId:[[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId] timestamp:timestamp];
}

@end

//
// Implementation : TLUpdateDescriptorTimestampIQ
//

static const int UPDATE_DESCRIPTOR_TIMESTAMP_SCHEMA_VERSION = 1;
static TLSerializer *UPDATE_DESCRIPTOR_TIMESTAMP_SERIALIZER = nil;

@implementation TLUpdateDescriptorTimestampIQ

+ (void)initialize {
    
    UPDATE_DESCRIPTOR_TIMESTAMP_SERIALIZER = [[TLUpdateDescriptorTimestampIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return UPDATE_DESCRIPTOR_TIMESTAMP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return UPDATE_DESCRIPTOR_TIMESTAMP_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion timestampType:(TLUpdateDescriptorTimestampType)timestampType descriptorId:(TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp {
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:UPDATE_DESCRIPTOR_TIMESTAMP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    
    if (self) {
        _timestampType = timestampType;
        _descriptorId = descriptorId;
        _timestamp = timestamp;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" timestampType:      %u\n", self.timestampType];
    [string appendFormat:@" descriptorId:       %@\n", self.descriptorId];
    [string appendFormat:@" timestamp:          %lld\n", self.timestamp];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"UpdateDescriptorTimestampIQ\n"];
    [self appendTo:string];
    return string;
}

//
// Private Methods
//

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ type:(TLUpdateDescriptorTimestampType)type descriptorId:(TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp {
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _timestampType = type;
        _descriptorId = descriptorId;
        _timestamp = timestamp;
    }
    return self;
}

@end

#pragma mark - TLOnUpdateDescriptorTimestampIQ

/**
 * <pre>
 *
 * Schema version 1
 *  Date: 2017/01/13
 *
 * {
 *  "schemaId":"87d33c5f-9b9b-49bf-a802-8bd24fb021a6",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnUpdateDescriptorTimestampIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  []
 * }
 *
 * </pre>
 */

//
// Interface : TLOnUpdateDescriptorTimestampIQ
//

@interface TLOnUpdateDescriptorTimestampIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ;

@end

//
// Implementation : TLOnUpdateDescriptorTimestampIQSerializer
//

@implementation TLOnUpdateDescriptorTimestampIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLOnUpdateTimestampIQ.SCHEMA_ID schemaVersion:TLOnUpdateDescriptorTimestampIQ.SCHEMA_VERSION class:[TLOnUpdateDescriptorTimestampIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    return [[TLOnUpdateDescriptorTimestampIQ alloc] initWithServiceResultIQ:serviceResultIQ];
}

@end

//
// Implementation : TLOnUpdateDescriptorTimestampIQ
//

static const int ON_UPDATE_DESCRIPTOR_TIMESTAMP_SCHEMA_VERSION = 1;
static TLSerializer *ON_UPDATE_DESCRIPTOR_TIMESTAMP_SERIALIZER = nil;

@implementation TLOnUpdateDescriptorTimestampIQ

+ (void)initialize {
    
    ON_UPDATE_DESCRIPTOR_TIMESTAMP_SERIALIZER = [[TLOnUpdateDescriptorTimestampIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_UPDATE_DESCRIPTOR_TIMESTAMP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_UPDATE_DESCRIPTOR_TIMESTAMP_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    return [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:ON_UPDATE_DESCRIPTOR_TIMESTAMP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLOnUpdateDescriptorTimestampIQ\n"];
    [self appendTo:string];
    return string;
}

//
// Private Methods
//

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ {
    
    return [super initWithServiceResultIQ:serviceResultIQ];
}

@end

#pragma mark - TLConversationServiceInviteGroupIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/05/30
 *
 * {
 *  "schemaId":"55e698ff-b429-425f-bcaa-0b21d4620621",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"InviteGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":[
 *   {
 *    "name":"invitationDescriptor",
 *    "type":"org.twinlife.schemas.conversation.InvitationDescriptor"
 *   }
 * }
 * </pre>
 */

//
// Interface: TLConversationServiceInviteGroupIQ ()
//

@interface TLConversationServiceInviteGroupIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor;

@end

//
// Implementation : TLConversationServiceInviteGroupIQSerializer
//

@implementation TLConversationServiceInviteGroupIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLInviteGroupIQ.SCHEMA_ID schemaVersion:TLConversationServiceInviteGroupIQ.SCHEMA_VERSION class:[TLConversationServiceInviteGroupIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
    
    TLConversationServiceInviteGroupIQ * inviteGroupIQ = (TLConversationServiceInviteGroupIQ*)object;
    [TLInvitationDescriptor.SERIALIZER_1 serializeWithSerializerFactory:serializerFactory encoder:encoder object:inviteGroupIQ.invitationDescriptor];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int version = [decoder readInt];
    if ([TLInvitationDescriptor.SCHEMA_ID isEqual:schemaId] && TLInvitationDescriptor.SCHEMA_VERSION_1 == version) {
        TLInvitationDescriptor *invitationDescriptor = (TLInvitationDescriptor *)[TLInvitationDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        
        return [[TLConversationServiceInviteGroupIQ alloc] initWithServiceRequestIQ:serviceRequestIQ invitationDescriptor:invitationDescriptor];
    } else {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
}

@end

//
// Implementation: TLConversationServiceInviteGroupIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceInviteGroupIQ"

static const int INVITE_GROUP_SCHEMA_VERSION = 1;
static TLSerializer *INVITE_GROUP_SERIALIZER = nil;

@implementation TLConversationServiceInviteGroupIQ

+ (void)initialize {
    
    INVITE_GROUP_SERIALIZER = [[TLConversationServiceInviteGroupIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return INVITE_GROUP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return INVITE_GROUP_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d", LOG_TAG, from, to, requestId, majorVersion, minorVersion);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:INVITE_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _invitationDescriptor = invitationDescriptor;
    }
    return self;
}

//
// Private Methods
//

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _invitationDescriptor = invitationDescriptor;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GROUP_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.6 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [INVITE_GROUP_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];

    return data;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceInviteGroupIQ\n"];
    [self appendTo:string];
    return string;
}

@end

#pragma mark - TLConversationServiceRevokeInviteGroupIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/07/26
 *
 * {
 *  "schemaId":"f04f5123-b42d-456b-ac5c-45af7b26e6a0",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"RevokeInviteGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":[
 *   {
 *    "name":"invitationDescriptor",
 *    "type":"org.twinlife.schemas.conversation.InvitationDescriptor"
 *   }
 * }
 * </pre>
 */

//
// Interface: TLConversationServiceRevokeInviteGroupIQ ()
//

@interface TLConversationServiceRevokeInviteGroupIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor;

@end

//
// Implementation : TLConversationServiceRevokeInviteGroupIQSerializer
//

@implementation TLConversationServiceRevokeInviteGroupIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLConversationServiceRevokeInviteGroupIQ.SCHEMA_ID schemaVersion:TLConversationServiceRevokeInviteGroupIQ.SCHEMA_VERSION class:[TLConversationServiceRevokeInviteGroupIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
    
    TLConversationServiceRevokeInviteGroupIQ *revokeInviteGroupIQ = (TLConversationServiceRevokeInviteGroupIQ*)object;
    [TLInvitationDescriptor.SERIALIZER_1 serializeWithSerializerFactory:serializerFactory encoder:encoder object:revokeInviteGroupIQ.invitationDescriptor];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int version = [decoder readInt];
    if ([TLInvitationDescriptor.SCHEMA_ID isEqual:schemaId] && TLInvitationDescriptor.SCHEMA_VERSION_1 == version) {
        TLInvitationDescriptor *invitationDescriptor = (TLInvitationDescriptor *)[TLInvitationDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        
        return [[TLConversationServiceRevokeInviteGroupIQ alloc] initWithServiceRequestIQ:serviceRequestIQ invitationDescriptor:invitationDescriptor];
    } else {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
}

@end

//
// Implementation: TLConversationServiceRevokeInviteGroupIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceRevokeInviteGroupIQ"

static NSUUID *REVOKE_INVITE_GROUP_SCHEMA_ID = nil;
static const int REVOKE_INVITE_GROUP_SCHEMA_VERSION = 1;
static TLSerializer *REVOKE_INVITE_GROUP_SERIALIZER = nil;

@implementation TLConversationServiceRevokeInviteGroupIQ

+ (void)initialize {
    
    REVOKE_INVITE_GROUP_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"f04f5123-b42d-456b-ac5c-45af7b26e6a0"];
    REVOKE_INVITE_GROUP_SERIALIZER = [[TLConversationServiceRevokeInviteGroupIQSerializer alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return REVOKE_INVITE_GROUP_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return REVOKE_INVITE_GROUP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return REVOKE_INVITE_GROUP_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d", LOG_TAG, from, to, requestId, majorVersion, minorVersion);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:REVOKE_INVITE_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _invitationDescriptor = invitationDescriptor;
    }
    return self;
}

//
// Private Methods
//

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _invitationDescriptor = invitationDescriptor;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GROUP_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.6 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [REVOKE_INVITE_GROUP_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceRevokeInviteGroupIQ\n"];
    [self appendTo:string];
    return string;
}

@end

#pragma mark - TLConversationServiceJoinGroupIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/05/30
 *
 * {
 *  "schemaId":"c1315d7f-bf10-4cec-811b-84c44302e7bd",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"JoinGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   [
 *    {"type":"record",
 *     "fields":
 *     [
 *      {"name":"groupTwincodeId", "type":"uuid"},
 *      {"name":"memberTwincodeId", "type":"uuid"},
 *      {"name":"permissions", "type":"uuid"}
 *     ]
 *    },
 *    {"name":"invitationDescriptor", "type":"org.twinlife.schemas.conversation.InvitationDescriptor"}
 *   ]
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServiceJoinGroupIQ ()
//

@interface TLConversationServiceJoinGroupIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor;

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

@end

//
// Implementation : TLConversationServiceJoinGroupIQSerializer
//

@implementation TLConversationServiceJoinGroupIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLJoinGroupIQ.SCHEMA_ID schemaVersion:TLConversationServiceJoinGroupIQ.SCHEMA_VERSION class:[TLConversationServiceJoinGroupIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
    
    TLConversationServiceJoinGroupIQ *joinGroupIQ = (TLConversationServiceJoinGroupIQ*)object;
    if (joinGroupIQ.invitationDescriptor) {
        [encoder writeInt:1];
        [TLInvitationDescriptor.SERIALIZER_1 serializeWithSerializerFactory:serializerFactory encoder:encoder object:joinGroupIQ.invitationDescriptor];
    } else {
        [encoder writeInt:0];
        [encoder writeUUID:joinGroupIQ.groupTwincodeId];
        [encoder writeUUID:joinGroupIQ.memberTwincodeId];
        [encoder writeLong:joinGroupIQ.permissions];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int mode = [decoder readInt];
    if (mode == 1) {
        NSUUID *schemaId = [decoder readUUID];
        int version = [decoder readInt];
        if ([TLInvitationDescriptor.SCHEMA_ID isEqual:schemaId] && TLInvitationDescriptor.SCHEMA_VERSION_1 == version) {
            TLInvitationDescriptor *invitationDescriptor = (TLInvitationDescriptor *)[TLInvitationDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:decoder];
        
            return [[TLConversationServiceJoinGroupIQ alloc] initWithServiceRequestIQ:serviceRequestIQ invitationDescriptor:invitationDescriptor];
        } else {
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
        }
    } else if (mode == 0) {
        NSUUID *groupTwincodeId = [decoder readUUID];
        NSUUID *memberTwincodeId = [decoder readUUID];
        int64_t permissions = [decoder readLong];
        return [[TLConversationServiceJoinGroupIQ alloc] initWithServiceRequestIQ:serviceRequestIQ groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId permissions:permissions];
    } else {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
}

@end

//
// Implementation: TLConversationServiceJoinGroupIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceJoinGroupIQ"

static const int JOIN_GROUP_SCHEMA_VERSION = 1;
static TLSerializer *JOIN_GROUP_SERIALIZER = nil;

@implementation TLConversationServiceJoinGroupIQ

+ (void)initialize {
    
    JOIN_GROUP_SERIALIZER = [[TLConversationServiceJoinGroupIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return JOIN_GROUP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return JOIN_GROUP_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d", LOG_TAG, from, to, requestId, majorVersion, minorVersion);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:JOIN_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _invitationDescriptor = invitationDescriptor;
        _groupTwincodeId = invitationDescriptor.groupTwincodeId;
        _memberTwincodeId = invitationDescriptor.memberTwincodeId;
        _permissions = 0;
    }
    return self;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d groupTwincodeId: %@ memberTwincodeId: %@ permissions: %lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, groupTwincodeId, memberTwincodeId, permissions);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:JOIN_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _invitationDescriptor = nil;
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _permissions = permissions;
    }
    return self;
}

//
// Private Methods
//

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _invitationDescriptor = invitationDescriptor;
        _groupTwincodeId = invitationDescriptor.groupTwincodeId;
        _memberTwincodeId = invitationDescriptor.memberTwincodeId;
        _permissions = 0;
    }
    return self;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions {
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _invitationDescriptor = nil;
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _permissions = permissions;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GROUP_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.6 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [JOIN_GROUP_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceJoinGroupIQ\n"];
    [self appendTo:string];
    return string;
}

@end

#pragma mark - TLConversationServiceLeaveGroupIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/06/25
 *
 * {
 *  "schemaId":"fae66d0a-ce05-423d-b5fa-6019b24ea924",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"LeaveGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {"name":"group", "type":"uuid"},
 *   {"name":"member", "type":"uuid"}
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServiceLeaveGroupIQ ()
//

@interface TLConversationServiceLeaveGroupIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId;

@end

//
// Implementation : TLConversationServiceLeaveGroupIQSerializer
//

@implementation TLConversationServiceLeaveGroupIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLConversationServiceLeaveGroupIQ.SCHEMA_ID schemaVersion:TLConversationServiceLeaveGroupIQ.SCHEMA_VERSION class:[TLConversationServiceLeaveGroupIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
    
    TLConversationServiceLeaveGroupIQ *leaveGroupIQ = (TLConversationServiceLeaveGroupIQ*)object;
    [encoder writeUUID:leaveGroupIQ.groupTwincodeId];
    [encoder writeUUID:leaveGroupIQ.memberTwincodeId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *groupTwincodeId = [decoder readUUID];
    NSUUID *memberTwincodeId = [decoder readUUID];
    return [[TLConversationServiceLeaveGroupIQ alloc] initWithServiceRequestIQ:serviceRequestIQ groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
}

@end

//
// Implementation: TLConversationServiceLeaveGroupIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceLeaveGroupIQ"

static NSUUID *LEAVE_GROUP_SCHEMA_ID = nil;
static const int LEAVE_GROUP_SCHEMA_VERSION = 1;
static TLSerializer *LEAVE_GROUP_SERIALIZER = nil;

@implementation TLConversationServiceLeaveGroupIQ

+ (void)initialize {
    
    LEAVE_GROUP_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"fae66d0a-ce05-423d-b5fa-6019b24ea924"];
    LEAVE_GROUP_SERIALIZER = [[TLConversationServiceLeaveGroupIQSerializer alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return LEAVE_GROUP_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return LEAVE_GROUP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return LEAVE_GROUP_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d groupTwincodeId: %@ memberTwincodeId: %@", LOG_TAG, from, to, requestId, majorVersion, minorVersion, groupTwincodeId, memberTwincodeId);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:LEAVE_GROUP_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
    }
    return self;
}

//
// Private Methods
//

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId {
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory withLeadingPadding:(BOOL)withLeadingPadding {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GROUP_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.6 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder;
    if (withLeadingPadding) {
        binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    } else {
        binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
    }
    [LEAVE_GROUP_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceLeaveGroupIQ\n"];
    [self appendTo:string];
    return string;
}

@end

#pragma mark - TLConversationServiceUpdateGroupMemberIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/07/25
 *
 * {
 *  "schemaId":"3b5dc8a2-2679-43f2-badf-ec61c7eed9f0",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateGroupMemberIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceRequestIQ"
 *  "fields":
 *  [
 *   {"name":"group", "type":"uuid"},
 *   {"name":"member", "type":"uuid"},
 *   {"name":"permissions", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServiceUpdateGroupMemberIQ ()
//

@interface TLConversationServiceUpdateGroupMemberIQ ()

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

@end

//
// Implementation : TLConversationServiceUpdateGroupMemberIQSerializer
//

@implementation TLConversationServiceUpdateGroupMemberIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLUpdatePermissionsIQ.SCHEMA_ID schemaVersion:TLConversationServiceUpdateGroupMemberIQ.SCHEMA_VERSION class:[TLConversationServiceUpdateGroupMemberIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
    
    TLConversationServiceUpdateGroupMemberIQ *updateGroupMemberIQ = (TLConversationServiceUpdateGroupMemberIQ*)object;
    [encoder writeUUID:updateGroupMemberIQ.groupTwincodeId];
    [encoder writeUUID:updateGroupMemberIQ.memberTwincodeId];
    [encoder writeLong:updateGroupMemberIQ.permissions];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *groupTwincodeId = [decoder readUUID];
    NSUUID *memberTwincodeId = [decoder readUUID];
    int64_t permissions = [decoder readLong];
    return [[TLConversationServiceUpdateGroupMemberIQ alloc] initWithServiceRequestIQ:serviceRequestIQ groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId permissions:permissions];
}

@end

//
// Implementation: TLConversationServiceUpdateGroupMemberIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceUpdateGroupMemberIQ"

static const int UPDATE_GROUP_MEMBER_SCHEMA_VERSION = 1;
static TLSerializer *UPDATE_GROUP_MEMBER_SERIALIZER = nil;

@implementation TLConversationServiceUpdateGroupMemberIQ

+ (void)initialize {
    
    UPDATE_GROUP_MEMBER_SERIALIZER = [[TLConversationServiceUpdateGroupMemberIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return UPDATE_GROUP_MEMBER_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return UPDATE_GROUP_MEMBER_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions {
    DDLogVerbose(@"%@ initWithFrom %@ to: %@ requestId: %lld majorVersion: %d minorVersion: %d groupTwincodeId: %@ memberTwincodeId: %@ permissions:%lld", LOG_TAG, from, to, requestId, majorVersion, minorVersion, groupTwincodeId, memberTwincodeId, permissions);
    
    self = [super initWithFrom:from to:to requestId:requestId service:TWINLIFE_NAME action:UPDATE_GROUP_MEMBER_ACTION majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _permissions = permissions;
    }
    return self;
}

//
// Private Methods
//

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions {
    
    self = [super initWithServiceRequestIQ:serviceRequestIQ];
    
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _permissions = permissions;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GROUP_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.6 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [UPDATE_GROUP_MEMBER_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceUpdateGroupMemberIQ\n"];
    [self appendTo:string];
    return string;
}

@end

#pragma mark - TLConversationServiceOnResultGroupIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/05/30
 *
 * {
 *  "schemaId":"afa81c21-beb5-4829-a5d0-8816afda602f",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnResultGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":
 *  []
 * }
 * </pre>
 */

//
// Implementation : TLConversationServiceOnResultGroupIQSerializer
//

@implementation TLConversationServiceOnResultGroupIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLOnInviteGroupIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnResultGroupIQ.SCHEMA_VERSION class:[TLConversationServiceOnResultGroupIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    return [[TLConversationServiceOnResultGroupIQ alloc] initWithServiceResultIQ:serviceResultIQ];
}

@end

//
// Implementation: TLConversationServiceOnResultGroupIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnResultGroupIQ"

static const int ON_RESULT_GROUP_SCHEMA_VERSION = 1;
static TLSerializer *ON_RESULT_GROUP_SERIALIZER = nil;

@implementation TLConversationServiceOnResultGroupIQ

+ (void)initialize {
    
    ON_RESULT_GROUP_SERIALIZER = [[TLConversationServiceOnResultGroupIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_RESULT_GROUP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_RESULT_GROUP_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    DDLogVerbose(@"%@ initWithId %@ from: %@ to: %@ requestId: %lld action:%@ majorVersion: %d minorVersion: %d", LOG_TAG, id, from, to, requestId, action, majorVersion, minorVersion);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:action majorVersion:majorVersion minorVersion:minorVersion];
    return self;
}

//
// Private Methods
//

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ {
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory withLeadingPadding:(BOOL)withLeadingPadding {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GROUP_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.6 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder;
    if (withLeadingPadding) {
        binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    } else {
        binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
    }
    [ON_RESULT_GROUP_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnResultGroupIQ\n"];
    [self appendTo:string];
    return string;
}

@end

#pragma mark - TLConversationServiceOnResultJoinGroupIQ

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/09/04
 *
 * {
 *  "schemaId":"3d175317-f1f7-4cd1-abd8-2f538b342e41",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnResultJoinIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.ServiceResultIQ"
 *  "fields":[
 *   {"name":"status", "type":"integer"},
 *   {"name":"permissions", "type":"long"},
 *   {"type":"array","items":
 *    {"type":"record",
 *     "fields":
 *     [
 *      {"name":"member", "type":"UUID"},
 *      {"name":"permissions", "type":"long"}
 *     ]
 *    }
 *   }
 *  ]
 * }
 * </pre>
 */

//
// Interface: TLConversationServiceOnResultJoinGroupIQ ()
//

@interface TLConversationServiceOnResultJoinGroupIQ ()

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ status:(TLInvitationDescriptorStatusType)status permissions:(int64_t)permissions members:(NSMutableArray*)members;

@end

//
// Implementation : TLConversationServiceOnResultJoinGroupIQSerializer
//

@implementation TLConversationServiceOnResultJoinGroupIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLOnJoinGroupIQ.SCHEMA_ID schemaVersion:TLConversationServiceOnResultJoinGroupIQ.SCHEMA_VERSION class:[TLConversationServiceOnResultJoinGroupIQ class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object];
    TLConversationServiceOnResultJoinGroupIQ *onResultJoinGroupIQ = (TLConversationServiceOnResultJoinGroupIQ *)object;
    if (onResultJoinGroupIQ.status == TLInvitationDescriptorStatusTypeJoined) {
        [encoder writeEnum:1];
    } else {
        [encoder writeEnum:0];
    }
    [encoder writeLong:onResultJoinGroupIQ.permissions];
    if (!onResultJoinGroupIQ.members) {
        [encoder writeLong:0];
    } else {
        [encoder writeLong:onResultJoinGroupIQ.members.count];
        for (TLOnJoinGroupMemberInfo *member in onResultJoinGroupIQ.members) {
            [encoder writeUUID:member.memberTwincodeId];
            [encoder writeLong:member.permissions];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
 
    int value = [decoder readEnum];
    int64_t permissions = [decoder readLong];
    int64_t count = [decoder readLong];
    TLInvitationDescriptorStatusType status;
    if (value == 1) {
        status = TLInvitationDescriptorStatusTypeJoined;
    } else {
        status = TLInvitationDescriptorStatusTypeWithdrawn;
    }
    NSMutableArray<TLOnJoinGroupMemberInfo*> *members = nil;
    if (count > 0) {
        members = [[NSMutableArray alloc] initWithCapacity:(int)count];
        while (count > 0) {
            NSUUID *member = [decoder readUUID];
            int64_t permissions = [decoder readLong];
        
            [members addObject:[[TLOnJoinGroupMemberInfo alloc] initWithTwincodeId:member publicKey:nil permissions:permissions]];
            count--;
        }
    }

    return [[TLConversationServiceOnResultJoinGroupIQ alloc] initWithServiceResultIQ:serviceResultIQ status:status permissions:permissions members:members];
}

@end

//
// Implementation: TLConversationServiceOnResultJoinGroupIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationServiceOnResultJoinGroupIQ"

static const int ON_RESULT_JOIN_GROUP_SCHEMA_VERSION = 1;
static TLSerializer *ON_RESULT_JOIN_GROUP_SERIALIZER = nil;

@implementation TLConversationServiceOnResultJoinGroupIQ

+ (void)initialize {
    
    ON_RESULT_JOIN_GROUP_SERIALIZER = [[TLConversationServiceOnResultJoinGroupIQSerializer alloc] init];
}

+ (int)SCHEMA_VERSION {
    
    return ON_RESULT_JOIN_GROUP_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ON_RESULT_JOIN_GROUP_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion status:(TLInvitationDescriptorStatusType)status permissions:(int64_t)permissions members:(NSArray <TLOnJoinGroupMemberInfo *>*)members {
    DDLogVerbose(@"%@ initWithId %@ from: %@ to: %@ requestId: %lld action:%@ majorVersion: %d minorVersion: %d status: %d permissions: %lld", LOG_TAG, id, from, to, requestId, action, majorVersion, minorVersion, status, permissions);
    
    self = [super initWithId:id from:from to:to requestId:requestId service:TWINLIFE_NAME action:action majorVersion:majorVersion minorVersion:minorVersion];
    if (self) {
        _status = status;
        _permissions = permissions;
        _members = members;
    }
    return self;
}

//
// Private Methods
//

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ status:(TLInvitationDescriptorStatusType)status permissions:(int64_t)permissions members:(NSMutableArray*)members {
    
    self = [super initWithServiceResultIQ:serviceResultIQ];
    if (self) {
        _status = status;
        _permissions = permissions;
        _members = members;
    }
    return self;
}

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory {
    
    if (self.majorVersion != TLConversationService.CONVERSATION_SERVICE_MAJOR_VERSION_2 || self.minorVersion < TLConversationService.CONVERSATION_SERVICE_GROUP_MINOR_VERSION) {
        @throw [TLUnsupportedException exceptionWithName:@"TLDecoderException" reason:@"Need 2.6 version at least" userInfo:nil];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
    [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    
    [ON_RESULT_JOIN_GROUP_SERIALIZER serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    
    return data;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOnResultJoinGroupIQ\n"];
    [self appendTo:string];
    return string;
}

@end

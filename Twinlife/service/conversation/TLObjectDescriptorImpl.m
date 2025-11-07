/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLObjectDescriptorImpl.h"
#import "TLConversationService.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"

/**
 * <pre>
 *
 * Schema version 5
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"9239451b-0193-4703-b98e-a487115e433a",
 *  "schemaVersion":"5",
 *
 *  "type":"record",
 *  "name":"ObjectDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor.4"
 *  "fields":
 *  [
 *   {"name":"object", "type":"Object"}
 *   {"name":"copyAllowed", "type":"boolean"}
 *  ]
 * }
 * *
 * Schema version 4
 *  Date: 2019/03/19
 *
 * {
 *  "schemaId":"9239451b-0193-4703-b98e-a487115e433a",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"ObjectDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"object", "type":"Object"}
 *   {"name":"copyAllowed", "type":"boolean"}
 *  ]
 * }
 *
 * Schema version 3
 *  Date: 2016/12/29
 *
 * {
 *  "schemaId":"9239451b-0193-4703-b98e-a487115e433a",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ObjectDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"object", "type":"Object"}
 *  ]
 * }
 * </pre>
 */

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLObjectDescriptorSerializer
//
static NSUUID *TL_MESSAGE_SCHEMA_ID = nil;
static int TL_MESSAGE_SCHEMA_VERSION = 1;

static NSUUID *OBJECT_DESCRIPTOR_SCHEMA_ID = nil;
static const int OBJECT_DESCRIPTOR_SCHEMA_VERSION_5 = 5;
static const int OBJECT_DESCRIPTOR_SCHEMA_VERSION_4 = 4;
static const int OBJECT_DESCRIPTOR_SCHEMA_VERSION_3 = 3;
static TLObjectDescriptorSerializer_5 *OBJECT_DESCRIPTOR_SERIALIZER_5 = nil;
static TLSerializer *OBJECT_DESCRIPTOR_SERIALIZER_4 = nil;
static TLSerializer *OBJECT_DESCRIPTOR_SERIALIZER_3 = nil;
static const BOOL OBJECT_DESCRIPTOR_DEFAULT_COPY_ALLOWED = false;

#undef LOG_TAG
#define LOG_TAG @"TLObjectDescriptorSerializer_5"

@implementation TLObjectDescriptorSerializer_5

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLObjectDescriptor.SCHEMA_ID schemaVersion:TLObjectDescriptor.SCHEMA_VERSION_5 class:[TLObjectDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)object;
    [objectDescriptor serializeWithEncoder:encoder];
    [encoder writeBoolean:objectDescriptor.copyAllowed];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);

    // Not used (see below).
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    int64_t expireTimeout = [decoder readLong];
    NSUUID *sendTo = [decoder readOptionalUUID];
    TLDescriptorId *replyTo = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];

    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    if (schemaVersion != TL_MESSAGE_SCHEMA_VERSION || ![TL_MESSAGE_SCHEMA_ID isEqual:schemaId]) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    NSString *message = [decoder readString];

    BOOL copyAllowed = [decoder readBoolean];
    return [[TLObjectDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo message:message copyAllowed:copyAllowed expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:0];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLObjectDescriptorSerializer_4"

@implementation TLObjectDescriptorSerializer_4

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLObjectDescriptor.SCHEMA_ID schemaVersion:TLObjectDescriptor.SCHEMA_VERSION_4 class:[TLObjectDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)object;
    [objectDescriptor serializeWithEncoder:encoder];
    [encoder writeBoolean:objectDescriptor.copyAllowed];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    TLSerializer *serializer = [serializerFactory getSerializerWithSchemaId:schemaId schemaVersion:schemaVersion];
    if (!serializer) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    NSString *message = [decoder readString];
    BOOL copyAllowed = [decoder readBoolean];
    return [[TLObjectDescriptor alloc] initWithDescriptor:descriptor message:message copyAllowed:copyAllowed];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLObjectDescriptorSerializer_3"

@implementation TLObjectDescriptorSerializer_3

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLObjectDescriptor.SCHEMA_ID schemaVersion:TLObjectDescriptor.SCHEMA_VERSION_3 class:[TLObjectDescriptor class]];
    return self;
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *schemaId = [decoder readUUID];
    int schemaVersion = [decoder readInt];
    TLSerializer *serializer = [serializerFactory getSerializerWithSchemaId:schemaId schemaVersion:schemaVersion];
    if (!serializer) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    NSObject *object = [serializer deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    if (!object) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    NSString *message = [decoder readString];
    return [[TLObjectDescriptor alloc] initWithDescriptor:descriptor message:message copyAllowed:OBJECT_DESCRIPTOR_DEFAULT_COPY_ALLOWED];
}

@end

//
// Implementation: TLObjectDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLObjectDescriptor"

@implementation TLObjectDescriptor

+ (void)initialize {
    
    OBJECT_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"9239451b-0193-4703-b98e-a487115e433a"];
    OBJECT_DESCRIPTOR_SERIALIZER_5 = [[TLObjectDescriptorSerializer_5 alloc] init];
    OBJECT_DESCRIPTOR_SERIALIZER_4 = [[TLObjectDescriptorSerializer_4 alloc] init];
    OBJECT_DESCRIPTOR_SERIALIZER_3 = [[TLObjectDescriptorSerializer_3 alloc] init];
    TL_MESSAGE_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"c1ba9e82-43a7-413a-ab9f-b743859e7595"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return OBJECT_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_5 {
    
    return OBJECT_DESCRIPTOR_SCHEMA_VERSION_5;
}

+ (int)SCHEMA_VERSION_4 {
    
    return OBJECT_DESCRIPTOR_SCHEMA_VERSION_4;
}

+ (int)SCHEMA_VERSION_3 {
    
    return OBJECT_DESCRIPTOR_SCHEMA_VERSION_3;
}

+ (TLObjectDescriptorSerializer_5 *)SERIALIZER_5 {
    
    return OBJECT_DESCRIPTOR_SERIALIZER_5;
}

+ (TLSerializer *)SERIALIZER_4 {
    
    return OBJECT_DESCRIPTOR_SERIALIZER_4;
}

+ (TLSerializer *)SERIALIZER_3 {
    
    return OBJECT_DESCRIPTOR_SERIALIZER_3;
}

+ (BOOL)DEFAULT_COPY_ALLOWED {
    
    return OBJECT_DESCRIPTOR_DEFAULT_COPY_ALLOWED;
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeObjectDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLObjectDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" copyAllow: %@\n", self.copyAllowed ? @"YES" : @"NO"];
}

#pragma mark - TLObjectDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ message: %@ copyAllowed: %d expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, message, copyAllowed, expireTimeout);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout];
    
    if (self) {
        _message = message;
        _copyAllowed = copyAllowed;
    }
    return self;
}

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout  createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ sequenceId: %lld sendTo: %@ replyTo: %@ message: %@ copyAllowed: %d expireTimeout: %lld createdTimestamp: %lld sentTimestamp: %lld", LOG_TAG, twincodeOutboundId, sequenceId, sendTo, replyTo, message, copyAllowed, expireTimeout, createdTimestamp, sentTimestamp);
    
    self = [super initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    
    if (self) {
        _message = message;
        _copyAllowed = copyAllowed;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ initWithDescriptor: %@ object: %@ copyAllowed: %d", LOG_TAG, descriptor, message, copyAllowed);
    
    self = [super initWithDescriptor:descriptor];
    
    if(self) {
        _message = message;
        _copyAllowed = copyAllowed;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@", LOG_TAG, descriptorId, conversationId, creationDate, flags, content);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    if(self) {
        _message = content;
        _copyAllowed = (flags & DESCRIPTOR_FLAG_COPY_ALLOWED) != 0;
        _isEdited = (flags & DESCRIPTOR_FLAG_UPDATED) != 0;
    }
    return self;
}

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder {
    
    [encoder writeUUID:TL_MESSAGE_SCHEMA_ID];
    [encoder writeInt:TL_MESSAGE_SCHEMA_VERSION];
    [encoder writeString:self.message];
}

- (nullable NSString *)serialize {
    
    return self.message;
}

- (int)flags {
    
    return (self.copyAllowed ? DESCRIPTOR_FLAG_COPY_ALLOWED : 0) | (self.isEdited ? DESCRIPTOR_FLAG_UPDATED : 0);
}

- (TLPermissionType)permission {
    
    return TLPermissionTypeSendMessage;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {
    
    return [[TLObjectDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil message:self.message copyAllowed:copyAllowed expireTimeout:expireTimeout];
}

- (BOOL)updateWithMessage:(nullable NSString *)message {
    
    if (!message || [self.message isEqual:message]) {
        return NO;
    }
    _message = message;
    return YES;
}

- (BOOL)updateWithCopyAllowed:(nullable NSNumber *)copyAllowed {
    
    if (copyAllowed == nil || copyAllowed.boolValue == self.copyAllowed) {
        return NO;
    }
    _copyAllowed = copyAllowed.boolValue;
    return YES;
}

- (void)markEdited {
    
    _isEdited = YES;
}

@end

/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLTwincodeDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLTwincode.h"

/*
 * <pre>
 * Schema version 2
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"1f0ad01a-9d6e-4157-8d50-e8cc9ce583be",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"TwincodeDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor.4"
 *  "fields":
 *  [
 *   {"name":"twincode", "type":"UUID"}
 *   {"name":"schemaId", "type":"UUID"}
 *   {"name":"copyAllowed", "type":"boolean"}
 *  ]
 * }
 *
 * Schema version 1
 *  Date: 2019/03/29
 *
 * {
 *  "schemaId":"1f0ad01a-9d6e-4157-8d50-e8cc9ce583be",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TwincodeDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"twincode", "type":"UUID"}
 *   {"name":"schemaId", "type":"UUID"}
 *   {"name":"copyAllowed", "type":"boolean"}
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
// Implementation: TLTwincodeDescriptorSerializer_1
//

static NSUUID *TWINCODE_DESCRIPTOR_SCHEMA_ID = nil;
static const int TWINCODE_DESCRIPTOR_SCHEMA_VERSION_2 = 2;
static const int TWINCODE_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLTwincodeDescriptorSerializer_2 *TWINCODE_DESCRIPTOR_SERIALIZER_2 = nil;
static TLSerializer *TWINCODE_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeDescriptorSerializer_2"

@implementation TLTwincodeDescriptorSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLTwincodeDescriptor.SCHEMA_ID schemaVersion:TLTwincodeDescriptor.SCHEMA_VERSION_2 class:[TLTwincodeDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLTwincodeDescriptor *twincodeDescriptor = (TLTwincodeDescriptor *)object;
    [encoder writeUUID:twincodeDescriptor.twincodeId];
    [encoder writeUUID:twincodeDescriptor.schemaId];
    [encoder writeBoolean:twincodeDescriptor.copyAllowed];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    // Not used (see below).
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    int64_t expireTimeout = [decoder readLong];
    NSUUID *sendTo = [decoder readOptionalUUID];
    TLDescriptorId *replyTo = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];

    NSUUID *twincodeId = [decoder readUUID];
    NSUUID *schemaId = [decoder readUUID];
    BOOL copyAllowed = [decoder readBoolean];

    return [[TLTwincodeDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo twincodeId:twincodeId schemaId:schemaId publicKey:nil copyAllowed:copyAllowed expireTimeout:expireTimeout  createdTimestamp:createdTimestamp sentTimestamp:0];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeDescriptorSerializer_1"

@implementation TLTwincodeDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLTwincodeDescriptor.SCHEMA_ID schemaVersion:TLTwincodeDescriptor.SCHEMA_VERSION_1 class:[TLTwincodeDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLTwincodeDescriptor *twincodeDescriptor = (TLTwincodeDescriptor *)object;
    [encoder writeUUID:twincodeDescriptor.twincodeId];
    [encoder writeUUID:twincodeDescriptor.schemaId];
    [encoder writeBoolean:twincodeDescriptor.copyAllowed];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *twincodeId = [decoder readUUID];
    NSUUID *schemaId = [decoder readUUID];
    BOOL copyAllowed = [decoder readBoolean];

    return [[TLTwincodeDescriptor alloc] initWithDescriptor:descriptor twincodeId:twincodeId schemaId:schemaId copyAllowed:copyAllowed];
}

@end

//
// Implementation: TLTwincodeDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeDescriptor"

@implementation TLTwincodeDescriptor

+ (void)initialize {
    
    TWINCODE_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"1f0ad01a-9d6e-4157-8d50-e8cc9ce583be"];
    TWINCODE_DESCRIPTOR_SERIALIZER_2 = [[TLTwincodeDescriptorSerializer_2 alloc] init];
    TWINCODE_DESCRIPTOR_SERIALIZER_1 = [[TLTwincodeDescriptorSerializer_1 alloc] init];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return TWINCODE_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_2 {
    
    return TWINCODE_DESCRIPTOR_SCHEMA_VERSION_2;
}

+ (int)SCHEMA_VERSION_1 {
    
    return TWINCODE_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (nonnull TLTwincodeDescriptorSerializer_2 *)SERIALIZER_2 {
    
    return TWINCODE_DESCRIPTOR_SERIALIZER_2;
}

+ (nonnull TLSerializer *)SERIALIZER_1 {
    
    return TWINCODE_DESCRIPTOR_SERIALIZER_1;
}

#pragma mark - NSObject

- (nonnull NSString *)description {
    
    NSMutableString *string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLTwincodeDescriptor\n"];
    [self appendTo:string];
    [string appendFormat:@" twincodeId: %@\n", self.twincodeId];
    [string appendFormat:@" schemaId: %@\n", self.schemaId];
    [string appendFormat:@" copyAllowed: %d\n", self.copyAllowed];
    return string;
}

#pragma mark - TLDescriptor ()

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeTwincodeDescriptor;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
}

#pragma mark - TLTwincodeDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo twincodeId:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId publicKey:(nullable NSString *)publicKey copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ twincodeId: %@ schemaId: %@ copyAllowed: %d expireTimeout: %lld ", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, twincodeId, schemaId, copyAllowed, expireTimeout);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout];
    
    if (self) {
        _twincodeId = twincodeId;
        _schemaId = schemaId;
        _copyAllowed = copyAllowed;
        _publicKey = publicKey;
    }
    return self;
}

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo twincodeId:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId publicKey:(nullable NSString *)publicKey copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ sequenceId: %lld sendTo: %@ replyTo: %@ twincodeId: %@ schemaId: %@ copyAllowed: %d expireTimeout: %lld createdTimestamp: %lld sentTimestamp: %lld", LOG_TAG, twincodeOutboundId, sequenceId, sendTo, replyTo, twincodeId, schemaId, copyAllowed, expireTimeout, createdTimestamp, sentTimestamp);
    
    self = [super initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    
    if (self) {
        _twincodeId = twincodeId;
        _schemaId = schemaId;
        _copyAllowed = copyAllowed;
        _publicKey = publicKey;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor twincodeId:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ initWithDescriptor: %@ twincodeId: %@ schemaId: %@ copyAllowed: %d", LOG_TAG, descriptor, twincodeId, schemaId, copyAllowed);
    
    self = [super initWithDescriptor:descriptor];
    
    if (self) {
        _twincodeId = twincodeId;
        _schemaId = schemaId;
        _copyAllowed = copyAllowed;
        _publicKey = nil;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@", LOG_TAG, descriptorId, conversationId, creationDate, flags, content);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    if(self) {
        _copyAllowed = (flags & DESCRIPTOR_FLAG_COPY_ALLOWED) != 0;

        NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];
        _schemaId = [TLDescriptor extractUUIDWithArgs:args position:0 defaultValue:[TLTwincode NOT_DEFINED]];
        _twincodeId = [TLDescriptor extractUUIDWithArgs:args position:1 defaultValue:[TLTwincode NOT_DEFINED]];
        _publicKey = [TLDescriptor extractStringWithArgs:args position:2 defaultValue:nil];
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    if (self.publicKey) {
        return [NSString stringWithFormat:@"%@\n%@\n%@", [self.schemaId UUIDString], [self.twincodeId UUIDString], self.publicKey];
    } else {
        return [NSString stringWithFormat:@"%@\n%@", [self.schemaId UUIDString], [self.twincodeId UUIDString]];
    }
}

- (int)flags {
    
    return (self.copyAllowed ? DESCRIPTOR_FLAG_COPY_ALLOWED : 0);
}

- (TLPermissionType)permission {
    
    return TLPermissionTypeSendTwincode;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {

    return [[TLTwincodeDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil twincodeId:self.twincodeId schemaId:self.schemaId publicKey:self.publicKey copyAllowed:copyAllowed expireTimeout:expireTimeout];
}

@end

/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLAudioDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLTwinlifeImpl.h"

/**
 * <pre>
 *
 * Schema version 3
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"f40eaf3b-69c2-4ad5-a4bf-41779b504956",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"AudioDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.4"
 *  "fields":
 *  [
 *   {"name":"duration", "type":"long"}
 *  ]
 * }
 *
 * Schema version 2
 *
 * {
 *  "schemaId":"f40eaf3b-69c2-4ad5-a4bf-41779b504956",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"AudioDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor"
 *  "fields":
 *  [
 *   {"name":"duration", "type":"long"}
 *  ]
 * }
  *
 * Schema version 1
 *
 * {
 *  "schemaId":"f40eaf3b-69c2-4ad5-a4bf-41779b504956",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"TLAudioDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.2"
 *  "fields":
 *  [
 *   {"name":"duration", "type":"long"}
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
// Implementation: TLAudioDescriptorSerializer
//

static NSUUID *AUDIO_DESCRIPTOR_SCHEMA_ID = nil;
static int AUDIO_DESCRIPTOR_SCHEMA_VERSION_3 = 3;
static int AUDIO_DESCRIPTOR_SCHEMA_VERSION_2 = 2;
static int AUDIO_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLAudioDescriptorSerializer_3 *AUDIO_DESCRIPTOR_SERIALIZER_3 = nil;
static TLSerializer *AUDIO_DESCRIPTOR_SERIALIZER_2 = nil;
static TLSerializer *AUDIO_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLAudioDescriptorSerializer_3"

@implementation TLAudioDescriptorSerializer_3

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLAudioDescriptor.SCHEMA_ID schemaVersion:TLAudioDescriptor.SCHEMA_VERSION_3 class:[TLAudioDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAudioDescriptor *audioDescriptor = (TLAudioDescriptor *)object;
    [encoder writeLong:audioDescriptor.duration];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);

    // Not used (see below).
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];

    int64_t duration = [decoder readLong];
    return [[TLAudioDescriptor alloc] initWithFileDescriptor:fileDescriptor duration:duration];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLAudioDescriptorSerializer_2"

@implementation TLAudioDescriptorSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLAudioDescriptor.SCHEMA_ID schemaVersion:TLAudioDescriptor.SCHEMA_VERSION_2 class:[TLAudioDescriptor class]];
    
    return self;
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t duration = [decoder readLong];
    return [[TLAudioDescriptor alloc] initWithFileDescriptor:fileDescriptor duration:duration];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLAudioDescriptorSerializer_1"

@implementation TLAudioDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLAudioDescriptor.SCHEMA_ID schemaVersion:TLAudioDescriptor.SCHEMA_VERSION_1 class:[TLAudioDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAudioDescriptor *audioDescriptor = (TLAudioDescriptor *)object;
    [encoder writeLong:audioDescriptor.duration];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t duration = [decoder readLong];
    return [[TLAudioDescriptor alloc] initWithFileDescriptor:fileDescriptor duration:duration];
}

@end

//
// Implementation: TLAudioDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLAudioDescriptor"

@implementation TLAudioDescriptor

+ (void)initialize {
    
    AUDIO_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"f40eaf3b-69c2-4ad5-a4bf-41779b504956"];
    AUDIO_DESCRIPTOR_SERIALIZER_3 = [[TLAudioDescriptorSerializer_3 alloc] init];
    AUDIO_DESCRIPTOR_SERIALIZER_2 = [[TLAudioDescriptorSerializer_2 alloc] init];
    AUDIO_DESCRIPTOR_SERIALIZER_1 = [[TLAudioDescriptorSerializer_1 alloc] init];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return AUDIO_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_3 {
    
    return AUDIO_DESCRIPTOR_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return AUDIO_DESCRIPTOR_SCHEMA_VERSION_2;
}

+ (int)SCHEMA_VERSION_1 {
    
    return AUDIO_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (nonnull TLAudioDescriptorSerializer_3 *)SERIALIZER_3 {
    
    return AUDIO_DESCRIPTOR_SERIALIZER_3;
}

+ (nonnull TLSerializer *)SERIALIZER_2 {
    
    return AUDIO_DESCRIPTOR_SERIALIZER_2;
}

+ (nonnull TLSerializer *)SERIALIZER_1 {
    
    return AUDIO_DESCRIPTOR_SERIALIZER_1;
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeAudioDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLAudioDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" duration: %lld\n", self.duration];
}

#pragma mark - TLFileDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo descriptor:(nonnull TLAudioDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ descriptor: %@ copyAllowed: %d expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, descriptor, copyAllowed, expireTimeout);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo descriptor:descriptor copyAllowed:copyAllowed expireTimeout:expireTimeout];
    
    if (self) {
        _duration = descriptor.duration;
    }
    return self;
}

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLAudioDescriptor *)soundDescriptor masked:(BOOL)masked {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ masked: %@", LOG_TAG, soundDescriptor, masked ? @"YES" : @"NO");
    
    self = [super initWithFileDescriptor:soundDescriptor masked:masked];
    
    if (self) {
        _duration = soundDescriptor.duration;
    }
    return self;
}

#pragma mark - TLAudioDescriptor ()

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nonnull NSString *)extension length:(int64_t)length end:(int64_t)end duration:(int64_t)duration copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ initWithDescriptor: %@ extension: %@ length: %lld end: %lld duration: %lld copyAllowed: %d", LOG_TAG, descriptor, extension, length ,end, duration, copyAllowed);
    
    self = [super initWithDescriptor:descriptor extension:extension length:length end:end copyAllowed:copyAllowed];
    
    if (self) {
        _duration = duration;
    }
    return self;
}

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor duration:(int64_t)duration {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ duration: %lld", LOG_TAG, fileDescriptor, duration);
    
    self = [super initWithFileDescriptor:fileDescriptor masked:NO];
    
    if (self) {
        _duration = duration;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content length:(int64_t)length {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@ length: %lld", LOG_TAG, descriptorId, conversationId, creationDate, flags, content, length);
    
    NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];
    int64_t end = [TLDescriptor extractLongWithArgs:args position:1 defaultValue:0];
    NSString *extension = [TLDescriptor extractStringWithArgs:args position:2 defaultValue:nil];
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags length:length end:end extension:extension];
    if (self) {
        _duration = [TLDescriptor extractLongWithArgs:args position:0 defaultValue:0];
    }
    return self;
}

/// Used to forward a descriptor (see createForwardWithDescriptorId).
- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo descriptor:(nonnull TLAudioDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ descriptor: %@ copyAllowed: %d", LOG_TAG, descriptorId, conversationId, sendTo, descriptor, copyAllowed);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil descriptor:descriptor copyAllowed:copyAllowed expireTimeout:expireTimeout];
    
    if (self) {
        _duration = descriptor.duration;
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    return [NSString stringWithFormat:@"%lld\n%@", self.duration, [super serialize]];
}

- (TLPermissionType)permission {
    
    return TLPermissionTypeSendAudio;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {

    return [[TLAudioDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo descriptor:self copyAllowed:copyAllowed expireTimeout:expireTimeout];
}

- (void)deleteDescriptor {
    DDLogVerbose(@"%@ deleteDescriptor", LOG_TAG);

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [self getPathWithFileManager:fileManager];
    [fileManager removeItemAtPath:path error:nil];

    path = [path stringByDeletingPathExtension];
    path = [path stringByAppendingPathExtension:@"dat"];
    [fileManager removeItemAtPath:path error:nil];
}

@end

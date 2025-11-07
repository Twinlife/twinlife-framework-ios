/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLNamedFileDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"

/*
 *
 * Schema version 3
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"49fc3005-af8e-43da-925a-00d40889dc98",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"NamedFileDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.4"
 *  "fields":
 *  [
 *   {"name":"name", "type":"string"},
 *  ]
 * }
 *
 * Schema version 2
 *  Date: 2019/03/19
 *
 * {
 *  "schemaId":"49fc3005-af8e-43da-925a-00d40889dc98",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"NamedFileDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor"
 *  "fields":
 *  [
 *   {"name":"name", "type":"string"},
 *  ]
 * }
 *
 * Schema version 1
 *  Date: 2018/09/17
 *
 * {
 *  "schemaId":"49fc3005-af8e-43da-925a-00d40889dc98",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"NamedFileDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.2"
 *  "fields":
 *  [
 *   {"name":"name", "type":"string"},
 *  ]
 * }
 *
 * </pre>
 */

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLNamedFileDescriptorSerializer
//

static NSUUID *NAMED_FILE_DESCRIPTOR_SCHEMA_ID = nil;
static const int NAMED_FILE_DESCRIPTOR_SCHEMA_VERSION_3 = 3;
static const int NAMED_FILE_DESCRIPTOR_SCHEMA_VERSION_2 = 2;
static const int NAMED_FILE_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLNamedFileDescriptorSerializer_3 *NAMED_FILE_DESCRIPTOR_SERIALIZER_3 = nil;
static TLSerializer *NAMED_FILE_DESCRIPTOR_SERIALIZER_2 = nil;
static TLSerializer *NAMED_FILE_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLNamedFileDescriptorSerializer_3"

@implementation TLNamedFileDescriptorSerializer_3

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLNamedFileDescriptor.SCHEMA_ID schemaVersion:TLNamedFileDescriptor.SCHEMA_VERSION_3 class:[TLNamedFileDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLNamedFileDescriptor *namedFileDescriptor = (TLNamedFileDescriptor *)object;
    [encoder writeString:namedFileDescriptor.name];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);

    // Not used (see below).
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
    
    NSString *name = [decoder readString];
    return [[TLNamedFileDescriptor alloc] initWithFileDescriptor:fileDescriptor name:name];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLNamedFileDescriptorSerializer_2"

@implementation TLNamedFileDescriptorSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLNamedFileDescriptor.SCHEMA_ID schemaVersion:TLNamedFileDescriptor.SCHEMA_VERSION_2 class:[TLNamedFileDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLNamedFileDescriptor *namedFileDescriptor = (TLNamedFileDescriptor *)object;
    [encoder writeString:namedFileDescriptor.name];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *name = [decoder readString];
    return [[TLNamedFileDescriptor alloc] initWithFileDescriptor:fileDescriptor name:name];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLNamedFileDescriptorSerializer_1"

@implementation TLNamedFileDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLNamedFileDescriptor.SCHEMA_ID schemaVersion:TLNamedFileDescriptor.SCHEMA_VERSION_1 class:[TLNamedFileDescriptor class]];
    
    return self;
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *name = [decoder readString];
    return [[TLNamedFileDescriptor alloc] initWithFileDescriptor:fileDescriptor name:name];
}

@end

//
// Implementation: TLNamedFileDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLNamedFileDescriptor"

@implementation TLNamedFileDescriptor

+ (void)initialize {
    
    NAMED_FILE_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"49fc3005-af8e-43da-925a-00d40889dc98"];
    NAMED_FILE_DESCRIPTOR_SERIALIZER_3 = [[TLNamedFileDescriptorSerializer_3 alloc] init];
    NAMED_FILE_DESCRIPTOR_SERIALIZER_2 = [[TLNamedFileDescriptorSerializer_2 alloc] init];
    NAMED_FILE_DESCRIPTOR_SERIALIZER_1 = [[TLNamedFileDescriptorSerializer_1 alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return NAMED_FILE_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_3 {
    
    return NAMED_FILE_DESCRIPTOR_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return NAMED_FILE_DESCRIPTOR_SCHEMA_VERSION_2;
}

+ (int)SCHEMA_VERSION_1 {
    
    return NAMED_FILE_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (nonnull TLNamedFileDescriptorSerializer_3 *)SERIALIZER_3 {
    
    return NAMED_FILE_DESCRIPTOR_SERIALIZER_3;
}

+ (nonnull TLSerializer *)SERIALIZER_2 {
    
    return NAMED_FILE_DESCRIPTOR_SERIALIZER_2;
}

+ (nonnull TLSerializer *)SERIALIZER_1 {
    
    return NAMED_FILE_DESCRIPTOR_SERIALIZER_1;
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeNamedFileDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLNamedFileDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" name:  %@\n", self.name];
}

#pragma mark - TLFileDescriptor ()

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLNamedFileDescriptor *)namedFileDescriptor masked:(BOOL)masked {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ masked: %@", LOG_TAG, namedFileDescriptor, masked ? @"YES" : @"NO");
    
    self = [super initWithFileDescriptor:namedFileDescriptor masked:masked];
    
    if (self) {
        _name = namedFileDescriptor.name;
    }
    return self;
}

#pragma mark - TLNamedFileDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo descriptor:(nonnull TLNamedFileDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ descriptor: %@ copyAllowed: %d expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, descriptor, copyAllowed, expireTimeout);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo descriptor:descriptor copyAllowed:copyAllowed expireTimeout:expireTimeout];
    
    if (self) {
        _name = descriptor.name;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nonnull NSString *)extension length:(int64_t)length end:(int64_t)end name:(nonnull NSString *)name copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ initWithDescriptor: %@ extension: %@ length: %lld end: %lld name: %@ copyAllowed: %d", LOG_TAG, descriptor, extension, length ,end, name, copyAllowed);
    
    self = [super initWithDescriptor:descriptor extension:extension length:length end:end copyAllowed:copyAllowed];
    
    if (self) {
        _name = name;
    }
    return self;
}

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor name:(nonnull NSString *)name {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ name: %@", LOG_TAG, fileDescriptor, name);
    
    self = [super initWithFileDescriptor:fileDescriptor masked:NO];
    
    if (self) {
        _name = name;      
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
        _name = [TLDescriptor extractStringWithArgs:args position:0 defaultValue:nil];
    }
    return self;
}

/// Used to forward a descriptor (see createForwardWithDescriptorId).
- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo descriptor:(nonnull TLNamedFileDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ descriptor: %@ copyAllowed: %d", LOG_TAG, descriptorId, conversationId, sendTo, descriptor, copyAllowed);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil descriptor:descriptor copyAllowed:copyAllowed expireTimeout:expireTimeout];
    
    if (self) {
        _name = descriptor.name;
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    return [NSString stringWithFormat:@"%@\n%@", self.name, [super serialize]];
}

- (TLPermissionType)permission {
    
    return TLPermissionTypeSendFile;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {

    return [[TLNamedFileDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo descriptor:self copyAllowed:copyAllowed expireTimeout:expireTimeout];
}

@end

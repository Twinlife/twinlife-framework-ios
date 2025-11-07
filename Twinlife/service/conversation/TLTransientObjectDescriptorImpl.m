/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <CocoaLumberjack.h>

#import "TLTransientObjectDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"

/**
 * <pre>
 *
 * Schema version 2
 *  Date: 2016/12/29
 *
 * {
 *  "type":"record",
 *  "name":"TransientObjectDescriptor",
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
// Implementation: TLTransientObjectDescriptorSerializer
//

static NSUUID *TRANSIENT_OBJECT_DESCRIPTOR_SCHEMA_ID = nil;
static int TRANSIENT_OBJECT_DESCRIPTOR_SCHEMA_VERSION = 2;
static TLSerializer *TRANSIENT_OBJECT_DESCRIPTOR_SERIALIZER = nil;

#undef LOG_TAG
#define LOG_TAG @"TLTransientObjectDescriptorSerializer"

@implementation TLTransientObjectDescriptorSerializer

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLTransientObjectDescriptor.SCHEMA_ID schemaVersion:TLTransientObjectDescriptor.SCHEMA_VERSION class:[TLTransientObjectDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLTransientObjectDescriptor *transientObjectDescriptor = (TLTransientObjectDescriptor *)object;
    [[transientObjectDescriptor serializer] serializeWithSerializerFactory:serializerFactory encoder:encoder object:transientObjectDescriptor.object];
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
    return [[TLTransientObjectDescriptor alloc] initWithDescriptor:descriptor serializer:serializer object:object];
}

@end

//
// Implementation: TLTransientObjectDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLTransientObjectDescriptor"

@implementation TLTransientObjectDescriptor

+ (void)initialize {
    
    TRANSIENT_OBJECT_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"43125f6e-aaf0-4985-a363-1aa1d813db46"];
    TRANSIENT_OBJECT_DESCRIPTOR_SERIALIZER = [[TLTransientObjectDescriptorSerializer alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return TRANSIENT_OBJECT_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return TRANSIENT_OBJECT_DESCRIPTOR_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return TRANSIENT_OBJECT_DESCRIPTOR_SERIALIZER;
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeTransientObjectDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLTransientObjectDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" serializer: %@\n", self.serializer];
    [string appendFormat:@" object:     %@\n", self.object];
}

#pragma mark - TLTransientObjectDescriptor ()

- (instancetype)initWithDescriptor:(TLDescriptor *)descriptor serializer:(TLSerializer *)serializer object:(NSObject *)object {
    DDLogVerbose(@"%@ initWithDescriptor: %@ serializer: %@ object: %@", LOG_TAG, descriptor, serializer, object);
    
    self = [super initWithDescriptor:descriptor];
    
    if(self) {
        _serializer = serializer;
        _object = object;
    }
    return self;
}

- (instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId serializer:(TLSerializer *)serializer object:(NSObject *)object {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ serializer: %@ object: %@", LOG_TAG, twincodeOutboundId, serializer, object);
    
    self = [super initWithDescriptorId:[[TLDescriptorId alloc] initWithId:0 twincodeOutboundId:twincodeOutboundId sequenceId:0] conversationId:0 sendTo:nil replyTo:nil expireTimeout:0];
    if (self) {
        _serializer = serializer;
        _object = object;
    }
    return self;
}

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId serializer:(nonnull TLSerializer *)serializer object:(nonnull NSObject *)object createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ serializer: %@ object: %@", LOG_TAG, twincodeOutboundId, serializer, object);
    
    self = [super initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:nil replyTo:nil expireTimeout:0 createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    if (self) {
        _serializer = serializer;
        _object = object;
    }
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@", LOG_TAG, serializerFactory, encoder);

    [self.serializer serializeWithSerializerFactory:serializerFactory encoder:encoder object:self.object];
}

@end

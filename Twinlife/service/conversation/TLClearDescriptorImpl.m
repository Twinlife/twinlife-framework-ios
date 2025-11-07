/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLClearDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2021/02/09
 *
 * {
 *  "schemaId":"1ea153d1-35ce-4911-9602-6ba4aee25a57",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ClearDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"clearTimestamp", "type":"long"}
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
// Interface: TLClearDescriptor
//

@interface TLClearDescriptor ()

@property int64_t clearTimestamp;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor clearTimestamp:(int64_t)clearTimestamp;

@end

//
// Implementation: TLClearDescriptorSerializer_1
//

static NSUUID *CLEAR_DESCRIPTOR_SCHEMA_ID = nil;
static const int CLEAR_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLSerializer *CLEAR_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLClearDescriptorSerializer_1"

@implementation TLClearDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLClearDescriptor.SCHEMA_ID schemaVersion:TLClearDescriptor.SCHEMA_VERSION_1 class:[TLClearDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLClearDescriptor *clearDescriptor = (TLClearDescriptor *)object;

    [encoder writeLong:clearDescriptor.clearTimestamp];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];

    int64_t clearTimestamp = [decoder readLong];

    return [[TLClearDescriptor alloc] initWithDescriptor:descriptor clearTimestamp:clearTimestamp];
}

@end

//
// Implementation: TLClearDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLClearDescriptor"

@implementation TLClearDescriptor

+ (void)initialize {
    
    CLEAR_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"1ea153d1-35ce-4911-9602-6ba4aee25a57"];
    CLEAR_DESCRIPTOR_SERIALIZER_1 = [[TLClearDescriptorSerializer_1 alloc] init];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return CLEAR_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_1 {
    
    return CLEAR_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (nonnull TLSerializer *)SERIALIZER_1 {
    
    return CLEAR_DESCRIPTOR_SERIALIZER_1;
}

#pragma mark - NSObject

- (nonnull NSString *)description {
    
    NSMutableString *string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLClearDescriptor\n"];
    [self appendTo:string];
    [string appendFormat:@" clearTimestamp: %lld\n", self.clearTimestamp];
    return string;
}

#pragma mark - TLDescriptor ()

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeClearDescriptor;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
}

#pragma mark - TLClearDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId clearTimestamp:(int64_t)clearTimestamp {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld clearTimestamp: %lld", LOG_TAG, descriptorId, conversationId, clearTimestamp);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil creationDate:clearTimestamp sendDate:0 receiveDate:0 readDate:0 updateDate:0 peerDeleteDate:0 deleteDate:0 expireTimeout:0];

    if (self) {
        _clearTimestamp = clearTimestamp;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp clearTimestamp:(int64_t)clearTimestamp {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld createdTimestamp: %lld sentTimestamp: %lld clearTimestamp: %lld", LOG_TAG, descriptorId, conversationId, createdTimestamp, sentTimestamp, clearTimestamp);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil expireTimeout:0];

    if (self) {
        self.createdTimestamp = createdTimestamp;
        self.sentTimestamp = sentTimestamp;
        _clearTimestamp = clearTimestamp;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor clearTimestamp:(int64_t)clearTimestamp {
    DDLogVerbose(@"%@ initWithinitWithDescriptor: %@ clearTimestamp: %lld", LOG_TAG, descriptor, clearTimestamp);
    
    self = [super initWithDescriptor:descriptor];
    
    if (self) {
        _clearTimestamp = clearTimestamp;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout clearDate:(int64_t)clearDate {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld clearDate: %lld", LOG_TAG, descriptorId, conversationId, creationDate, clearDate);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    if(self) {
        _clearTimestamp = clearDate;
    }
    return self;
}

@end

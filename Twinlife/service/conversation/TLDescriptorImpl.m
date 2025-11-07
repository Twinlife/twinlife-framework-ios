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

#import "TLDescriptorImpl.h"
#import "TLEncoder.h"
#import "TLDecoder.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLAudioDescriptorImpl.h"
#import "TLCallDescriptorImpl.h"
#import "TLClearDescriptorImpl.h"
#import "TLGeolocationDescriptorImpl.h"
#import "TLImageDescriptorImpl.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLNamedFileDescriptorImpl.h"
#import "TLObjectDescriptorImpl.h"
#import "TLTwincodeDescriptorImpl.h"
#import "TLVideoDescriptorImpl.h"

/**
 * <pre>
 * Schema version 4
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"6aa12d75-04db-4994-8c01-eecb6e1a0cf7",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"Descriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"expireTimeout", "type":"long"}
 *   {"name":"sendTo", "type":[null, "UUID"]}
 *   {"name":"replyTo", "type":["null", {
 *       {"name":"twincodeOutboundId", "type":"uuid"},
 *       {"name":"sequenceId", "type":"long"}
 *     }
 *   }
 *  ]
 * }
 *
 * Schema version 3
 *
 * {
 *  "schemaId":"6aa12d75-04db-4994-8c01-eecb6e1a0cf7",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"Descriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"twincodeOutboundId", "type":"uuid"}
 *   {"name":"sequenceId", "type":"long"}
 *   {"name":"createdTimestamp", "type":"long"}
 *   {"name":"updatedTimestamp", "type":"long"}
 *   {"name":"sentTimestamp", "type":"long"}
 *   {"name":"receivedTimestamp", "type":"long"}
 *   {"name":"readTimestamp", "type":"long"}
 *   {"name":"deletedTimestamp", "type":"long"}
 *   {"name":"peerDeletedTimestamp", "type":"long"}
 *  ]
 * }
 *
 * {
 *  "type":"record",
 *  "name":"DescriptorTimestamps",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "fields":
 *  [
 *   {"name":"updatedTimestamp", "type":"long"}
 *   {"name":"sentTimestamp", "type":"long"}
 *   {"name":"receivedTimestamp", "type":"long"}
 *   {"name":"readTimestamp", "type":"long"}
 *   {"name":"deletedTimestamp", "type":"long"}
 *   {"name":"peerDeletedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

//
// Implementation: TLDescriptorSerializer_4
//

#undef LOG_TAG
#define LOG_TAG @"TLDescriptorSerializer_4"

@implementation TLDescriptorSerializer_4

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLDescriptor *descriptor = (TLDescriptor *)object;
    [encoder writeLong:descriptor.expireTimeout];
    [encoder writeOptionalUUID:descriptor.sendTo];
    TLDescriptorId *replyTo = descriptor.replyTo;
    if (replyTo) {
        [encoder writeEnum:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    } else {
        [encoder writeEnum:0];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);

    // Not used.
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

+ (nullable TLDescriptorId *)readOptionalDescriptorIdWithDecoder:(nonnull id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ readOptionalDescriptorIdWithDecoder: %@", LOG_TAG, decoder);

    if ([decoder readEnum] == 1) {
        NSUUID *twincodeOutboundId = [decoder readUUID];
        int64_t sequenceId = [decoder readLong];
        return [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
    } else {
        return nil;
    }
}

@end

//
// Implementation: TLDescriptorSerializer_3
//

#undef LOG_TAG
#define LOG_TAG @"TLDescriptorSerializer_3"

@implementation TLDescriptorSerializer_3

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLDescriptor *descriptor = (TLDescriptor *)object;
    TLDescriptorId *descriptorId = descriptor.descriptorId;
    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeLong:descriptor.createdTimestamp];
    [encoder writeLong:descriptor.updatedTimestamp];
    [encoder writeLong:descriptor.sentTimestamp];
    [encoder writeLong:descriptor.receivedTimestamp];
    [encoder writeLong:descriptor.readTimestamp];
    [encoder writeLong:descriptor.deletedTimestamp];
    [encoder writeLong:descriptor.peerDeletedTimestamp];
    
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    int64_t createdTimestamp = [decoder readLong];
    int64_t updatedTimestamp = [decoder readLong];
    int64_t sentTimestamp = [decoder readLong];
    int64_t receivedTimestamp = [decoder readLong];
    int64_t readTimestamp = [decoder readLong];
    int64_t deletedTimestamp = [decoder readLong];
    int64_t peerDeletedTimestamp = [decoder readLong];
    
    return [[TLDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp updatedTimestamp:updatedTimestamp sentTimestamp:sentTimestamp receivedTimestamp:receivedTimestamp readTimestamp:readTimestamp deletedTimestamp:deletedTimestamp peerDeletedTimestamp:peerDeletedTimestamp];
}

@end

//
// Implementation: TLDescriptorAnnotation ()
//

#undef LOG_TAG
#define LOG_TAG @"TLDescriptorAnnotation"

@implementation TLDescriptorAnnotation

- (nonnull instancetype)initWithType:(TLDescriptorAnnotationType)type value:(int)value count:(int)count {
    DDLogVerbose(@"%@ initWithType: %d value: %d count: %d", LOG_TAG, type, value, count);
    
    self = [super init];
    
    if (self) {
        _type = type;
        _value = value;
        _count = count;
    }

    return self;
}

@end

//
// Implementation: TLDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLDescriptor"

@implementation TLDescriptor

+ (nullable NSArray<NSString *> *)extractWithContent:(nullable NSString *)content {
    
    if (!content) {
        return nil;
    } else {
        return [content componentsSeparatedByString:DESCRIPTOR_FIELD_SEPARATOR];
    }
}

+ (int64_t)extractLongWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(int64_t)defaultValue {
    
    if (!args || position < 0 || position >= args.count) {
        return defaultValue;
    }
    
    return [args[position] longLongValue];
}

+ (nullable NSString *)extractStringWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(nullable NSString *)defaultValue {

    if (!args || position < 0 || position >= args.count) {
        return defaultValue;
    }
    
    return args[position];
}

+ (double)extractDoubleWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(double)defaultValue {

    if (!args || position < 0 || position >= args.count) {
        return defaultValue;
    }
    
    return [args[position] doubleValue];
}

+ (nonnull NSUUID *)extractUUIDWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(nonnull NSUUID *)defaultValue {
    
    if (!args || position < 0 || position >= args.count) {
        return defaultValue;
    }
    
    NSUUID *result = [[NSUUID alloc] initWithUUIDString:args[position]];
    return result ? result : defaultValue;
}

+ (nullable TLDescriptor *)extractDescriptorWithContent:(nullable NSData *)content serializerFactory:(nonnull TLSerializerFactory *)serializerFactory timestamps:(nullable NSData *)timestamps twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    DDLogVerbose(@"%@ extractDescriptorWithContent: %@ timestamps: %@", LOG_TAG, content, timestamps);
    
    if (!content) {
        return nil;
    }
    
    TLBinaryDecoder *binaryDecoder = [[TLBinaryDecoder alloc] initWithData:content];
    TLDescriptor *descriptor = nil;
    NSUUID *schemaId = nil;
    int schemaVersion = -1;
    NSException *exception = nil;
    @try {
        schemaId = [binaryDecoder readUUID];
        schemaVersion = [binaryDecoder readInt];
        
        if ([TLObjectDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLObjectDescriptor.SCHEMA_VERSION_5 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLObjectDescriptor.SERIALIZER_5 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLObjectDescriptor.SCHEMA_VERSION_4 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLObjectDescriptor.SERIALIZER_4 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLObjectDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLObjectDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLFileDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLFileDescriptor.SCHEMA_VERSION_4 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLFileDescriptor.SERIALIZER_4 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLFileDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLFileDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLFileDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLFileDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLImageDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLImageDescriptor.SCHEMA_VERSION_4 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLImageDescriptor.SERIALIZER_4 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLImageDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLImageDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLImageDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLImageDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLAudioDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLAudioDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLAudioDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLAudioDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLAudioDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLAudioDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLAudioDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLVideoDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLVideoDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLVideoDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLVideoDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLVideoDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLVideoDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLVideoDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLNamedFileDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLNamedFileDescriptor.SCHEMA_VERSION_3 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLNamedFileDescriptor.SERIALIZER_3 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLNamedFileDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLNamedFileDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLNamedFileDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLNamedFileDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLInvitationDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLInvitationDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLInvitationDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLGeolocationDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLGeolocationDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLGeolocationDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLGeolocationDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLGeolocationDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLTwincodeDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLTwincodeDescriptor.SCHEMA_VERSION_2 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLTwincodeDescriptor.SERIALIZER_2 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            } else if (TLTwincodeDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLTwincodeDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLCallDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLCallDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLCallDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        } else if ([TLClearDescriptor.SCHEMA_ID isEqual:schemaId]) {
            if (TLClearDescriptor.SCHEMA_VERSION_1 == schemaVersion) {
                descriptor = (TLDescriptor *)[TLClearDescriptor.SERIALIZER_1 deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
                if (timestamps) {
                    [descriptor deserializeTimestamps:timestamps];
                }
            }
        }
        return descriptor;
        
    } @catch (NSException *lException) {
        exception = lException;
        return nil;
    }
}

- (nonnull NSString *)getDescriptorKey {

    return [NSString stringWithFormat:@"%@:%lld", self.descriptorId.twincodeOutboundId.UUIDString, self.descriptorId.sequenceId];
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeDescriptor;
}

- (int64_t)expireTimestamp {
    
    if (self.expireTimeout <= 0 || self.readTimestamp == 0) {
        return -1;
    } else {
        return self.readTimestamp + self.expireTimeout;
    }
}

- (BOOL)isEqualDescriptor:(nullable TLDescriptor *)descriptor {
    
    return [self.descriptorId isEqual:descriptor.descriptorId];
}

- (BOOL)isTwincodeOutbound:(nonnull NSUUID *)twincodeOutbound {
    
    return twincodeOutbound && [self.descriptorId.twincodeOutboundId isEqual:twincodeOutbound];
}

- (nullable TLDescriptorAnnotation *)getDescriptorAnnotationWithType:(TLDescriptorAnnotationType)type {
    
    if (self.annotations) {
        for (TLDescriptorAnnotation *annotation in self.annotations) {
            if (annotation.type == type) {
                
                return annotation;
            }
        }
    }

    return nil;
}

/// Get the list of annotations of a given type.
- (nullable NSArray<TLDescriptorAnnotation *> *)getDescriptorAnnotationsWithType:(TLDescriptorAnnotationType)type {
    DDLogVerbose(@"%@ getDescriptorAnnotationsWithType: %d", LOG_TAG, type);

    NSMutableArray<TLDescriptorAnnotation *> *result = nil;
    if (self.annotations) {
        for (TLDescriptorAnnotation *annotation in self.annotations) {
            if (annotation.type == type) {
                if (result == nil) {
                    result = [[NSMutableArray alloc] init];
                }
                [result addObject:annotation];
            }
        }
    }

    return result;
}

- (nullable NSString *)serialize {
    
    return nil;
}

- (int)flags {
    
    return 0;
}

- (int64_t)value {
    
    return 0;
}

#pragma mark - NSObject

- (BOOL)isEqual:(nullable id)object {

    if (self == object) {
        return YES;
    }

    if (object == nil || ![object isKindOfClass:[TLDescriptor class]]) {
        return false;
    }

    return [self isEqualDescriptor:(TLDescriptor *)object];
}

- (NSUInteger)hash {

    NSUInteger result = 17;
    result = 31 * result + self.descriptorId.id;
    result = 31 * result + (NSUInteger)(self.descriptorId.sequenceId ^ (self.descriptorId.sequenceId >> 32));
    return result;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, expireTimeout);
    
    self = [super init];
    
    if (self) {
        _descriptorId = descriptorId;
        _conversationId = conversationId;
        _sendTo = sendTo;
        _replyTo = replyTo;
        
        _createdTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        _updatedTimestamp = 0;
        _expireTimeout = expireTimeout;
        _sentTimestamp = 0L;
        _receivedTimestamp = 0L;
        _deletedTimestamp = 0L;
        _peerDeletedTimestamp = 0L;
        _readTimestamp = 0L;
    }
    return self;
}

- (instancetype)initWithTwincodeOutboundId:(NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo expireTimeout:(int64_t)expireTimeout  createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ sequenceId: %lld sendTo: %@ replyTo: %@ expireTimeout: %lld createdTimestamp: %lld sentTimestamp: %lld", LOG_TAG, twincodeOutboundId, sequenceId, sendTo, replyTo, expireTimeout, createdTimestamp, sentTimestamp);
    
    self = [super init];
    
    if (self) {
        _descriptorId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
        _sendTo = sendTo;
        _replyTo = replyTo;
        
        _createdTimestamp = createdTimestamp;
        _updatedTimestamp = 0;
        _expireTimeout = expireTimeout;
        _sentTimestamp = sentTimestamp;
        _receivedTimestamp = 0L;
        _deletedTimestamp = 0L;
        _peerDeletedTimestamp = 0L;
        _readTimestamp = 0L;
    }
    return self;
}

- (instancetype)initWithTwincodeOutboundId:(NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp updatedTimestamp:(int64_t)updatedTimestamp sentTimestamp:(int64_t)sentTimestamp receivedTimestamp:(int64_t)receivedTimestamp readTimestamp:(int64_t)readTimestamp deletedTimestamp:(int64_t)deletedTimestamp peerDeletedTimestamp:(int64_t)peerDeletedTimestamp {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ sequenceId: %lld createdTimestamp: %lld updatedTimestamp: %lld sentTimestamp: %lld receivedTimestamp: %lld readTimestamp: %lld deletedTimestamp: %lld peerDeletedTimestamp: %lld", LOG_TAG, twincodeOutboundId, sequenceId, createdTimestamp, updatedTimestamp, sentTimestamp, receivedTimestamp, readTimestamp, deletedTimestamp, peerDeletedTimestamp);
    
    self = [super init];
    
    if (self) {
        _descriptorId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
        _expireTimeout = 0;
        _sendTo = nil;
        _replyTo = nil;
        
        _createdTimestamp = createdTimestamp;
        _updatedTimestamp = updatedTimestamp;
        _sentTimestamp = sentTimestamp;
        _receivedTimestamp = receivedTimestamp;
        _deletedTimestamp = deletedTimestamp;
        _peerDeletedTimestamp = peerDeletedTimestamp;
        _readTimestamp = readTimestamp;
    }
    return self;
}

- (instancetype)initWithDescriptor:(TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ initWithDescriptor: %@", LOG_TAG, descriptor);
    
    self = [super init];
    
    if (self) {
        _conversationId = descriptor.conversationId;
        _descriptorId = descriptor.descriptorId;
        _expireTimeout = descriptor.expireTimeout;
        _sendTo = descriptor.sendTo;
        _replyTo = descriptor.replyTo;
        
        _createdTimestamp = descriptor.createdTimestamp;
        _updatedTimestamp = descriptor.updatedTimestamp;
        _sentTimestamp = descriptor.sentTimestamp;
        _receivedTimestamp = descriptor.receivedTimestamp;
        _deletedTimestamp = descriptor.deletedTimestamp;
        _peerDeletedTimestamp = descriptor.peerDeletedTimestamp;
        _readTimestamp = descriptor.readTimestamp;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld ", LOG_TAG, descriptorId, conversationId);
    
    self = [super init];
    if(self) {
        _conversationId = conversationId;
        _descriptorId = descriptorId;
        _expireTimeout = expireTimeout;
        _sendTo = sendTo;
        _replyTo = replyTo;
        
        _createdTimestamp = creationDate;
        _updatedTimestamp = updateDate;
        _sentTimestamp = sendDate;
        _receivedTimestamp = receiveDate;
        _deletedTimestamp = deleteDate;
        _peerDeletedTimestamp = peerDeleteDate;
        _readTimestamp = readDate;
    }
    return self;
}

- (void)setUpdatedTimestamp:(int64_t)updatedTimestamp {
    DDLogVerbose(@"%@ setUpdatedTimestamp: %lld", LOG_TAG, updatedTimestamp);
    
    _updatedTimestamp = updatedTimestamp;
}

- (void)setSentTimestamp:(int64_t)sentTimestamp {
    DDLogVerbose(@"%@ setSentTimestamp: %lld", LOG_TAG, sentTimestamp);
    
    _sentTimestamp = sentTimestamp;
}

- (void)setReceivedTimestamp:(int64_t)receivedTimestamp {
    DDLogVerbose(@"%@ setReceivedTimestamp: %lld", LOG_TAG, receivedTimestamp);
    
    _receivedTimestamp = receivedTimestamp;
}

- (void)setDeletedTimestamp:(int64_t)deletedTimestamp {
    DDLogVerbose(@"%@ setDeletedTimestamp: %lld", LOG_TAG, deletedTimestamp);
    
    _deletedTimestamp = deletedTimestamp;
}

- (void)setPeerDeletedTimestamp:(int64_t)peerDeletedTimestamp {
    DDLogVerbose(@"%@ setPeerDeletedTimestamp: %lld", LOG_TAG, peerDeletedTimestamp);
    
    _peerDeletedTimestamp = peerDeletedTimestamp;
}

- (void)setReadTimestamp:(int64_t)readTimestamp {
    DDLogVerbose(@"%@ setReadTimestamp: %lld", LOG_TAG, readTimestamp);
    
    _readTimestamp = readTimestamp;
}

- (void)deserializeTimestamps:(NSData *)data {
    DDLogVerbose(@"%@ deserializeTimestamps: data %@", LOG_TAG, data);
    
    TLBinaryDecoder * binaryDecoder = [[TLBinaryDecoder alloc] initWithData:data];
    [self setUpdatedTimestamp:[binaryDecoder readLong]];
    [self setSentTimestamp:[binaryDecoder readLong]];
    [self setReceivedTimestamp:[binaryDecoder readLong]];
    [self setReadTimestamp:[binaryDecoder readLong]];
    [self setDeletedTimestamp:[binaryDecoder readLong]];
    [self setPeerDeletedTimestamp:[binaryDecoder readLong]];
}

- (NSData *)serializeTimestamps {
    DDLogVerbose(@"%@ serializeTimestamps", LOG_TAG);
    
    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];
    [binaryEncoder writeLong:self.updatedTimestamp];
    [binaryEncoder writeLong:self.sentTimestamp];
    [binaryEncoder writeLong:self.receivedTimestamp];
    [binaryEncoder writeLong:self.readTimestamp];
    [binaryEncoder writeLong:self.deletedTimestamp];
    [binaryEncoder writeLong:self.peerDeletedTimestamp];
    
    return content;
}

- (BOOL)isExpired {
    DDLogVerbose(@"%@ isExpired", LOG_TAG);

    // No expiration timeout or message not yet read.
    if (self.expireTimeout <= 0 || self.readTimestamp == 0) {
        
        return NO;
    }

    // Message was not delivered: consider it has expired.
    if (self.readTimestamp < 0) {
        
        return YES;
    }

    // Message was delivered and read: check the deadline.
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    return self.expireTimeout + self.readTimestamp < now;
}

- (void)adjustCreatedAndSentTimestamps:(int64_t)offset {
    
    self.createdTimestamp = self.createdTimestamp + offset;
    self.sentTimestamp = self.sentTimestamp + offset;

    // Insure that createdTimestamp is not in the future
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    if (self.createdTimestamp > now) {
        self.createdTimestamp = now;
    }
    if (self.sentTimestamp > now) {
        self.sentTimestamp = now;
    }
}

- (BOOL)hasTimestamps {
    DDLogVerbose(@"%@ hasTimestamps", LOG_TAG);

    return self.sentTimestamp != 0 || self.updatedTimestamp != 0 || self.receivedTimestamp != 0 || self.readTimestamp != 0 || self.deletedTimestamp != 0 || self.peerDeletedTimestamp != 0;
}

- (void)deleteDescriptor {
    DDLogVerbose(@"%@ deleteDescriptor", LOG_TAG);

}

- (TLPermissionType)permission {
    
    return TLPermissionTypeNone;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {
    
    return nil;
}

- (void)updateWithConversationId:(int64_t)conversationId descriptorId:(int64_t)descriptorId {
    
    self.conversationId = conversationId;
    self.descriptorId.id = descriptorId;
}

- (BOOL)updateWithExpireTimeout:(nullable NSNumber *)expireTimeout {
    
    if (expireTimeout == nil || expireTimeout.longLongValue == self.expireTimeout) {
        return NO;
    }
    _expireTimeout = expireTimeout.longLongValue;
    return YES;
}

- (void)appendTo:(NSMutableString*)string {
    
    [string appendFormat:@" descriptorId:         %@\n", self.descriptorId];
    [string appendFormat:@" expireTimeout:        %lld\n", self.expireTimeout];
    [string appendFormat:@" sendTo:               %@\n", self.sendTo];
    [string appendFormat:@" replyTo:              %@\n", self.replyTo];
    [string appendFormat:@" createdTimestamp:     %lld\n", self.createdTimestamp];
    [string appendFormat:@" updatedTimestamp:     %lld\n", self.updatedTimestamp];
    [string appendFormat:@" sentTimestamp:        %lld\n", self.sentTimestamp];
    [string appendFormat:@" receivedTimestamp:    %lld\n", self.receivedTimestamp];
    [string appendFormat:@" readTimestamp:        %lld\n", self.readTimestamp];
    [string appendFormat:@" deletedTimestamp:     %lld\n", self.deletedTimestamp];
    [string appendFormat:@" peerDeletedTimestamp: %lld\n", self.peerDeletedTimestamp];
}

@end

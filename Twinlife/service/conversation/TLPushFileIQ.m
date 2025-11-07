/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPushFileIQ.h"
#import "TLFileDescriptorImpl.h"
#import "TLAudioDescriptorImpl.h"
#import "TLImageDescriptorImpl.h"
#import "TLNamedFileDescriptorImpl.h"
#import "TLVideoDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * PushFile IQ.
 * <p>
 * Schema version 7
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"8359efba-fb7e-4378-a054-c4a9e2d37f8f",
 *  "schemaVersion":"7",
 *
 *  "type":"record",
 *  "name":"PushFileIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"sendTo", "type":["null", "UUID"]},
 *     {"name":"replyTo", "type":["null", {
 *         {"name":"twincodeOutboundId", "type":"uuid"},
 *         {"name":"sequenceId", "type":"long"}
 *     }},
 *     {"name":"createdTimestamp", "type":"long"}
 *     {"name":"sentTimestamp", "type":"long"}
 *     {"name":"expireTimeout", "type":"long"}
 *     {"name":"extension", "type":["null", "String"]}
 *     {"name":"length", "type":"long"}
 *     {"name":"copyAllowed", "type":"boolean"}
 *     {"name":"thumbnail", [null, "type":"bytes"]}
 *     {"name":"descriptorType", "type":"enum"},
 *     {"name":"width", "type":"int"}
 *     {"name":"height", "type":"int"}
 *     {"name":"duration", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLPushFileIQSerializer
//

@implementation TLPushFileIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushFileIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushFileIQ *pushFileIQ = (TLPushFileIQ *)object;
    TLFileDescriptor *fileDescriptor = pushFileIQ.fileDescriptor;
    TLDescriptorId *descriptorId = fileDescriptor.descriptorId;

    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeOptionalUUID:fileDescriptor.sendTo];
    TLDescriptorId *replyTo = fileDescriptor.replyTo;
    if (!replyTo) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:replyTo.twincodeOutboundId];
        [encoder writeLong:replyTo.sequenceId];
    }
    [encoder writeLong:fileDescriptor.createdTimestamp];
    [encoder writeLong:fileDescriptor.sentTimestamp];
    [encoder writeLong:fileDescriptor.expireTimeout];
    [encoder writeOptionalString:fileDescriptor.extension];
    [encoder writeLong:fileDescriptor.length];
    [encoder writeBoolean:fileDescriptor.copyAllowed];
    if (pushFileIQ.thumbnail) {
        [encoder writeEnum:pushFileIQ.thumbnail.length > 0 ? 1 : 2];
        [encoder writeData:pushFileIQ.thumbnail];
    } else {
        [encoder writeEnum:0];
    }
    switch ([fileDescriptor getType]) {
        case TLDescriptorTypeFileDescriptor:
            [encoder writeEnum:0];
            break;

        case TLDescriptorTypeImageDescriptor: {
            [encoder writeEnum:1];

            TLImageDescriptor *imageDescriptor = (TLImageDescriptor *)fileDescriptor;
            [encoder writeInt:imageDescriptor.width];
            [encoder writeInt:imageDescriptor.height];
            break;
        }

        case TLDescriptorTypeAudioDescriptor: {
            [encoder writeEnum:2];
            
            TLAudioDescriptor *audioDescriptor = (TLAudioDescriptor *)fileDescriptor;
            [encoder writeLong:audioDescriptor.duration];
            break;
        }

        case TLDescriptorTypeVideoDescriptor: {
            [encoder writeEnum:3];
            
            TLVideoDescriptor *videoDescriptor = (TLVideoDescriptor *)fileDescriptor;
            [encoder writeInt:videoDescriptor.width];
            [encoder writeInt:videoDescriptor.height];
            [encoder writeLong:videoDescriptor.duration];
            break;
        }

        case TLDescriptorTypeNamedFileDescriptor: {
            [encoder writeEnum:4];

            TLNamedFileDescriptor *namedFileDescriptor = (TLNamedFileDescriptor *)fileDescriptor;
            [encoder writeString:namedFileDescriptor.name];
            break;
        }

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    NSUUID *sendTo = [decoder readOptionalUUID];
    TLDescriptorId *replyTo = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];
    int64_t createdTimestamp = [decoder readLong];
    int64_t sentTimestamp = [decoder readLong];
    int64_t expireTimeout = [decoder readLong];
    NSString *extension = [decoder readOptionalString];
    int64_t length = [decoder readLong];
    BOOL copyAllowed = [decoder readBoolean];
    BOOL hasThumbnail;
    NSData *thumbnail;
    switch ([decoder readEnum]) {
        case 1:
            thumbnail = [decoder readData];
            hasThumbnail = YES;
            break;

        case 2:
            [decoder readData];
            thumbnail = nil;
            hasThumbnail = YES;
            break;

        default:
            thumbnail = nil;
            hasThumbnail = NO;
            break;
    }
    TLFileDescriptor *fileDescriptor;

    fileDescriptor = [[TLFileDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo path:nil extension:extension length:length end:0 copyAllowed:copyAllowed hasThumbnail:hasThumbnail expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    switch ([decoder readEnum]) {
        case 0:
            break;

        case 1: {
            int width = [decoder readInt];
            int height = [decoder readInt];
            fileDescriptor = [[TLImageDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height];
            break;
        }

        case 2: {
            int64_t duration = [decoder readLong];
            fileDescriptor = [[TLAudioDescriptor alloc] initWithFileDescriptor:fileDescriptor duration:duration];
            break;
        }
        case 3: {
            int width = [decoder readInt];
            int height = [decoder readInt];
            int64_t duration = [decoder readLong];
            fileDescriptor = [[TLVideoDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height duration:duration];
            break;
        }
        case 4: {
            NSString *name = [decoder readString];
            fileDescriptor = [[TLNamedFileDescriptor alloc] initWithFileDescriptor:fileDescriptor name:name];
            break;
        }
        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }

    return [[TLPushFileIQ alloc] initWithSerializer:self requestId:requestId fileDescriptor:fileDescriptor thumbnail:thumbnail];
}

@end

//
// Implementation: TLPushFileIQ
//

@implementation TLPushFileIQ

static TLPushFileIQSerializer *IQ_PUSH_FILE_SERIALIZER_7;
static const int IQ_PUSH_FILE_SCHEMA_VERSION_7 = 7;

+ (void)initialize {
    
    IQ_PUSH_FILE_SERIALIZER_7 = [[TLPushFileIQSerializer alloc] initWithSchema:@"8359efba-fb7e-4378-a054-c4a9e2d37f8f" schemaVersion:IQ_PUSH_FILE_SCHEMA_VERSION_7];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_FILE_SERIALIZER_7.schemaId;
}

+ (int)SCHEMA_VERSION_7 {

    return IQ_PUSH_FILE_SERIALIZER_7.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_7 {
    
    return IQ_PUSH_FILE_SERIALIZER_7;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor thumbnail:(nullable NSData *)thumbnail {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _fileDescriptor = fileDescriptor;
        _thumbnail = thumbnail;
    }
    return self;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushFileIQ:"];
    [self appendTo:string];
    return string;
}

@end

/*
 *  Copyright (c) 2021-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPushFileChunkIQ.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLFileDescriptorImpl.h"

/**
 * PushFileChunk IQ.
 * <pre>
 *
 * Schema version 2
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"ae5192f5-f505-4211-84c5-76cb5bf9b147",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"PushFileChunkIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields":
 *  [
 *   {"name":"twincodeOutboundId", "type":"uuid"}
 *   {"name":"sequenceId", "type":"long"}
 *   {"name":"timestamp", "type":"long"}
 *   {"name":"chunkStart", "type":"long"}
 *   {"name":"chunk", "type":[null, "bytes"]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLPushFileChunkIQSerializer
//

@implementation TLPushFileChunkIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushFileChunkIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushFileChunkIQ *pushFileChunkIQ = (TLPushFileChunkIQ *)object;

    [encoder writeUUID:pushFileChunkIQ.descriptorId.twincodeOutboundId];
    [encoder writeLong:pushFileChunkIQ.descriptorId.sequenceId];
    [encoder writeLong:pushFileChunkIQ.timestamp];
    [encoder writeLong:pushFileChunkIQ.chunkStart];
    if (pushFileChunkIQ.chunk) {
        [encoder writeEnum:1];
        [encoder writeDataWithData:pushFileChunkIQ.chunk start:pushFileChunkIQ.startPos length:pushFileChunkIQ.length];
    } else {
        [encoder writeEnum:0];
    }
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    int64_t timestamp = [decoder readLong];
    int64_t chunkStart = [decoder readLong];
    NSData *chunk = [decoder readOptionalData];

    return [[TLPushFileChunkIQ alloc] initWithSerializer:self requestId:requestId descriptorId:[[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId] timestamp:timestamp chunkStart:chunkStart startPos:0 chunk:chunk length:chunk ? (int32_t)chunk.length : 0];
}

@end

//
// Implementation: TLPushFileChunkIQ
//

@implementation TLPushFileChunkIQ

static TLPushFileChunkIQSerializer *IQ_PUSH_FILE_CHUNK_SERIALIZER_2;
static const int IQ_PUSH_FILE_CHUNK_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_PUSH_FILE_CHUNK_SERIALIZER_2 = [[TLPushFileChunkIQSerializer alloc] initWithSchema:@"ae5192f5-f505-4211-84c5-76cb5bf9b147" schemaVersion:IQ_PUSH_FILE_CHUNK_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_FILE_CHUNK_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_PUSH_FILE_CHUNK_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_PUSH_FILE_CHUNK_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp chunkStart:(int64_t)chunkStart startPos:(int32_t)startPos chunk:(nullable NSData *)chunk length:(int32_t)length {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _descriptorId = descriptorId;
        _timestamp = timestamp;
        _chunkStart = chunkStart;
        _startPos = startPos;
        _chunk = chunk;
        _length = length;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [string appendFormat:@" descriptorId: %@", self.descriptorId];
    [string appendFormat:@" timestamp: %lld", self.timestamp];
    [string appendFormat:@" chunkStart: %lld", self.chunkStart];
    [string appendFormat:@" size: %d", self.chunk ? (int)self.chunk.length : 0];
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushFileChunkIQ:"];
    [self appendTo:string];
    return string;
}

@end

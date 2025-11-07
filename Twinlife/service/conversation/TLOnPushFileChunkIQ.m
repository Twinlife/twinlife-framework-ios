/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushFileChunkIQ.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * OnPushFileChunk IQ.
 * <p>
 * Schema version 2
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"af9e04d2-88c5-4054-8707-ad5f06ce9fc4",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnPushFileChunkIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *     {"name":"senderTimestamp", "type":"long"}
 *     {"name":"nextChunkStart", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnPushFileChunkIQSerializer
//

@implementation TLOnPushFileChunkIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnPushFileChunkIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLOnPushFileChunkIQ *onPushFileChunkIQ = (TLOnPushFileChunkIQ *)object;

    [encoder writeInt:onPushFileChunkIQ.deviceState];
    [encoder writeLong:onPushFileChunkIQ.receivedTimestamp];
    [encoder writeLong:onPushFileChunkIQ.senderTimestamp];
    [encoder writeLong:onPushFileChunkIQ.nextChunkStart];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    int deviceState = [decoder readInt];
    int64_t receivedTimestamp = [decoder readLong];
    int64_t senderTimestamp = [decoder readLong];
    int64_t nextChunkStart = [decoder readLong];

    return [[TLOnPushFileChunkIQ alloc] initWithSerializer:self requestId:requestId deviceState:deviceState receivedTimestamp:receivedTimestamp senderTimestamp:senderTimestamp nextChunkStart:nextChunkStart];
}

@end

//
// Implementation: TLOnPushFileChunkIQ
//

@implementation TLOnPushFileChunkIQ

static TLOnPushFileChunkIQSerializer *IQ_ON_PUSH_FILE_CHUNK_SERIALIZER_2;
static const int IQ_ON_PUSH_FILE_CHUNK_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_PUSH_FILE_CHUNK_SERIALIZER_2 = [[TLOnPushFileChunkIQSerializer alloc] initWithSchema:@"af9e04d2-88c5-4054-8707-ad5f06ce9fc4" schemaVersion:IQ_ON_PUSH_FILE_CHUNK_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_FILE_CHUNK_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_PUSH_FILE_CHUNK_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_ON_PUSH_FILE_CHUNK_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState receivedTimestamp:(int64_t)receivedTimestamp senderTimestamp:(int64_t)senderTimestamp nextChunkStart:(int64_t)nextChunkStart {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _deviceState = deviceState;
        _receivedTimestamp = receivedTimestamp;
        _senderTimestamp = senderTimestamp;
        _nextChunkStart = nextChunkStart;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [string appendFormat:@" deviceState: %d", self.deviceState];
    [string appendFormat:@" receivedTimestamp: %lld", self.receivedTimestamp];
    [string appendFormat:@" senderTimestamp: %lld", self.senderTimestamp];
    [string appendFormat:@" nextChunkStart: %lld", self.nextChunkStart];
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLOnPushFileChunkIQ:"];
    [self appendTo:string];
    return string;
}

@end

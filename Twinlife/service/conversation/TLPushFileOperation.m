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

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLPushFileOperation.h"
#import "TLPushFileIQ.h"
#import "TLPushFileChunkIQ.h"
#import "TLPushThumbnailIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLBinaryEncoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLPushFileOperation"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

static NSUUID *PUSH_FILE_OPERATION_SCHEMA_ID = nil;
static int PUSH_FILE_OPERATION_SCHEMA_VERSION = 1;
static const int64_t CHUNK_SIZE = 256 * 1024;

//
// Implementation: TLPushFileOperation
//

@implementation TLPushFileOperation

+ (void)initialize {
    
    PUSH_FILE_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"e8fb18fd-d221-4f25-8099-6f09745136a5"];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return PUSH_FILE_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_FILE_OPERATION_SCHEMA_VERSION;
}

+ (int)NOT_INITIALIZED {
    
    return PUSH_FILE_OPERATION_NOT_INITIALIZED;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushFile descriptor:fileDescriptor];
    
    if(self) {
        _chunkStart = PUSH_FILE_OPERATION_NOT_INITIALIZED;
        _fileDescriptor = fileDescriptor;
        _sentOffset = 0;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId chunkStart:(int64_t)chunkStart {

    self = [super initWithId:id type:TLConversationServiceOperationTypePushFile conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
    if (self) {
        _chunkStart = chunkStart;
    }
    return self;
}

- (void)setChunkStart:(int64_t)chunkStart {
    
    _chunkStart = chunkStart;
    if (_sentOffset < chunkStart) {
        _sentOffset = chunkStart;
    }
}

- (BOOL)isReadyToSend:(int64_t)length {
    
    // Check if we have sent all our data chunks.
    if (self.sentOffset >= length) {
        
        return NO;
    }

    // Check if we know where to start (otherwise we are waiting for the peer to tell us its position).
    if (self.sentOffset < 0) {
        
        return NO;
    }

    // Compute the chunk size that is not yet acknowledged and don't send if we exceed the data window (1Mb).
    int64_t sentNotAckwnoledged = self.sentOffset - self.chunkStart;
    return sentNotAckwnoledged >= 0 && sentNotAckwnoledged < DATA_WINDOW_SIZE;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);
    
    TLFileDescriptor *fileDescriptor = self.fileDescriptor;
    if (!fileDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLFileDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        fileDescriptor = (TLFileDescriptor *)descriptor;
        self.fileDescriptor = fileDescriptor;
    }
    if (![connection preparePushWithDescriptor:fileDescriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }

    if (self.chunkStart == PUSH_FILE_OPERATION_NOT_INITIALIZED) {
        return [self sendPushFileIQWithConnection:connection fileDescriptor:fileDescriptor];
    } else {
        return [self sendPushFileChunkIQWithConnection:connection fileDescriptor:fileDescriptor];
    }
}

- (TLBaseServiceErrorCode)sendPushFileIQWithConnection:(nonnull TLConversationConnection *)connection fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor {
    DDLogVerbose(@"%@ sendPushFileIQWithConnection: %@ fileDescriptor: %@", LOG_TAG, connection, fileDescriptor);
    
    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_12]) {

        NSData *thumbnailData = [fileDescriptor loadThumbnailData];

        // If the thumbnail is big, send it before the PushFileIQ as several PushFileChunkIQ with
        // a dedicated schemaId (there is be no ack for these IQs).  When the PushFileIQ is received
        // it will have a nil thumbnail but it was received before and we will get back the OnPushFileIQ
        // that valides the correct reception of the thumbnail+PushFileIQ.  We use 2xbestChunkSize
        // to send chunks in the range [32, 64, 128K] depending on the RTT.  We must not exceed 256K
        // otherwise WebRTC will not send the IQ.
        int chunkSize = 2 * [connection bestChunkSize];
        if (thumbnailData && thumbnailData.length > chunkSize && [connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_19]) {
            int32_t offset = 0;
            
            while (offset < thumbnailData.length) {
                int32_t len = (int32_t) (thumbnailData.length - offset);
                if (len > chunkSize) {
                    len = chunkSize;
                }

                TLPushFileChunkIQ *pushThumbnailIQ = [[TLPushFileChunkIQ alloc] initWithSerializer:[TLPushThumbnailIQ SERIALIZER_1] requestId:requestId descriptorId:fileDescriptor.descriptorId timestamp:0 chunkStart:offset startPos:offset chunk:thumbnailData length:len];
                [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushFileChunk iq:pushThumbnailIQ];
                offset = offset + len;
            }
            thumbnailData = [[NSData alloc] initWithBytes:nil length:0];
        }
        TLPushFileIQ *pushFileIQ = [[TLPushFileIQ alloc] initWithSerializer:[TLPushFileIQ SERIALIZER_7] requestId:requestId fileDescriptor:fileDescriptor thumbnail:thumbnailData];

        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushFile iq:pushFileIQ];
        return TLBaseServiceErrorCodeQueued;

    } else if (!fileDescriptor.sendTo && !fileDescriptor.replyTo && fileDescriptor.expireTimeout == 0) {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
    
        TLConversationServicePushFileIQ *pushFileIQ;
        switch ([fileDescriptor getType]) {
            case TLDescriptorTypeFileDescriptor:
                pushFileIQ = [[TLConversationServicePushFileIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion fileDescriptor:[[TLFileDescriptor alloc] initWithFileDescriptor:fileDescriptor masked:YES]];
                break;
                
            case TLDescriptorTypeImageDescriptor:
                pushFileIQ = [[TLConversationServicePushFileIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion fileDescriptor:[[TLImageDescriptor alloc] initWithFileDescriptor:fileDescriptor masked:YES]];
                break;
                
            case TLDescriptorTypeAudioDescriptor:
                pushFileIQ = [[TLConversationServicePushFileIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion fileDescriptor:[[TLAudioDescriptor alloc] initWithFileDescriptor:fileDescriptor masked:YES]];
                break;
                
            case TLDescriptorTypeVideoDescriptor:
                pushFileIQ = [[TLConversationServicePushFileIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion fileDescriptor:[[TLVideoDescriptor alloc] initWithFileDescriptor:fileDescriptor masked:YES]];
                break;
                
            case TLDescriptorTypeNamedFileDescriptor:
                pushFileIQ = [[TLConversationServicePushFileIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion fileDescriptor:[[TLNamedFileDescriptor alloc] initWithFileDescriptor:fileDescriptor masked:YES]];
                break;
                
            default:
                return [connection operationNotSupportedWithConnection:connection descriptor:fileDescriptor];
                break;
        }

        NSMutableData *data = [pushFileIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetPushFile data:data];
        return TLBaseServiceErrorCodeQueued;

    } else {
        return [connection operationNotSupportedWithConnection:connection descriptor:fileDescriptor];
    }
}

- (TLBaseServiceErrorCode)sendPushFileChunkIQWithConnection:(nonnull TLConversationConnection *)connection fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor {
    DDLogVerbose(@"%@ sendPushFileChunkIQWithConnection: %@ fileDescriptor: %@", LOG_TAG, connection, fileDescriptor);

    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_12]) {

        int64_t requestId = self.requestId;
        if (requestId < 0) {
            requestId = [TLTwinlife newRequestId];
            int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
            TLPushFileChunkIQ *pushFileChunkIQ = [[TLPushFileChunkIQ alloc] initWithSerializer:[TLPushFileChunkIQ SERIALIZER_2] requestId:requestId descriptorId:fileDescriptor.descriptorId timestamp:now chunkStart:0 startPos:0 chunk:nil length:0];

            self.sentOffset = -1L;
            [self updateWithRequestId:requestId];

            [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushFileChunk iq:pushFileChunkIQ];
            return TLBaseServiceErrorCodeQueued;

        } else {
            int chunkSize = [connection bestChunkSize];
            while ([self isReadyToSend:fileDescriptor.length]) {
                int64_t offset = self.sentOffset;

                NSData *chunk = [connection readChunkWithFileDescriptor:fileDescriptor chunkStart:offset chunkSize:chunkSize];
                if (!chunk) {
                    // File was removed, send a delete descriptor operation (current operation is deleted).
                    return [connection deleteFileDescriptorWithConnection:connection fileDescriptor:fileDescriptor operation:self];
                }

                if (chunk.length == 0) {
                    break;
                }

                int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
                TLPushFileChunkIQ *pushFileChunkIQ = [[TLPushFileChunkIQ alloc] initWithSerializer:[TLPushFileChunkIQ SERIALIZER_2] requestId:requestId descriptorId:fileDescriptor.descriptorId timestamp:now chunkStart:offset startPos:0 chunk:chunk length:(int32_t)chunk.length];

                [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushFileChunk iq:pushFileChunkIQ];

                self.sentOffset = offset + chunk.length;
             }
            return TLBaseServiceErrorCodeQueued;
        }
    } else if (!fileDescriptor.sendTo && !fileDescriptor.replyTo && fileDescriptor.expireTimeout == 0) {

        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
    
        if (majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_1) {
            return [connection operationNotSupportedWithConnection:connection descriptor:fileDescriptor];
        }

        int chunkSize = CHUNK_SIZE;

        NSData *chunk = [connection readChunkWithFileDescriptor:fileDescriptor chunkStart:self.chunkStart chunkSize:chunkSize];
        if (!chunk) {
            // File was removed, send a delete descriptor operation (current operation is deleted).
            return [connection deleteFileDescriptorWithConnection:connection fileDescriptor:fileDescriptor operation:self];
        }
    
        int64_t requestId = [TLTwinlife newRequestId];
        [self updateWithRequestId:requestId];

        TLConversationServicePushFileChunkIQ *pushChunkFileIQ = [[TLConversationServicePushFileChunkIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId descriptorId:fileDescriptor.descriptorId majorVersion:majorVersion minorVersion:minorVersion chunkStart:self.chunkStart chunk:chunk];

        NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
        
        [[TLConversationServicePushFileChunkIQ SERIALIZER] serializeWithSerializerFactory:connection.serializerFactory encoder:binaryEncoder object:pushChunkFileIQ];

        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetPushFileChunk data:data];
        return TLBaseServiceErrorCodeQueued;
    } else {
        return [connection operationNotSupportedWithConnection:connection descriptor:fileDescriptor];
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushFileOperation\n"];
    [self appendTo:string];
    [string appendFormat:@" descriptorId:       %lld", self.descriptor];
    [string appendFormat:@" chunkStart:         %lld\n", self.chunkStart];
    [string appendFormat:@" sentOffset:         %lld\n", self.sentOffset];
    return string;
}

@end

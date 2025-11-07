/*
 *  Copyright (c) 2017-2025 twinlife SA.
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
#import "TLUpdateDescriptorTimestampOperation.h"
#import "TLUpdateTimestampIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLTwincode.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLUpdateDescriptorTimestampOperation"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 128

/**
 * <pre>
 *
 * Schema version 1
 *  Date: 2017/01/13
 *
 * {
 *  "type":"enum",
 *  "name":"UpdateDescriptorTimestampType",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "symbols" : ["READ", "DELETE", "PEER_DELETE"]
 * }
 *
 * {
 *  "schemaId":"62e7fe3c-720c-4247-853a-8fca4bcf0e24",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateDescriptorTimestampOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.Operation"
 *  "fields":
 *  [
 *   {"name":"type", "type":"org.twinlife.schemas.conversation.UpdateDescriptorTimestampType"}
 *   {"name":"twincodeOutboundId", "type":"uuid"},
 *   {"name":"sequenceId", "type":"long"}
 *   {"name":"timestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation : TLUpdateDescriptorTimestampOperationSerializer
//

//
// Implementation : TLUpdateDescriptorTimestampOperation
//

static NSUUID *UPDATE_DESCRIPTOR_TIMESTAMP_OPERATION_SCHEMA_ID = nil;
static const int UPDATE_DESCRIPTOR_TIMESTAMP_OPERATION_SCHEMA_VERSION = 1;

@implementation TLUpdateDescriptorTimestampOperation

+ (void)initialize {
    
    UPDATE_DESCRIPTOR_TIMESTAMP_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"62e7fe3c-720c-4247-853a-8fca4bcf0e24"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return UPDATE_DESCRIPTOR_TIMESTAMP_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return UPDATE_DESCRIPTOR_TIMESTAMP_OPERATION_SCHEMA_VERSION;
}

+ (nullable NSData *)serializeOperation:(TLUpdateDescriptorTimestampType)timestampType timestamp:(int64_t)timestamp descriptorId:(nonnull TLDescriptorId *)descriptorId {

    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *encoder = [[TLBinaryEncoder alloc] initWithData:content];

    [encoder writeInt:UPDATE_DESCRIPTOR_TIMESTAMP_OPERATION_SCHEMA_VERSION];
    switch (timestampType) {
        case TLUpdateDescriptorTimestampTypeRead:
            [encoder writeEnum:0];
            break;
            
        case TLUpdateDescriptorTimestampTypeDelete:
            [encoder writeEnum:1];
            break;
            
        case TLUpdateDescriptorTimestampTypePeerDelete:
            [encoder writeEnum:2];
            break;
            
        default:
            break;
    }
    // Note: we must save the descriptor id as twincode and sequence Id because the descriptor
    // could have been removed from the database for the PEER_DELETE case and we must still
    // notify the peer for the deletion date.
    [encoder writeUUID:descriptorId.twincodeOutboundId];
    [encoder writeLong:descriptorId.sequenceId];
    [encoder writeLong:timestamp];

    return content;
}

- (instancetype)initWithConversation:(TLConversationImpl *)conversation timestampType:(TLUpdateDescriptorTimestampType)timestampType descriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypeUpdateDescriptorTimestamp descriptorId:descriptorId.id];
    
    if (self) {
        _timestampType = timestampType;
        _descriptorTimestamp = timestamp;
        _updateDescriptorId = descriptorId;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content {
    
    self = [super initWithId:id type:TLConversationServiceOperationTypeUpdateDescriptorTimestamp conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
    if (self) {
        int64_t sequenceId = 0;
        NSUUID *twincodeOutbound = [TLTwincode NOT_DEFINED];
        if (content) {
            TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
            
            int schemaVersion = [decoder readInt];
            if (schemaVersion == UPDATE_DESCRIPTOR_TIMESTAMP_OPERATION_SCHEMA_VERSION) {
                switch ([decoder readInt]) {
                    case 0:
                        _timestampType = TLUpdateDescriptorTimestampTypeRead;
                        break;
                    case 1:
                        _timestampType = TLUpdateDescriptorTimestampTypeDelete;
                        break;
                    case 2:
                        _timestampType = TLUpdateDescriptorTimestampTypePeerDelete;
                        break;
                }
                twincodeOutbound = [decoder readUUID];
                sequenceId = [decoder readLong];
                _descriptorTimestamp = [decoder readLong];
            }
        }
        _updateDescriptorId = [[TLDescriptorId alloc] initWithId:0 twincodeOutboundId:twincodeOutbound sequenceId:sequenceId];
    }
    return self;
}

- (nullable NSData *)serialize {
    
    return [TLUpdateDescriptorTimestampOperation serializeOperation:self.timestampType timestamp:self.timestamp descriptorId:self.updateDescriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);
    
    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_17]) {
        TLUpdateTimestampIQ *updateTimestampIQ = [[TLUpdateTimestampIQ alloc] initWithSerializer:[TLUpdateTimestampIQ SERIALIZER_2] requestId:requestId descriptorId:self.updateDescriptorId timestampType:self.timestampType timestamp:self.timestamp];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetUpdateObject iq:updateTimestampIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
        
        TLUpdateDescriptorTimestampIQ *updateDescriptorTimestampIQ = [[TLUpdateDescriptorTimestampIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion timestampType:self.timestampType descriptorId:self.updateDescriptorId timestamp:self.timestamp];
        
        NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
        [[TLUpdateDescriptorTimestampIQ SERIALIZER] serializeWithSerializerFactory:connection.serializerFactory encoder:binaryEncoder object:updateDescriptorTimestampIQ];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetUpdateObject data:data];
        return TLBaseServiceErrorCodeQueued;
    }
}

- (void)appendTo:(NSMutableString*)string {
    
    [string appendFormat:@" timestampType:       %u\n", self.timestampType];
    [string appendFormat:@" conversationId:      %@\n", self.conversationId];
    [string appendFormat:@" descriptor:          %lld\n", self.descriptor];
    [string appendFormat:@" descriptorTimestamp: %lld\n", self.descriptorTimestamp];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLUpdateDescriptorTimestampOperation\n"];
    [self appendTo:string];
    return string;
}

@end

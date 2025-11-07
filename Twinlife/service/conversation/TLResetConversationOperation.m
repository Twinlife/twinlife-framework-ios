/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLClearDescriptorImpl.h"
#import "TLResetConversationOperation.h"
#import "TLResetConversationIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLResetConversationOperation"

//
// Interface: TLResetConversationOperation
//

@interface TLResetConversationOperation ()

- (nonnull instancetype)initWithConversationId:(nonnull TLDatabaseIdentifier *)conversationId descriptorId:(nullable TLDescriptorId *)descriptorId minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(nullable NSMutableArray<TLDescriptorId*> *)resetMembers clearTimestamp:(int64_t)clearTimestamp createdTimestamp:(int64_t)createdTimestamp clearMode:(TLConversationServiceClearMode)clearMode;

@end

/**
 * ResetConversationOperation
 *
 * <pre>
 * Schema version 4
 *  Date: 2022/03/24
 *
 * {
 *  "schemaId":"16d83e7c-761a-4091-8946-59ef5f7903d3",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"ResetConversationOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.Operation"
 *  "fields":
 *  [
 *   {"name":"minSequenceId", "type":"long"}
 *   {"name":"peerMinSequenceId", "type":"long"}
 *   {"name":"count", "type":"long"}
 *   [ {"name":"memberTwincodeOutboundId", "type":"uuid"},
 *     {"name":"peerMinSequenceId", "type":"long"}],
 *   {"name":"clearDescriptorId":["null", {
 *     {"name":"twincodeOutboundId", "type":"uuid"},
 *     {"name":"sequenceId", "type":"long"}
 *   }},
 *   {"name":"clearTimestamp", "type":"long"}
 *   {"name":"clearMode", "type":"int"}
 *   {"name":"createdTimestamp", "type":"long"}
 *  ]
 * }
 *
 * Schema version 3
 *  Date: 2022/02/09
 *
 * {
 *  "schemaId":"16d83e7c-761a-4091-8946-59ef5f7903d3",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"ResetConversationOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.Operation"
 *  "fields":
 *  [
 *   {"name":"minSequenceId", "type":"long"}
 *   {"name":"peerMinSequenceId", "type":"long"}
 *   {"name":"count", "type":"long"}
 *   [ {"name":"memberTwincodeOutboundId", "type":"uuid"},
 *     {"name":"peerMinSequenceId", "type":"long"}],
 *   {"name":"clearDescriptorId":["null", {
 *     {"name":"twincodeOutboundId", "type":"uuid"},
 *     {"name":"sequenceId", "type":"long"}
 *   }},
 *   {"name":"clearTimestamp", "type":"long"}
 *   {"name":"clearMode", "type":"int"}
 *  ]
 * }
 *
 * Schema version 2
 *
 * {
 *  "schemaId":"16d83e7c-761a-4091-8946-59ef5f7903d3",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"ResetConversationOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.Operation"
 *  "fields":
 *  [
 *   {"name":"minSequenceId", "type":"long"}
 *   {"name":"peerMinSequenceId", "type":"long"}
 *   {"name":"count", "type":"long"}
 *   [ {"name":"memberTwincodeOutboundId", "type":"uuid"},
 *     {"name":"peerMinSequenceId", "type":"long"}]
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLResetConversationOperationSerializer
//

#define SERIALIZER_BUFFER_DEFAULT_SIZE 256

static NSUUID *RESET_CONVERSATION_OPERATION_SCHEMA_ID = nil;
static const int RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_4 = 4;
static const int RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_3 = 3;
static const int RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_2 = 2;

/**
 * Version 4 record the creation timestamp of the clear descriptor because it can be destroyed before the operation is sent.
 */
@implementation TLResetConversationOperationSerializer_4

+ (nullable TLResetConversationOperation *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder conversationId:(nonnull TLDatabaseIdentifier *)conversationId {

    int64_t minSequenceId = [decoder readLong];
    int64_t peerMinSequenceId = [decoder readLong];
    long count = (long)[decoder readLong];
    NSMutableArray<TLDescriptorId*> *resetMembers = nil;
    if (count > 0) {
        resetMembers = [[NSMutableArray alloc] initWithCapacity:count];
        while (count > 0) {
            count--;
            NSUUID* memberTwincodeId = [decoder readUUID];
            int64_t memberMinSequenceId = [decoder readLong];
            [resetMembers addObject:[[TLDescriptorId alloc] initWithTwincodeOutboundId:memberTwincodeId sequenceId:memberMinSequenceId]];
        }
    }

    TLDescriptorId *descriptorId = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];
    int64_t clearTimestamp = [decoder readLong];
    TLConversationServiceClearMode clearMode;
    switch ([decoder readEnum]) {
        case 0:
            clearMode = TLConversationServiceClearLocal;
            break;

        case 1:
            clearMode = TLConversationServiceClearBoth;
            break;

            // 2023-02-21: added this new clear mode but supported only starting with ConversationService 2.15.
        case 2:
            clearMode = TLConversationServiceClearMedia;
            break;

        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    int64_t createdTimestamp = [decoder readLong];

    return [[TLResetConversationOperation alloc] initWithConversationId:conversationId descriptorId:descriptorId minSequenceId:minSequenceId peerMinSequenceId:peerMinSequenceId resetMembers:resetMembers clearTimestamp:clearTimestamp createdTimestamp:createdTimestamp clearMode:clearMode];
}

@end

/**
 * Version 3 adds a clear descriptor, a clear mode and uses a timestamp to define descriptors that are cleared.
 */
@implementation TLResetConversationOperationSerializer_3

+ (nullable TLResetConversationOperation *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder conversationId:(nonnull TLDatabaseIdentifier *)conversationId {
    
    int64_t minSequenceId = [decoder readLong];
    int64_t peerMinSequenceId = [decoder readLong];
    long count = (long)[decoder readLong];
    NSMutableArray<TLDescriptorId*> *resetMembers = nil;
    if (count > 0) {
        resetMembers = [[NSMutableArray alloc] initWithCapacity:count];
        while (count > 0) {
            count--;
            NSUUID* memberTwincodeId = [decoder readUUID];
            int64_t memberMinSequenceId = [decoder readLong];
            [resetMembers addObject:[[TLDescriptorId alloc] initWithTwincodeOutboundId:memberTwincodeId sequenceId:memberMinSequenceId]];
        }
    }

    TLDescriptorId *descriptorId = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];
    int64_t clearTimestamp = [decoder readLong];
    TLConversationServiceClearMode clearMode;
    switch ([decoder readEnum]) {
        case 0:
            clearMode = TLConversationServiceClearLocal;
            break;

        case 1:
            clearMode = TLConversationServiceClearBoth;
            break;
            
        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }

    return [[TLResetConversationOperation alloc] initWithConversationId:conversationId descriptorId:descriptorId minSequenceId:minSequenceId peerMinSequenceId:peerMinSequenceId resetMembers:resetMembers clearTimestamp:clearTimestamp createdTimestamp:0 clearMode:clearMode];
}

@end

/**
 * Version 2 adds support for group reset conversation: the peerMinSequenceId is specific to each group member
 * but a given group member has the same peerMinSequenceId for every device in the group.
 */
@implementation TLResetConversationOperationSerializer_2

+ (nullable TLResetConversationOperation *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder conversationId:(nonnull TLDatabaseIdentifier *)conversationId {

    int64_t minSequenceId = [decoder readLong];
    int64_t peerMinSequenceId = [decoder readLong];
    long count = (long)[decoder readLong];
    NSMutableArray<TLDescriptorId*> *resetMembers = nil;
    if (count > 0) {
        resetMembers = [[NSMutableArray alloc] initWithCapacity:count];
        while (count > 0) {
            count--;
            NSUUID* memberTwincodeId = [decoder readUUID];
            int64_t memberMinSequenceId = [decoder readLong];
            [resetMembers addObject:[[TLDescriptorId alloc] initWithTwincodeOutboundId:memberTwincodeId sequenceId:memberMinSequenceId]];
        }
    }
    return [[TLResetConversationOperation alloc] initWithConversationId:conversationId descriptorId:nil minSequenceId:minSequenceId peerMinSequenceId:peerMinSequenceId resetMembers:resetMembers clearTimestamp:0 createdTimestamp:0 clearMode:TLConversationServiceClearBoth];
}

@end

//
// Implementation: TLResetConversationOperation
//

@implementation TLResetConversationOperation

+ (void)initialize {
    
    RESET_CONVERSATION_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"16d83e7c-761a-4091-8946-59ef5f7903d3"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return RESET_CONVERSATION_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_4 {
    
    return RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_4;
}

+ (int)SCHEMA_VERSION_3 {
    
    return RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_2;
}

- (instancetype)initWithConversation:(TLConversationImpl *)conversation clearDescriptor:(nullable TLClearDescriptor *)clearDescriptor minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(NSMutableArray<TLDescriptorId*> *)resetMembers clearTimestamp:(int64_t)clearTimestamp clearMode:(TLConversationServiceClearMode)clearMode {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypeResetConversation descriptor:clearDescriptor];
    if (self) {
        _minSequenceId = minSequenceId;
        _peerMinSequenceId = peerMinSequenceId;
        _resetMembers = resetMembers;
        _clearDescriptor = clearDescriptor;
        if (clearDescriptor) {
            _createdTimestamp = [clearDescriptor createdTimestamp];
            _descriptorId = clearDescriptor.descriptorId;
        } else {
            _createdTimestamp = 0;
            _descriptorId = nil;
        }
        _clearTimestamp = clearTimestamp;
        _clearMode = clearMode;
    }
    return self;
}

- (instancetype)initWithConversationId:(nonnull TLDatabaseIdentifier *)conversationId descriptorId:(nullable TLDescriptorId *)descriptorId minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(NSMutableArray<TLDescriptorId*> *)resetMembers clearTimestamp:(int64_t)clearTimestamp createdTimestamp:(int64_t)createdTimestamp  clearMode:(TLConversationServiceClearMode)clearMode {
    
    self = [super initWithConversationId:conversationId type:TLConversationServiceOperationTypeResetConversation descriptor:nil];
    if (self) {
        _minSequenceId = minSequenceId;
        _peerMinSequenceId = peerMinSequenceId;
        _resetMembers = resetMembers;
        _clearTimestamp = clearTimestamp;
        _createdTimestamp = createdTimestamp;
        _clearMode = clearMode;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content {

    self = [super initWithId:id type:TLConversationServiceOperationTypeResetConversation conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
    if (self) {
        if (content) {
            TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
            
            int schemaVersion = [decoder readInt];
            if (schemaVersion == RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_4) {
                _minSequenceId = [decoder readLong];
                _peerMinSequenceId = [decoder readLong];

                long count = (long)[decoder readLong];
                NSMutableArray<TLDescriptorId*> *resetMembers = nil;
                if (count > 0) {
                    resetMembers = [[NSMutableArray alloc] initWithCapacity:count];
                    while (count > 0) {
                        count--;
                        NSUUID* memberTwincodeId = [decoder readUUID];
                        int64_t memberMinSequenceId = [decoder readLong];
                        [resetMembers addObject:[[TLDescriptorId alloc] initWithTwincodeOutboundId:memberTwincodeId sequenceId:memberMinSequenceId]];
                    }
                    _resetMembers = resetMembers;
                }

                if ([decoder readEnum] != 0) {
                    NSUUID *twincodeOutboundId = [decoder readUUID];
                    int64_t sequenceId = [decoder readLong];
                    _descriptorId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
                }
                _clearTimestamp = [decoder readLong];
                switch ([decoder readEnum]) {
                    case 0:
                        _clearMode = TLConversationServiceClearLocal;
                        break;

                    case 1:
                        _clearMode = TLConversationServiceClearBoth;
                        break;

                        // 2023-02-21: added this new clear mode but supported only starting with ConversationService 2.15.
                    case 2:
                        _clearMode = TLConversationServiceClearMedia;
                        break;

                    case 3:
                        _clearMode = TLConversationServiceClearBothMedia;
                        break;

                    default:
                        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
                }
                _createdTimestamp = [decoder readLong];
            }
        }
    }
    return self;
}

- (int64_t)getCreatedTimestamp {
    
    if (self.clearDescriptor) {
        return [self.clearDescriptor createdTimestamp];
    } else {
        return self.createdTimestamp;
    }
}

- (nullable NSData *)serialize {
    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *encoder = [[TLBinaryEncoder alloc] initWithData:content];

    [encoder writeInt:RESET_CONVERSATION_OPERATION_SCHEMA_VERSION_4];
    [encoder writeLong:self.minSequenceId];
    [encoder writeLong:self.peerMinSequenceId];
    if (!self.resetMembers) {
        [encoder writeLong:0];
    } else {
        [encoder writeLong:self.resetMembers.count];
        for (TLDescriptorId *descriptorId in self.resetMembers) {
            [encoder writeUUID:descriptorId.twincodeOutboundId];
            [encoder writeLong:descriptorId.sequenceId];
        }
    }
    if (!self.descriptorId) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:self.descriptorId.twincodeOutboundId];
        [encoder writeLong:self.descriptorId.sequenceId];
    }
    [encoder writeLong:self.clearTimestamp];
    switch (self.clearMode) {
        case TLConversationServiceClearLocal:
            [encoder writeEnum:0];
            break;

        case TLConversationServiceClearBoth:
            [encoder writeEnum:1];
            break;

        case TLConversationServiceClearMedia:
            [encoder writeEnum:2];
            break;

        case TLConversationServiceClearBothMedia:
            [encoder writeEnum:3];
            break;
    }
    [encoder writeLong:self.createdTimestamp];
    return content;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);
    
    TLClearDescriptor *clearDescriptor = self.clearDescriptor;
    if (!clearDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (descriptor && [descriptor isKindOfClass:[TLClearDescriptor class]]) {
            clearDescriptor = (TLClearDescriptor *)descriptor;
            self.clearDescriptor = clearDescriptor;
        }
    }
    [connection preparePushWithDescriptor:clearDescriptor];

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_13]) {

        // The clear mode CLEAR_MEDIA is supported only starting with 2.15 version, drop the operation otherwise.
        if (self.clearMode == TLConversationServiceClearMedia && ![connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_15]) {
            return TLBaseServiceErrorCodeSuccess;
        }

        int64_t clearTimestamp = self.clearTimestamp;
        TLDescriptorId *clearDescriptorId = self.descriptorId;
        if (!clearDescriptor && clearDescriptorId) {
            int64_t createdTimestamp = [self getCreatedTimestamp];
            int64_t sentTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
            
            clearDescriptor = [[TLClearDescriptor alloc] initWithDescriptorId:clearDescriptorId conversationId:0 createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp clearTimestamp:clearTimestamp];
        }
        TLResetConversationIQ *resetConversationIQ = [[TLResetConversationIQ alloc] initWithSerializer:[TLResetConversationIQ SERIALIZER_4] requestId:requestId clearDescriptor:clearDescriptor clearTimestamp:clearTimestamp clearMode:self.clearMode];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetResetConversation iq:resetConversationIQ];
        return TLBaseServiceErrorCodeQueued;

    } else if (self.clearMode != TLConversationServiceClearBoth) {

        // The descriptor contains a mode not supported by old versions.
        return TLBaseServiceErrorCodeSuccess;

    } else {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];

        TLConversationServiceResetConversationIQ *resetConversationIQ = [[TLConversationServiceResetConversationIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion minSequenceId:self.minSequenceId peerMinSequenceId:self.peerMinSequenceId resetMembers:self.resetMembers];

        NSMutableData *data = [resetConversationIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetResetConversation data:data];
        return TLBaseServiceErrorCodeQueued;
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"\nTLResetConversationOperation\n"];
    [string appendFormat:@" id:                %lld\n", self.id];
    [string appendFormat:@" type:              %u\n", self.type];
    [string appendFormat:@" conversationId:    %@\n", self.conversationId];
    [string appendFormat:@" timestamp:         %lld\n", self.timestamp];
    [string appendFormat:@" requestId:         %lld\n", self.requestId];
    [string appendFormat:@" minSequenceId:     %lld\n", self.minSequenceId];
    [string appendFormat:@" peerMinSequenceId: %lld\n", self.peerMinSequenceId];
    return string;
}

@end

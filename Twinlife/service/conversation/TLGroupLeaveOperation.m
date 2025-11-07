/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationServiceImpl.h"
#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLGroupConversationManager.h"
#import "TLGroupLeaveOperation.h"
#import "TLInviteGroupIQ.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLConversationImpl.h"
#import "TLGroupConversationImpl.h"
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
#define LOG_TAG @"TLGroupLeaveOperation"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 128

//
// Implementation: TLGroupLeaveOperation
//

@implementation TLGroupLeaveOperation

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId {

    return [super initWithConversation:conversation type:type groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
}

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content {
    
    NSUUID *groupTwincodeId = nil;
    NSUUID *memberTwincodeId = nil;
    if (self) {
        if (content) {
            TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
            
            int schemaVersion = [decoder readInt];
            if (schemaVersion <= GROUP_OPERATION_SCHEMA_VERSION_2) {
                groupTwincodeId = [decoder readUUID];
                memberTwincodeId = [decoder readUUID];
            }
        }
    }

    return [super initWithId:id type:type conversationId:conversationId creationDate:creationDate descriptorId:descriptorId groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
}

- (nullable NSData *)serialize {

    return [TLGroupOperation serializeOperation:self.groupTwincodeId memberTwincodeId:self.memberTwincodeId permissions:0 publicKey:nil signedOffTwincodeId:nil signature:nil];
}

- (TLBaseServiceErrorCode)executeInvokeWithConversation:(nonnull TLConversationImpl *)conversationImpl conversationService:(nonnull TLConversationService *)conversationService {
    
    if (self.type == TLConversationServiceOperationTypeInvokeLeaveGroup) {
        return [conversationService.groupManager invokeLeaveGroupWithConversation:conversationImpl groupOperation:self];
    }
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);
    
    // Before sending the leave, verify IFF this is our member twincode that we have not re-joined the group.
    TLConversationImpl *conversation = connection.conversation;
    TLGroupConversationImpl *group = conversation.groupConversation;
    if (group && [group state] == TLGroupConversationStateJoined && [self.memberTwincodeId isEqual:group.twincodeOutboundId]) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];

    int majorVersion = [connection getMaxPeerMajorVersion];
    int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
    BOOL withLeadingPadding = connection.withLeadingPadding;
    TLConversationServiceLeaveGroupIQ *leaveGroupMemberIQ = [[TLConversationServiceLeaveGroupIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion groupTwincodeId:self.groupTwincodeId memberTwincodeId:self.memberTwincodeId];
    
    NSMutableData *data = [leaveGroupMemberIQ serializeWithSerializerFactory:connection.serializerFactory withLeadingPadding:withLeadingPadding];
    [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetLeaveGroup data:data];
    return TLBaseServiceErrorCodeQueued;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLGroupLeaveOperation"];
    [self appendTo:string];
    return string;
}

@end

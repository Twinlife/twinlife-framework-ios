/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLGroupInviteOperation.h"
#import "TLInviteGroupIQ.h"
#import "TLInvitationDescriptorImpl.h"
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
#define LOG_TAG @"TLGroupInviteOperation"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 128

//
// Implementation: TLGroupInviteOperation
//

@implementation TLGroupInviteOperation

- (instancetype)initWithConversation:(TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    
    self = [super initWithConversation:conversation type:type descriptor:invitationDescriptor];
    if (self) {
        _invitationDescriptor = invitationDescriptor;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {
    
    self = [super initWithId:id type:type conversationId:conversationId creationDate:creationDate descriptorId:descriptorId groupTwincodeId:nil memberTwincodeId:nil];
    if (self) {
        _invitationDescriptor = nil;
    }
    return self;
}

- (nullable NSData *)serialize {
    
    // Nothing to serialize: information is in the invitation.
    return nil;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);
    
    TLInvitationDescriptor *invitationDescriptor = self.invitationDescriptor;
    if (!invitationDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        invitationDescriptor = (TLInvitationDescriptor *)descriptor;
        self.invitationDescriptor = invitationDescriptor;
    }
    if (![connection preparePushWithDescriptor:invitationDescriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }
    
    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];

    if (self.type == TLConversationServiceOperationTypeWithdrawInviteGroup) {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
        
        TLConversationServiceRevokeInviteGroupIQ *revokeInviteGroupIQ = [[TLConversationServiceRevokeInviteGroupIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion invitationDescriptor:invitationDescriptor];
        
        NSMutableData *data = [revokeInviteGroupIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetWithdrawInviteGroup data:data];
        return TLBaseServiceErrorCodeQueued;

    } else if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_18]) {
        TLInviteGroupIQ *inviteGroupIQ = [[TLInviteGroupIQ alloc] initWithSerializer:[TLInviteGroupIQ SERIALIZER_2] requestId:requestId invitationDescriptor:invitationDescriptor];

        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetInviteGroup iq:inviteGroupIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
            
        TLConversationServiceInviteGroupIQ *inviteGroupIQ = [[TLConversationServiceInviteGroupIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion invitationDescriptor:invitationDescriptor];
        NSMutableData *data = [inviteGroupIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetInviteGroup data:data];
        return TLBaseServiceErrorCodeQueued;
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLGroupInviteOperation"];
    [self appendTo:string];
    [string appendFormat:@" inviteDescriptor: %@\n", self.invitationDescriptor];
    return string;
}

@end

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
#import "TLGroupJoinOperation.h"
#import "TLJoinGroupIQ.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLConversationImpl.h"
#import "TLGroupConversationImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLSignatureInfoIQ.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLGroupJoinOperation"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 128

//
// Implementation: TLGroupJoinOperation
//

@implementation TLGroupJoinOperation

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor {

    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypeJoinGroup descriptor:invitationDescriptor];
    if (self) {
        _invitationDescriptor = invitationDescriptor;
        _permissions = 0;
        _publicKey = nil;
    }
    return self;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions publicKey:(nullable NSString *)publicKey signedOffTwincodeId:(nullable NSUUID *)signedOffTwincodeId signature:(nullable NSString *)signature {
    
    self = [super initWithConversation:conversation type:type groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
    if (self) {
        _permissions = permissions;
        _publicKey = publicKey;
        _signedOffTwincodeId = signedOffTwincodeId;
        _signature = signature;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content {

    NSUUID *groupTwincodeId = nil;
    NSUUID *memberTwincodeId = nil;
    int64_t permissions = 0;
    NSString *signature = nil;
    NSString *publicKey = nil;
    NSUUID *signedOffTwincodeId;
    if (self) {
        if (content) {
            TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
            
            int schemaVersion = [decoder readInt];
            if (schemaVersion <= GROUP_OPERATION_SCHEMA_VERSION_2) {
                groupTwincodeId = [decoder readUUID];
                memberTwincodeId = [decoder readUUID];
                permissions = [decoder readLong];
                if (schemaVersion == GROUP_OPERATION_SCHEMA_VERSION_2) {
                    publicKey = [decoder readString];
                    signedOffTwincodeId = [decoder readOptionalUUID];
                    signature = [decoder readOptionalString];
                }
            }
        }
    }

    self = [super initWithId:id type:type conversationId:conversationId creationDate:creationDate descriptorId:descriptorId groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
    if (self) {
        _permissions = permissions;
        _publicKey = publicKey;
        _signature = signature;
        _signedOffTwincodeId = signedOffTwincodeId;
    }
    return self;
}

- (nullable NSData *)serialize {

    return [TLGroupOperation serializeOperation:self.groupTwincodeId memberTwincodeId:self.memberTwincodeId permissions:self.permissions publicKey:self.publicKey signedOffTwincodeId:self.signedOffTwincodeId signature:self.signature];
}

- (TLBaseServiceErrorCode)executeInvokeWithConversation:(nonnull TLConversationImpl *)conversationImpl conversationService:(nonnull TLConversationService *)conversationService {
    
    if (self.type == TLConversationServiceOperationTypeInvokeJoinGroup) {
        return [conversationService.groupManager invokeJoinGroupWithConversation:conversationImpl groupOperation:self];
    }
    if (self.type == TLConversationServiceOperationTypeInvokeAddMember) {
        return [conversationService.groupManager invokeAddMemberWithConversation:conversationImpl groupOperation:self];
    }
    return TLBaseServiceErrorCodeSuccess;
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

    NSUUID *groupTwincodeId = [self groupTwincodeId];
    if (!groupTwincodeId) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];

    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_18] && invitationDescriptor) {

        NSUUID *groupTwincodeId = invitationDescriptor.groupTwincodeId;
        TLSignatureInfoIQ *signatureInfo = [connection createSignatureWithConnection:connection groupTwincodeId:groupTwincodeId];
        TLJoinGroupIQ *joinGroupIQ;
        if (signatureInfo) {
            joinGroupIQ = [[TLJoinGroupIQ alloc] initWithSerializer:[TLJoinGroupIQ SERIALIZER_2] requestId:requestId invitationDescriptorId:invitationDescriptor.descriptorId groupTwincodeId:groupTwincodeId memberTwincodeId:signatureInfo.twincodeOutboundId publicKey:signatureInfo.publicKey secretKey:signatureInfo.secret];
        } else {
            joinGroupIQ = [[TLJoinGroupIQ alloc] initWithSerializer:[TLJoinGroupIQ SERIALIZER_2] requestId:requestId invitationDescriptorId:invitationDescriptor.descriptorId groupTwincodeId:groupTwincodeId memberTwincodeId:nil publicKey:nil secretKey:nil];
        }
        
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetJoinGroup iq:joinGroupIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
        
        TLConversationServiceJoinGroupIQ *joinGroupIQ;
        if (invitationDescriptor) {
            joinGroupIQ = [[TLConversationServiceJoinGroupIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion invitationDescriptor:invitationDescriptor];
        } else {
            joinGroupIQ = [[TLConversationServiceJoinGroupIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion groupTwincodeId:groupTwincodeId memberTwincodeId:self.memberTwincodeId permissions:self.permissions];
        }
        
        NSMutableData *data = [joinGroupIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetJoinGroup data:data];
        return TLBaseServiceErrorCodeQueued;
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLGroupJoinOperation"];
    [self appendTo:string];
    [string appendFormat:@" inviteDescriptor: %@\n", self.invitationDescriptor];
    return string;
}

@end

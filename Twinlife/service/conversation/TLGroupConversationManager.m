/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLConversationServiceImpl.h"
#import "TLConversationServiceScheduler.h"
#import "TLRepositoryServiceImpl.h"

#import "TLGroupConversationManager.h"
#import "TLGroupInviteOperation.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLClearDescriptorImpl.h"
#import "TLConversationServiceProvider.h"
#import "TLConversationProtocol.h"
#import "TLConversationImpl.h"
#import "TLGroupConversationImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLTwincodeInboundService.h"
#import "TLCryptoServiceImpl.h"
#import "TLGroupInviteOperation.h"
#import "TLGroupJoinOperation.h"
#import "TLGroupLeaveOperation.h"
#import "TLGroupUpdateOperation.h"
#import "TLConversationServiceIQ.h"
#import "TLOnJoinGroupIQ.h"
#import "TLAttributeNameValue.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define TL_ACTION_GROUP_LEAVE    @"twinlife::conversation::leave"
#define TL_ACTION_GROUP_JOIN     @"twinlife::conversation::join"
#define TL_ACTION_GROUP_ON_JOIN  @"twinlife::conversation::on-join"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

#define PARAM_GROUP_TWINCODE_ID      @"groupTwincodeId"
#define PARAM_MEMBER_TWINCODE_ID     @"memberTwincodeId"
#define PARAM_SIGNED_OFF_TWINCODE_ID @"signedOffTwincodeId"
#define PARAM_PERMISSIONS            @"permissions"
#define PARAM_SIGNATURE              @"signature"
#define PARAM_PUBLIC_KEY             @"pubKey"
#define PARAM_MEMBERS                @"members"

//
// Implementation: TLGroupJoinResult
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupJoinResult"

@implementation TLGroupJoinResult

- (nonnull instancetype)initWithStatus:(TLInvitationDescriptorStatusType)status inviterMemberTwincode:(nullable TLTwincodeOutbound *)inviterMemberTwincode inviterMemberPermissions:(int64_t)inviterMemberPermissions memberPermissions:(int64_t)memberPermissions members:(nullable NSMutableArray<TLOnJoinGroupMemberInfo *> *)members signature:(nullable NSString *)signature {
    DDLogVerbose(@"%@ initWithStatus: %d inviterMemberTwincode: %@ inviterMemberPermissions: %lld memberPermissions: %lld members: %@ signature: %@", LOG_TAG, status, inviterMemberTwincode, inviterMemberPermissions, memberPermissions, members, signature);
    
    self = [super init];
    if (self) {
        _status = status;
        _inviterMemberTwincode = inviterMemberTwincode;
        _inviterMemberPermissions = inviterMemberPermissions;
        _memberPermissions = memberPermissions;
        _members = members;
        _signature = signature;
    }
    return self;
}

@end

//
// Interface: TLGroupConversationManager
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupConversationManager"

@implementation TLGroupConversationManager

- (nonnull instancetype)initWithConversationService:(nonnull TLConversationService *)conversationService {
    DDLogVerbose(@"%@ initWithConversationService %@", LOG_TAG, conversationService);

    self = [super init];
    if (self) {
        _conversationService = conversationService;
        _twinlife = conversationService.twinlife;
        _cryptoService = [_twinlife getCryptoService];
        _twincodeOutboundService = [_twinlife getTwincodeOutboundService];
        _scheduler = conversationService.scheduler;
        _serviceProvider = conversationService.serviceProvider;
    }
    return self;
}

- (void)onTwinlifeReady {
    DDLogVerbose(@"%@ onTwinlifeReady", LOG_TAG);
    
    [[self.twinlife getTwincodeInboundService] addListenerWithAction:TL_ACTION_GROUP_JOIN listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [self onJoinGroupWithInvocation:invocation];
    }];
    [[self.twinlife getTwincodeInboundService] addListenerWithAction:TL_ACTION_GROUP_ON_JOIN listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [self onOnJoinGroupWithInvocation:invocation];
    }];
    [[self.twinlife getTwincodeInboundService] addListenerWithAction:TL_ACTION_GROUP_LEAVE listener:^TLBaseServiceErrorCode(TLTwincodeInvocation *invocation) {
        return [self onLeaveGroupWithInvocation:invocation];
    }];
}

#pragma mark - ConversationService API

- (nullable id<TLGroupConversation>)createGroupConversationWithSubject:(nonnull id<TLRepositoryObject>)subject owner:(BOOL)owner {
    DDLogVerbose(@"%@ createGroupConversationWithSubject: %@ owner: %d", LOG_TAG, subject, owner);
    
    TLTwincodeOutbound *groupTwincode = subject.peerTwincodeOutbound;
    if (!groupTwincode) {
        return nil;
    }

    TLGroupConversationImpl *group = [self.serviceProvider findGroupWithTwincodeId:groupTwincode.uuid];
    if (group) {
        // If we were leaving the group and accepted a new invitation, change the state to joined.
        if ([group state] == TLGroupConversationStateLeaving) {
            [group rejoin];
            [self.serviceProvider updateGroupConversation:group];
        }
        return group;
    }

    group = [self.serviceProvider createGroupConversationWithSubject:subject isOwner:owner];
    
    // Notify upper layers about the new group conversation.
    for (id delegate in self.conversationService.delegates) {
        if ([delegate respondsToSelector:@selector(onGetOrCreateConversationWithRequestId:conversation:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onGetOrCreateConversationWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:group];
            });
        }
    }
    return group;
}

- (TLBaseServiceErrorCode)inviteGroupWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation group:(nonnull id<TLRepositoryObject>)group name:(NSString *)name {
    DDLogVerbose(@"%@ inviteGroupWithRequestId %lld conversation: %@ group: %@ name: %@", LOG_TAG, requestId, conversation, group, name);

    // This operation is not supported on a group.
    if (![conversation isKindOfClass:[TLConversationImpl class]]) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    // Verify that the group exists and remember the peer to which we send the invitation.
    id<TLConversation> targetConversation = [self.serviceProvider loadConversationWithSubject:group];
    if (!targetConversation || ![targetConversation isKindOfClass:[TLGroupConversationImpl class]]) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)targetConversation;
    if (![groupConversation hasPermissionWithPermission:TLPermissionTypeInviteMember]) {
        return TLBaseServiceErrorCodeNoPermission;
    }

    TLTwincodeOutbound *groupTwincode = groupConversation.subject.peerTwincodeOutbound;
    if (!groupTwincode) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    NSString *publicKey = [[self.twinlife getCryptoService] getPublicKeyWithTwincode:groupTwincode];

    // Create one invitation descriptor for the conversation.
    TLConversationImpl *conversationImpl = (TLConversationImpl *)conversation;
    TLInvitationDescriptor *invitation = [self.serviceProvider createInvitationWithConversation:conversation group:groupConversation name:name publicKey:publicKey];
    if (!invitation) {
        // Too many members or pending invitation in the group, refuse the new invitation.
        return TLBaseServiceErrorCodeLimitReached;
    }

    [conversationImpl touch];
    conversationImpl.isActive = YES;
    
    TLGroupInviteOperation *groupOperation = [[TLGroupInviteOperation alloc] initWithConversation:conversation type:TLConversationServiceOperationTypeInviteGroup invitationDescriptor:invitation];
    
    [self.serviceProvider storeOperation:groupOperation];
    [self.scheduler addOperation:groupOperation conversation:conversationImpl];
    
    // Notify invitation was queued.
    for (id delegate in self.conversationService.delegates) {
        if ([delegate respondsToSelector:@selector(onInviteGroupWithRequestId:conversation:descriptor:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onInviteGroupWithRequestId:requestId conversation:conversationImpl descriptor:invitation];
            });
        }
    }
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)withdrawInviteGroupWithRequestId:(int64_t)requestId invitation:(TLInvitationDescriptor *)invitation {
    DDLogVerbose(@"%@ withdrawInviteGroupWithRequestId %lld invitation: %@", LOG_TAG, requestId, invitation);

    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:invitation.conversationId];
    if (!conversation || ![conversation isKindOfClass:[TLConversationImpl class]]) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    TLConversationImpl *conversationImpl = (TLConversationImpl *)conversation;

    BOOL needPeerUpdate = invitation.sentTimestamp > 0 && invitation.status == TLInvitationDescriptorStatusTypePending;
    [invitation setDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
    if (!needPeerUpdate) {
        [invitation setPeerDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
    }
    invitation.status = TLInvitationDescriptorStatusTypeWithdrawn;
    [self.serviceProvider updateWithDescriptor:invitation];

    if (needPeerUpdate) {
        [conversationImpl touch];

        TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypeDelete descriptorId:invitation.descriptorId timestamp:invitation.deletedTimestamp];
        
        [self.serviceProvider storeOperation:updateDescriptorTimestampOperation];
        [self.scheduler addOperation:updateDescriptorTimestampOperation conversation:conversationImpl];
    }
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)joinGroupWithRequestId:(int64_t)requestId descriptorId:(TLDescriptorId *)descriptorId group:(nullable id<TLRepositoryObject>)group {
    DDLogVerbose(@"%@ joinGroupWithRequestId %lld descriptorId: %@ group: %@", LOG_TAG, requestId, descriptorId, group);

    // Retrieve the descriptor for the invitation.
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    // Make sure the descriptor is an invitation.
    if (![descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
        return TLBaseServiceErrorCodeBadRequest;
    }
    
    id <TLConversation> conversation = [self.serviceProvider loadConversationWithId:descriptor.conversationId];
    if (!conversation || ![conversation isKindOfClass:[TLConversationImpl class]]) {
        return TLBaseServiceErrorCodeItemNotFound;
    }
    TLConversationImpl *conversationImpl = (TLConversationImpl *)conversation;

    // Invitation must be pending to be able to join.
    TLInvitationDescriptor *invitation = (TLInvitationDescriptor *)descriptor;
    if (invitation.status != TLInvitationDescriptorStatusTypePending) {
        return TLBaseServiceErrorCodeNoPermission;
    }
    
    // Verify that the user is not already member of this group or we have exactly the same member and groupId.
    TLGroupConversationImpl *groupConversation;
    if (group) {
        TLTwincodeOutbound *twincodeOutbound = group.twincodeOutbound;
        TLTwincodeOutbound *peerTwincodeOutbound = group.peerTwincodeOutbound;
        if (!twincodeOutbound || !group.twincodeInbound || !peerTwincodeOutbound) {
            return TLBaseServiceErrorCodeNoPermission;
        }
        if (![invitation.groupTwincodeId isEqual:peerTwincodeOutbound.uuid]) {
            return TLBaseServiceErrorCodeBadRequest;
        }
        invitation.status = TLInvitationDescriptorStatusTypeAccepted;
        
        // Create the local group conversation.
        groupConversation = [self createGroupConversationWithSubject:group owner:false];
        invitation.memberTwincodeId = twincodeOutbound.uuid;

        // Update the invitation descriptor.
        [invitation setReadTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
        [self.serviceProvider acceptInvitationWithDescriptor:invitation groupConversation:groupConversation];
        
    } else {
        invitation.status = TLInvitationDescriptorStatusTypeRefused;
        
        // Update the invitation descriptor.
        [invitation setReadTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
        [self.serviceProvider updateWithDescriptor:invitation];
        
        groupConversation = nil;
    }

    [conversationImpl touch];
    
    TLGroupJoinOperation *groupOperation = [[TLGroupJoinOperation alloc] initWithConversation:conversation type:TLConversationServiceOperationTypeJoinGroup invitationDescriptor:invitation];
    
    [self.serviceProvider storeOperation:groupOperation];
    [self.scheduler addOperation:groupOperation conversation:conversationImpl];
    
    // Notify invitation was accepted or refused.
    for (id delegate in self.conversationService.delegates) {
        if ([delegate respondsToSelector:@selector(onJoinGroupWithRequestId:group:invitation:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onJoinGroupWithRequestId:requestId group:groupConversation invitation:invitation];
            });
        }
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:requestId conversation:conversation descriptor:invitation updateType:TLConversationServiceUpdateTypeTimestamps];
            });
        }
    }
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)registeredGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group adminTwincodeOutbound:(nonnull TLTwincodeOutbound *)adminTwincodeOutbound adminPermissions:(long)adminPermissions permissions:(long)permissions {
    DDLogVerbose(@"%@ registeredGroupWithRequestId %lld group: %@ adminTwincodeOutbound: %@ adminPermissions: %ld permissions: %ld", LOG_TAG, requestId, group, adminTwincodeOutbound, adminPermissions, permissions);
    
    id<TLConversation> conversation = [self.serviceProvider loadConversationWithSubject:group];
    if (!conversation || ![conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)conversation;
    [groupConversation joinWithPermissions:permissions];
    [self.serviceProvider updateGroupConversation:groupConversation];
    
    // Add the admin member.
    TLGroupConversationAddMemberStatusType result = [self addMember:groupConversation memberTwincode:adminTwincodeOutbound permissions:adminPermissions invitedContactId:nil returnMembers:nil propagate:false signedOffTwincodeId:nil signature:nil];
    if (result == TLGroupConversationAddMemberStatusTypeNewMember) {
        
        for (id delegate in self.conversationService.delegates) {
            if ([delegate respondsToSelector:@selector(onJoinGroupResponseWithRequestId:group:invitation:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onJoinGroupResponseWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:groupConversation invitation:nil];
                });
            }
        }
    }
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)leaveGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group memberTwincodeId:(NSUUID*)memberTwincodeId {
    DDLogVerbose(@"%@ leaveGroupWithRequestId %lld group: %@ memberTwincodeId: %@", LOG_TAG, requestId, group, memberTwincodeId);

    id<TLConversation> conversation = [self.serviceProvider loadConversationWithSubject:group];
    if (!conversation || ![conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)conversation;
    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:groupConversation sendTo:nil];
    TLGroupMemberConversationImpl *member = [groupConversation leaveGroupWithTwincodeId:memberTwincodeId];
    if (!member) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    BOOL leavingCurrentGroup = member == groupConversation.incomingConversation;
    NSDictionary<NSUUID *, TLInvitationDescriptor *> *pendingInvitations = nil;
    if (leavingCurrentGroup) {
        pendingInvitations = [self.serviceProvider listPendingInvitationsWithGroup:group];
    } else {
        pendingInvitations = nil;
    }
    
    // User wants to leave the group, we have to setup the group conversation object in a special state.
    // - we need to send the leave to other members,
    // - we must not accept any pending invitation,
    // - we must free the system resources (files, messages),
    // - ideally, we should not accept new messages except the response to our leave operation.
    if (leavingCurrentGroup) {
        [self.serviceProvider updateGroupConversation:groupConversation];

        // Drop the descriptors and files we have sent.
        NSDictionary<NSUUID *, TLDescriptorId *> *resetList = [self.serviceProvider listDescriptorsToDeleteWithConversation:groupConversation twincodeOutboundId:nil resetDate:LONG_MAX];
        
        [self.conversationService resetWithConversation:groupConversation resetList:resetList clearMode:TLConversationServiceClearBoth];

        // Revoke the pending invitations.
        for (NSUUID *twincodeOutboundId in pendingInvitations) {
            TLInvitationDescriptor *invitation = pendingInvitations[twincodeOutboundId];
            if (invitation) {
                [self withdrawInviteGroupWithRequestId:requestId invitation:invitation];
            }
        }
    } else {
        [self.serviceProvider updateConversation:member];
        
        // Drop the descriptors, files and pending operations for this member.
        NSDictionary<NSUUID *, TLDescriptorId *> *resetList = [self.serviceProvider listDescriptorsToDeleteWithConversation:groupConversation twincodeOutboundId:member.peerTwincodeOutboundId resetDate:LONG_MAX];
        [self.conversationService resetWithConversation:groupConversation resetList:resetList clearMode:TLConversationServiceClearBoth];
    }
    
    // Send the leave operation to each peer, including the member being removed:
    // - if the peer twincode is signed, we can do a secure invocation to notify about the leave,
    // - otherwise, we must queue a LEAVE_GROUP operation.
    TLTwincodeOutbound *groupTwincode = group.peerTwincodeOutbound;
    if (conversations && conversations.count > 0 && groupTwincode) {

        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            TLTwincodeOutbound *peerTwincode = conversationImpl.peerTwincodeOutbound;
            TLGroupLeaveOperation *groupOperation;
            if (peerTwincode && [peerTwincode isSigned]) {
                groupOperation = [[TLGroupLeaveOperation alloc] initWithConversation:conversationImpl type:TLConversationServiceOperationTypeInvokeLeaveGroup groupTwincodeId:groupTwincode.uuid memberTwincodeId:memberTwincodeId];

            } else {
                [conversationImpl touch];
                
                groupOperation = [[TLGroupLeaveOperation alloc] initWithConversation:conversationImpl type:TLConversationServiceOperationTypeLeaveGroup groupTwincodeId:groupTwincode.uuid memberTwincodeId:memberTwincodeId];
            }
            [pendingOperations setObject:groupOperation forKey:conversationImpl];
        }
        [self.conversationService addOperationsWithMap:pendingOperations];
    }
    
    // Remove the member
    for (id delegate in self.conversationService.delegates) {
        if ([delegate respondsToSelector:@selector(onLeaveGroupWithRequestId:group:memberId:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onLeaveGroupWithRequestId:requestId group:groupConversation memberId:memberTwincodeId];
            });
        }
    }
    
    // We are leaving a group with nobody: we must perform the last step now because nobody will tell us to do it.
    if (leavingCurrentGroup && (!conversations || conversations.count == 0)) {
        // Delete the group conversation.
        [self deleteGroupConversation:groupConversation];
    }
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)setPermissionsWithSubject:(nullable id<TLRepositoryObject>)group memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions {

    TLTwincodeOutbound *groupTwincode = group.peerTwincodeOutbound;
    if (!groupTwincode) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    id<TLConversation> conversation = [self.serviceProvider loadConversationWithSubject:group];
    if (!conversation || ![conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        return TLBaseServiceErrorCodeItemNotFound;
    }

    // User must have the update permission.
    TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)conversation;
    if (![groupConversation hasPermissionWithPermission:TLPermissionTypeUpdateMember]) {
        return TLBaseServiceErrorCodeNoPermission;
    }

    TLGroupMemberConversationImpl *member = nil;
    if (!memberTwincodeId) {
        groupConversation.joinPermissions = permissions;
        [self.serviceProvider updateGroupConversation:groupConversation];
    } else {
        member = [groupConversation getMemberWithTwincodeId:memberTwincodeId];
        if (!member) {
            return TLBaseServiceErrorCodeItemNotFound;
        }
        member.permissions = permissions;
        [self.serviceProvider updateConversation:member];
    }

    NSMutableArray<TLConversationImpl *> *conversations = [TLConversationService getConversations:groupConversation sendTo:nil];

    // Send the update permission to each peer.
    if (conversations && conversations.count > 0) {
        NSMapTable<TLConversationImpl *, NSObject *> *pendingOperations = [[NSMapTable alloc] init];
        for (TLConversationImpl *conversationImpl in conversations) {
            [conversationImpl touch];
            if (memberTwincodeId) {
                TLGroupUpdateOperation *groupOperation = [[TLGroupUpdateOperation alloc] initWithConversation:conversationImpl groupTwincodeId:groupTwincode.uuid memberTwincodeId:memberTwincodeId permissions:permissions];

                [pendingOperations setObject:groupOperation forKey:conversationImpl];
            } else {
                // Change this member's permissions and save it.
                conversationImpl.permissions = permissions;
                [self.serviceProvider updateConversation:conversationImpl];

                // Propagate this member's permission to every members.
                for (TLConversationImpl *peer in conversations) {
                    TLGroupUpdateOperation *groupOperation = [[TLGroupUpdateOperation alloc] initWithConversation:conversationImpl groupTwincodeId:groupTwincode.uuid memberTwincodeId:peer.peerTwincodeOutboundId permissions:permissions];

                    [pendingOperations setObject:groupOperation forKey:conversationImpl];
                }
            }
        }
        [self.conversationService addOperationsWithMap:pendingOperations];
    }

    return TLBaseServiceErrorCodeSuccess;
}

#pragma mark - invoke Group operations

- (TLBaseServiceErrorCode)invokeJoinGroupWithConversation:(nonnull TLConversationImpl *)conversation groupOperation:(nonnull TLGroupJoinOperation *)groupOperation {
    DDLogVerbose(@"%@ invokeJoinGroupWithConversation: %@ groupOperation: %@", LOG_TAG, conversation, groupOperation);
    
    TLTwincodeOutbound *twincodeOutbound = conversation.subject.twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound = conversation.peerTwincodeOutbound;
    if (!twincodeOutbound || !peerTwincodeOutbound) {
        return TLBaseServiceErrorCodeExpired;
    }

    NSUUID *groupTwincodeId = groupOperation.groupTwincodeId;
    NSUUID *memberTwincodeId = groupOperation.memberTwincodeId;
    NSString *signature = groupOperation.signature;
    NSUUID *signedOffTwincodeId = groupOperation.signedOffTwincodeId;
    if (![twincodeOutbound.uuid isEqual:memberTwincodeId] || !signedOffTwincodeId || !signature) {
        return TLBaseServiceErrorCodeExpired;
    }

    NSMutableArray<TLAttributeNameValue *> *attributes = [[NSMutableArray alloc] initWithCapacity:3];
    [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_GROUP_TWINCODE_ID uuidValue:groupTwincodeId]];
    [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_MEMBER_TWINCODE_ID uuidValue:memberTwincodeId]];
    [attributes addObject:[[TLAttributeNameLongValue alloc] initWithName:PARAM_PERMISSIONS longValue:groupOperation.permissions]];
    [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_SIGNED_OFF_TWINCODE_ID uuidValue:signedOffTwincodeId]];
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:PARAM_SIGNATURE stringValue:signature]];

    [groupOperation updateWithRequestId:[TLTwinlife newRequestId]];
    [self.twincodeOutboundService secureInvokeTwincodeWithTwincode:twincodeOutbound senderTwincode:twincodeOutbound receiverTwincode:peerTwincodeOutbound options:(TLInvokeTwincodeUrgent | TLInvokeTwincodeCreateSecret) action:TL_ACTION_GROUP_JOIN attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {

        // If we are offline or timed out don't acknowledge the operation but clear the
        // request id so that we can retry it as soon as we are online.
        if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
            [groupOperation updateWithRequestId:OPERATION_NO_REQUEST_ID];
            return;
        }

        // It could happen that the member we want to inform about our join has finally left the group and is invalid.
        // We must remove it.
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
            if (groupConversation) {
                [self delMember:groupConversation memberTwincodeId:peerTwincodeOutbound.uuid];
            }
        }

        [self.scheduler finishInvokeOperation:groupOperation conversation:conversation];
    }];
    return TLBaseServiceErrorCodeQueued;
}

- (TLBaseServiceErrorCode)invokeLeaveGroupWithConversation:(nonnull TLConversationImpl *)conversation groupOperation:(nonnull TLGroupLeaveOperation *)groupOperation {
    DDLogVerbose(@"%@ invokeLeaveGroupWithConversation: %@ groupOperation: %@", LOG_TAG, conversation, groupOperation);
    
    TLTwincodeOutbound *twincodeOutbound = conversation.subject.twincodeOutbound;
    TLTwincodeOutbound *peerTwincodeOutbound = conversation.peerTwincodeOutbound;
    if (!twincodeOutbound || !peerTwincodeOutbound) {
        return TLBaseServiceErrorCodeExpired;
    }
    
    NSUUID *groupTwincodeId = groupOperation.groupTwincodeId;
    NSUUID *memberTwincodeId = groupOperation.memberTwincodeId;
    NSMutableArray<TLAttributeNameValue *> *attributes = [[NSMutableArray alloc] initWithCapacity:2];
    [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_GROUP_TWINCODE_ID uuidValue:groupTwincodeId]];
    [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_MEMBER_TWINCODE_ID uuidValue:memberTwincodeId]];

    [groupOperation updateWithRequestId:[TLTwinlife newRequestId]];
    [self.twincodeOutboundService secureInvokeTwincodeWithTwincode:twincodeOutbound senderTwincode:twincodeOutbound receiverTwincode:peerTwincodeOutbound options:TLInvokeTwincodeUrgent action:TL_ACTION_GROUP_LEAVE attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *invocationId) {
        // If we are offline or timed out don't acknowledge the operation but clear the
        // request id so that we can retry it as soon as we are online.
        if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
            [groupOperation updateWithRequestId:OPERATION_NO_REQUEST_ID];
            return;
        }

        // Proceed with the removal as if we got the on-leave IQ from the peer.
        [self processOnLeaveGroupWithGroupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId peerTwincodeId:conversation.peerTwincodeOutboundId];
        [self.scheduler finishInvokeOperation:groupOperation conversation:conversation];
    }];
    return TLBaseServiceErrorCodeQueued;
}

- (TLBaseServiceErrorCode)invokeAddMemberWithConversation:(nonnull TLConversationImpl *)conversation groupOperation:(nonnull TLGroupJoinOperation *)groupOperation {
    DDLogVerbose(@"%@ invokeAddMemberWithConversation: %@ groupOperation: %@", LOG_TAG, conversation, groupOperation);

    NSUUID *groupTwincodeId = groupOperation.groupTwincodeId;
    NSUUID *memberTwincodeId = groupOperation.memberTwincodeId;
    NSString *publicKey = groupOperation.publicKey;

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (!groupConversation) {
        return TLBaseServiceErrorCodeExpired;
    }
    [groupOperation updateWithRequestId:[TLTwinlife newRequestId]];

    if (!publicKey) {
        [self.twincodeOutboundService getTwincodeWithTwincodeId:memberTwincodeId refreshPeriod:TL_REFRESH_PERIOD withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
            // If we are offline or timed out don't acknowledge the operation but clear the
            // request id so that we can retry it as soon as we are online.
            if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                [groupOperation updateWithRequestId:OPERATION_NO_REQUEST_ID];
                return;
            }
            if (twincodeOutbound) {
                [self addMember:groupConversation memberTwincode:twincodeOutbound permissions:groupOperation.permissions invitedContactId:nil returnMembers:nil propagate:YES signedOffTwincodeId:groupOperation.signedOffTwincodeId signature:groupOperation.signature];
            }
            [self.scheduler finishInvokeOperation:groupOperation conversation:conversation];
        }];
    } else {
        [self.twincodeOutboundService getSignedTwincodeWithTwincodeId:memberTwincodeId publicKey:publicKey trustMethod:TLTrustMethodPeer withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {
            // If we are offline or timed out don't acknowledge the operation but clear the
            // request id so that we can retry it as soon as we are online.
            if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
                [groupOperation updateWithRequestId:OPERATION_NO_REQUEST_ID];
                return;
            }
            if (twincodeOutbound) {
                [self addMember:groupConversation memberTwincode:twincodeOutbound permissions:groupOperation.permissions invitedContactId:nil returnMembers:nil propagate:YES signedOffTwincodeId:groupOperation.signedOffTwincodeId signature:groupOperation.signature];
            }
            [self.scheduler finishInvokeOperation:groupOperation conversation:conversation];
        }];
    }
    return TLBaseServiceErrorCodeQueued;
}

- (TLBaseServiceErrorCode)invokeOnJoinGroupWithGroupConversation:(nonnull TLGroupConversationImpl *)groupConversation memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode publicKey:(nonnull NSString *)publicKey members:(nonnull NSArray<TLOnJoinGroupMemberInfo *> *)members invocationId:(nonnull NSUUID *)invocationId {
    DDLogVerbose(@"%@ invokeOnJoinGroupWithConversation: %@ memberTwincode: %@ publicKey: %@ members: %@ invocationId: %@", LOG_TAG, groupConversation, memberTwincode, publicKey, members, invocationId);
    
    TLTwincodeOutbound *twincodeOutbound = groupConversation.subject.twincodeOutbound;
    if (!twincodeOutbound) {
        [[self.twinlife getTwincodeInboundService] acknowledgeInvocationWithInvocationId:invocationId errorCode:TLBaseServiceErrorCodeExpired];
        return TLBaseServiceErrorCodeExpired;
    }

    NSUUID *groupTwincodeId = groupConversation.peerTwincodeOutboundId;
    NSUUID *memberTwincodeId = memberTwincode.uuid;
    int64_t permissions = groupConversation.joinPermissions;
    NSString *signature = [self signMemberWithTwincode:twincodeOutbound groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId publicKey:publicKey permissions:permissions];
    if (!signature) {
        [[self.twinlife getTwincodeInboundService] acknowledgeInvocationWithInvocationId:invocationId errorCode:TLBaseServiceErrorCodeBadRequest];
        return TLBaseServiceErrorCodeBadRequest;
    }

    NSMutableArray<TLAttributeNameValue *> *attributes = [[NSMutableArray alloc] initWithCapacity:3];
    [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_GROUP_TWINCODE_ID uuidValue:groupTwincodeId]];
    [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_SIGNED_OFF_TWINCODE_ID uuidValue:twincodeOutbound.uuid]];
    [attributes addObject:[[TLAttributeNameLongValue alloc] initWithName:PARAM_PERMISSIONS longValue:permissions]];
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:PARAM_SIGNATURE stringValue:signature]];

    for (TLOnJoinGroupMemberInfo *member in members) {
        NSMutableArray<TLAttributeNameValue *> *memberInfo = [[NSMutableArray alloc] initWithCapacity:3];

        [memberInfo addObject:[[TLAttributeNameUUIDValue alloc] initWithName:PARAM_MEMBER_TWINCODE_ID uuidValue:member.memberTwincodeId]];
        [memberInfo addObject:[[TLAttributeNameLongValue alloc] initWithName:PARAM_PERMISSIONS longValue:member.permissions]];
        [memberInfo addObject:[[TLAttributeNameStringValue alloc] initWithName:PARAM_PUBLIC_KEY stringValue:member.publicKey]];

        [attributes addObject:[[TLAttributeNameListValue alloc] initWithName:PARAM_MEMBERS listValue:memberInfo]];
    }

    [self.twincodeOutboundService secureInvokeTwincodeWithTwincode:twincodeOutbound senderTwincode:twincodeOutbound receiverTwincode:memberTwincode options:(TLInvokeTwincodeUrgent | TLInvokeTwincodeCreateSecret) action:TL_ACTION_GROUP_ON_JOIN attributes:attributes withBlock:^(TLBaseServiceErrorCode errorCode, NSUUID *onJoinInvocationId) {
        // If we are offline or timed out don't acknowledge the invocation: it will be retried.
        if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
            return;
        }

        // It could happen that the member that invoked the join has invalidated its twincode (leave group or uninstall).
        // We must remove it.
        if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
            [self delMember:groupConversation memberTwincodeId:memberTwincode.uuid];
        } else {
            // Secrets and keys are known, we can set the FLAG_ENCRYPT on memberTwincode.
            [self.twincodeOutboundService associateTwincodes:twincodeOutbound previousPeerTwincode:nil peerTwincode:memberTwincode];
        }
        [[self.twinlife getTwincodeInboundService] acknowledgeInvocationWithInvocationId:invocationId errorCode:TLBaseServiceErrorCodeSuccess];
    }];
    return TLBaseServiceErrorCodeQueued;
}

#pragma mark - invocation received

- (TLBaseServiceErrorCode)onJoinGroupWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@: onJoinGroupWithInvocation", LOG_TAG);

    // Perform the join group member invocation only when the invocation is encrypted and signed.
    // BUT it is not trusted yet.
    if (invocation.publicKey == nil) {
        return TLBaseServiceErrorCodeNotAuthorizedOperation;
    }
    if (!invocation.attributes) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    NSUUID *memberTwincodeId = invocation.peerTwincodeId;
    NSUUID *groupTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:PARAM_GROUP_TWINCODE_ID list:invocation.attributes];
    NSUUID *signedOffByTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:PARAM_SIGNED_OFF_TWINCODE_ID list:invocation.attributes];
    NSString *signature = [TLAttributeNameValue getStringAttributeWithName:PARAM_SIGNATURE list:invocation.attributes];
    if (!memberTwincodeId || !groupTwincodeId || !signedOffByTwincodeId || !signature) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (!groupConversation) {
        return TLBaseServiceErrorCodeExpired;
    }

    // The join invocation request is made by a new member and we don't yet trust its public key.
    // This is why the join was signed by a member that we trust and we must verify the join signature.
    TLGroupMemberConversationImpl *signedOffBy = [groupConversation getMemberWithTwincodeId:signedOffByTwincodeId];
    if (!signedOffBy) {
        return TLBaseServiceErrorCodeNoPublicKey;
    }

    TLTwincodeOutbound *signedOffTwincode = signedOffBy.peerTwincodeOutbound;
    if (!signedOffTwincode || ![signedOffTwincode isSigned]) {
        return TLBaseServiceErrorCodeNoPublicKey;
    }

    int64_t permissions = [TLAttributeNameValue getLongAttributeWithName:PARAM_PERMISSIONS list:invocation.attributes defaultValue:groupConversation.joinPermissions];
    TLBaseServiceErrorCode verifyResult = [self verifySignatureWithTwincode:signedOffTwincode groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId publicKey:invocation.publicKey permissions:permissions signature:signature];
    if (verifyResult != TLBaseServiceErrorCodeSuccess) {
        return verifyResult;
    }

    // This join is verified, we can add the member after getting and verifying its attributes with the public key.
    // Now, we trust this member because it was signed by an existing member.
    [self.twincodeOutboundService getSignedTwincodeWithTwincodeId:memberTwincodeId publicKey:invocation.publicKey keyIndex:invocation.keyIndex secretKey:invocation.secretKey trustMethod:TLTrustMethodPeer withBlock:^(TLBaseServiceErrorCode errorCode, TLTwincodeOutbound *twincodeOutbound) {

        // If we are offline or timed out don't acknowledge the invocation.
        if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline) {
            return;
        }

        if (!twincodeOutbound || errorCode != TLBaseServiceErrorCodeSuccess) {
            [[self.twinlife getTwincodeInboundService] acknowledgeInvocationWithInvocationId:invocation.invocationId errorCode:errorCode];
            return;
        }

        NSMutableArray<TLOnJoinGroupMemberInfo *> *members = [[NSMutableArray alloc] init];
        [self addMember:groupConversation memberTwincode:twincodeOutbound permissions:permissions invitedContactId:nil returnMembers:members propagate:NO signedOffTwincodeId:nil signature:nil];
        [self invokeOnJoinGroupWithGroupConversation:groupConversation memberTwincode:twincodeOutbound publicKey:invocation.publicKey members:members invocationId:invocation.invocationId];
    }];
    return TLBaseServiceErrorCodeQueued;
}

- (TLBaseServiceErrorCode)onOnJoinGroupWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@: onOnJoinGroupWithInvocation", LOG_TAG);

    // Perform the join group member invocation only when the invocation is trusted (encrypted and signed).
    if (invocation.trustMethod == TLTrustMethodNone || invocation.publicKey == nil) {
        return TLBaseServiceErrorCodeNotAuthorizedOperation;
    }
    if (!invocation.attributes) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    NSUUID *signedOffByTwincodeId = invocation.peerTwincodeId;
    NSUUID *groupTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:PARAM_GROUP_TWINCODE_ID list:invocation.attributes];
    NSString *signature = [TLAttributeNameValue getStringAttributeWithName:PARAM_SIGNATURE list:invocation.attributes];
    if (!groupTwincodeId || !signature || !signedOffByTwincodeId) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (!groupConversation) {
        return TLBaseServiceErrorCodeExpired;
    }
    TLGroupMemberConversationImpl *signedOffBy = [groupConversation getMemberWithTwincodeId:signedOffByTwincodeId];
    if (!signedOffBy) {
        return TLBaseServiceErrorCodeNoPublicKey;
    }

    TLTwincodeOutbound *twincodeOutbound = groupConversation.subject.twincodeOutbound;
    if (!twincodeOutbound) {
        return TLBaseServiceErrorCodeExpired;
    }

    // The join was signed by a member and we must know it to verify its signature.
    TLTwincodeOutbound *signedOffTwincode = signedOffBy.peerTwincodeOutbound;
    if (!signedOffTwincode || ![signedOffTwincode isSigned]) {
        return TLBaseServiceErrorCodeNoPublicKey;
    }

    // Save the secret that was given by the peer to decrypt its SDPs and set the FLAG_ENCRYPT.
    if (invocation.secretKey) {
        [self.cryptoService saveSecretKeyWithTwincode:twincodeOutbound peerTwincodeOutbound:signedOffTwincode keyIndex:invocation.keyIndex secretKey:invocation.secretKey];
    }

    TLConversationImpl *conversation = groupConversation.incomingConversation;
    while (true) {
        TLAttributeNameValue *list = [TLAttributeNameValue removeAttributeWithName:PARAM_MEMBERS list:invocation.attributes];
        if (!list || ![list isKindOfClass:[TLAttributeNameListValue class]]) {
            return TLBaseServiceErrorCodeSuccess;
        }

        NSArray<TLAttributeNameValue *> *memberInfo = (NSArray<TLAttributeNameValue *> *)list.value;
        NSUUID *memberTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:PARAM_MEMBER_TWINCODE_ID list:memberInfo];
        NSString *memberPublicKey = [TLAttributeNameValue getStringAttributeWithName:PARAM_PUBLIC_KEY list:memberInfo];
        int64_t permissions = [TLAttributeNameValue getLongAttributeWithName:PARAM_PERMISSIONS list:memberInfo defaultValue:0];
        if (memberTwincodeId) {
            TLGroupMemberConversationImpl *groupMember = [groupConversation getMemberWithTwincodeId:memberTwincodeId];
            if (!groupMember) {
                TLGroupJoinOperation *groupOperation = [[TLGroupJoinOperation alloc] initWithConversation:conversation type:TLConversationServiceOperationTypeInvokeAddMember groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId permissions:permissions publicKey:memberPublicKey signedOffTwincodeId:signedOffByTwincodeId signature:signature];

                [self.serviceProvider storeOperation:groupOperation];
                [self.scheduler addOperation:groupOperation conversation:conversation];
            }
        }
    }
}

- (TLBaseServiceErrorCode)onLeaveGroupWithInvocation:(nonnull TLTwincodeInvocation *)invocation {
    DDLogVerbose(@"%@: onLeaveGroupWithInvocation", LOG_TAG);

    // Perform the leave group member invocation for an encrypted and signed invocation only.
    if (invocation.publicKey == nil) {
        return TLBaseServiceErrorCodeNotAuthorizedOperation;
    }
    if (!invocation.attributes) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    NSUUID *memberTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:PARAM_MEMBER_TWINCODE_ID list:invocation.attributes];
    NSUUID *groupTwincodeId = [TLAttributeNameValue getUUIDAttributeWithName:PARAM_GROUP_TWINCODE_ID list:invocation.attributes];
    if (!memberTwincodeId || !groupTwincodeId) {
        return TLBaseServiceErrorCodeBadRequest;
    }

    // If we don't trust the member yet, still accept the leave only from itself.
    if (invocation.trustMethod == TLTrustMethodNone && ![memberTwincodeId isEqual:invocation.peerTwincodeId]) {
        return TLBaseServiceErrorCodeNotAuthorizedOperation;
    }

    [self processLeaveGroupWithGroupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
    return TLBaseServiceErrorCodeSuccess;
}

#pragma mark - process IQ operations

- (int64_t)processInviteGroupWithConnection:(nonnull TLConversationConnection *)connection invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor {
    DDLogVerbose(@"%@ processInviteGroupWithConnection: %@ invitationDescriptor: %@", LOG_TAG, connection, invitationDescriptor);

    TLConversationImpl *conversationImpl = connection.conversation;
    int64_t receivedTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    invitationDescriptor.receivedTimestamp = receivedTimestamp;
    [invitationDescriptor adjustCreatedAndSentTimestamps:connection.peerTimeCorrection];
    TLConversationServiceProviderResult result = [self.serviceProvider insertOrUpdateDescriptorWithConversation:conversationImpl descriptor:invitationDescriptor];
    if (result == TLConversationServiceProviderResultError) {
        receivedTimestamp = -1L;
    }

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:invitationDescriptor.groupTwincodeId];

    if (groupConversation && [groupConversation state] == TLGroupConversationStateJoined) {
        // User is already member of the group.
        invitationDescriptor.readTimestamp = invitationDescriptor.receivedTimestamp;
        invitationDescriptor.memberTwincodeId = groupConversation.twincodeOutboundId;
        invitationDescriptor.status = TLInvitationDescriptorStatusTypeAccepted;
        [self.serviceProvider updateWithDescriptor:invitationDescriptor];
        
        // Send the join request immediately.
        TLGroupJoinOperation *groupOperation = [[TLGroupJoinOperation alloc] initWithConversation:conversationImpl type:TLConversationServiceOperationTypeJoinGroup invitationDescriptor:invitationDescriptor];
        
        [self.serviceProvider storeOperation:groupOperation];
        [self.scheduler addOperation:groupOperation conversation:conversationImpl];
    }
    
    if (result == TLConversationServiceProviderResultStored) {
        
        conversationImpl.isActive = YES;
        
        if (!groupConversation) {
            // If the invitation was inserted, propagate it to upper layers through the onInviteGroupRequest callback.
            // Otherwise, we already know the invitation and we only need to acknowledge the sender.
            for (id delegate in self.conversationService.delegates) {
                if ([delegate respondsToSelector:@selector(onInviteGroupRequestWithRequestId:conversation:invitation:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onInviteGroupRequestWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl invitation:invitationDescriptor];
                    });
                }
            }
        }
        
        // Make the invitation visible in the conversation view (even if it was accepted).
        for (id delegate in self.conversationService.delegates) {
            if ([delegate respondsToSelector:@selector(onPopDescriptorWithRequestId:conversation:descriptor:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onPopDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversationImpl descriptor:invitationDescriptor];
                });
            }
        }
    }
    
    return receivedTimestamp;
}

- (void)processRevokeInviteGroup:(nonnull TLConversationImpl *)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ processRevokeInviteGroup: %@ descriptorId: %@", LOG_TAG, conversation, descriptorId);

    // Verify that the descriptor exists and is an invitation.
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (descriptor && [descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
        TLInvitationDescriptor *invitationDescriptor = (TLInvitationDescriptor *)descriptor;
        
        invitationDescriptor.status = TLInvitationDescriptorStatusTypeWithdrawn;
        [invitationDescriptor setDeletedTimestamp:[[NSDate date] timeIntervalSince1970] * 1000];
        [self.serviceProvider updateWithDescriptor:invitationDescriptor];
        
        [self.conversationService deleteConversationDescriptor:invitationDescriptor requestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation];
    }
}

- (nullable TLGroupJoinResult *)processJoinGroupWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode descriptorId:(nonnull TLDescriptorId *)descriptorId publicKey:(nullable NSString *)publicKey {
    DDLogVerbose(@"%@ processJoinGroupWithConversation: %@ groupTwincodeId: %@ memberTwincode: %@ descriptorId: %@ publicKey: %@", LOG_TAG, conversation, groupTwincodeId, memberTwincode, descriptorId, publicKey);
    
    // Find the group.
    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (!groupConversation) {
        return nil;
    }
    
    // Verify that the invitation is still available.
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
        return nil;
    }

    // Verify the invitation is still pending, or, it has the same member and is joined.
    TLInvitationDescriptor *invitationDescriptor = (TLInvitationDescriptor *)descriptor;
    TLInvitationDescriptorStatusType newStatus;
    BOOL invitationChanged = false;
    if (invitationDescriptor.status == TLInvitationDescriptorStatusTypePending) {
        newStatus = TLInvitationDescriptorStatusTypeAccepted;
        invitationDescriptor.memberTwincodeId = memberTwincode.uuid;
        invitationDescriptor.readTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        invitationChanged = true;
        
        // We can receive the same join-group IQ several times and we must accept it if this is the same member.
    } else if (invitationDescriptor.status == TLInvitationDescriptorStatusTypeJoined
               && [memberTwincode.uuid isEqual:invitationDescriptor.memberTwincodeId]) {
        newStatus = TLInvitationDescriptorStatusTypeAccepted;
    } else {
        newStatus = TLInvitationDescriptorStatusTypeWithdrawn;
    }
    
    // If the invitation is accepted, add the member in the group.
    int64_t memberPermissions = groupConversation.joinPermissions;
    TLGroupConversationAddMemberStatusType result;
    NSMutableArray<TLOnJoinGroupMemberInfo*> *members = nil;
    if (newStatus == TLInvitationDescriptorStatusTypeAccepted) {
        
        // If we have an invitation, keep the contactId of the conversation to which the invitation was sent.
        NSUUID *invitedContactId = conversation.contactId;
        members = [[NSMutableArray alloc] init];
        result = [self addMember:groupConversation memberTwincode:memberTwincode permissions:memberPermissions invitedContactId:invitedContactId returnMembers:members propagate:false signedOffTwincodeId:nil signature:nil];
        if (result != TLGroupConversationAddMemberStatusTypeError) {
            newStatus = TLInvitationDescriptorStatusTypeJoined;
        } else {
            memberPermissions = 0;
            newStatus = TLInvitationDescriptorStatusTypeWithdrawn;
            invitationChanged = true;
        }
    } else {
        memberPermissions = 0;
        result = TLGroupConversationAddMemberStatusTypeNoChange;
    }
    
    if (invitationChanged) {
        invitationDescriptor.status = newStatus;
        [self.serviceProvider updateWithDescriptor:invitationDescriptor];
        
        // Notify upper layers that the invitation was changed.
        for (id delegate in self.conversationService.delegates) {
            if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:invitationDescriptor updateType:TLConversationServiceUpdateTypeTimestamps];
                });
            }
        }
    }
    
    // The group is known and a new member joined the group, notify the upper layers.
    if (result == TLGroupConversationAddMemberStatusTypeNewMember) {
        for (id delegate in self.conversationService.delegates) {
            if ([delegate respondsToSelector:@selector(onJoinGroupRequestWithRequestId:group:invitation:memberId:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onJoinGroupRequestWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:groupConversation invitation:invitationDescriptor memberId:memberTwincode.uuid];
                });
            }
        }
    }

    NSString *signature = [self signMemberWithTwincode:groupConversation.subject.twincodeOutbound groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincode.uuid publicKey:publicKey permissions:memberPermissions];
    return [[TLGroupJoinResult alloc] initWithStatus:newStatus inviterMemberTwincode:groupConversation.subject.twincodeOutbound inviterMemberPermissions:groupConversation.permissions memberPermissions:memberPermissions members:members signature:signature];
}

- (nullable TLGroupJoinResult *)processJoinGroupWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode memberPermissions:(int64_t)memberPermissions {
    DDLogVerbose(@"%@ processJoinGroupWithGroupTwincodeId: %@ memberTwincode: %@ memberPermissions: %lld", LOG_TAG, groupTwincodeId, memberTwincode, memberPermissions);
    
    // Find the group.
    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (!groupConversation) {
        return nil;
    }

    NSMutableArray<TLOnJoinGroupMemberInfo*> *members = nil;
    TLGroupConversationAddMemberStatusType result = [self addMember:groupConversation memberTwincode:memberTwincode permissions:memberPermissions invitedContactId:nil returnMembers:members propagate:false signedOffTwincodeId:nil signature:nil];
    if (result == TLGroupConversationAddMemberStatusTypeError) {
        return nil;
    }
    
    // The group is known and a new member joined the group, notify the upper layers.
    if (result == TLGroupConversationAddMemberStatusTypeNewMember) {
        for (id delegate in self.conversationService.delegates) {
            if ([delegate respondsToSelector:@selector(onJoinGroupRequestWithRequestId:group:invitation:memberId:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onJoinGroupRequestWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:groupConversation invitation:nil memberId:memberTwincode.uuid];
                });
            }
        }
    }
    return [[TLGroupJoinResult alloc] initWithStatus:TLInvitationDescriptorStatusTypeJoined inviterMemberTwincode:groupConversation.subject.twincodeOutbound inviterMemberPermissions:groupConversation.permissions memberPermissions:memberPermissions members:members signature:nil];
}

- (void)processRejectJoinGroupWithConversation:(nullable TLConversationImpl *)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ processRejectJoinGroupWithConversation: %@ descriptorId: %@", LOG_TAG, conversation, descriptorId);

    // Verify that the invitation is still available and pending.
    TLDescriptor *descriptor = [self.serviceProvider loadDescriptorWithDescriptorId:descriptorId];
    if (!descriptor || ![descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
        return;
    }

    TLInvitationDescriptor *invitationDescriptor = (TLInvitationDescriptor *)descriptor;
    if (invitationDescriptor.status != TLInvitationDescriptorStatusTypePending) {
        return;
    }

    invitationDescriptor.status = TLInvitationDescriptorStatusTypeWithdrawn;
    invitationDescriptor.readTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    [self.serviceProvider updateWithDescriptor:invitationDescriptor];
        
    // Notify upper layers that the invitation was changed.
    for (id delegate in self.conversationService.delegates) {
        if ([delegate respondsToSelector:@selector(onUpdateDescriptorWithRequestId:conversation:descriptor:updateType:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onUpdateDescriptorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] conversation:conversation descriptor:invitationDescriptor updateType:TLConversationServiceUpdateTypeTimestamps];
            });
        }
    }
}

- (void)processLeaveGroupWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ processLeaveGroupWithGroupTwincodeId: %@ memberTwincodeId: %@", LOG_TAG, groupTwincodeId, memberTwincodeId);

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    BOOL groupDeleted = false;
    BOOL memberDeleted = false;
    if (groupConversation) {
        if ([groupConversation.twincodeOutboundId isEqual:memberTwincodeId]) {
            // We have left the group, finish the process by deleting the group conversation.
            [self deleteGroupConversation:groupConversation];
            groupDeleted = true;
        } else {
            memberDeleted = [self delMember:groupConversation memberTwincodeId:memberTwincodeId];
        }
    }

    if (groupConversation) {
        
        // Report that the member has left the group.
        if (memberDeleted || groupDeleted) {
            for (id delegate in self.conversationService.delegates) {
                if ([delegate respondsToSelector:@selector(onLeaveGroupWithRequestId:group:memberId:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onLeaveGroupWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:groupConversation memberId:memberTwincodeId];
                    });
                }
            }
        }
    }
}

- (void)processOnJoinGroupWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nonnull NSUUID *)groupTwincodeId invitationDescriptor:(nullable TLInvitationDescriptor *)invitationDescriptor inviterTwincode:(nullable TLTwincodeOutbound *)inviterTwincode inviterPermissions:(int64_t)inviterPermissions members:(nullable NSArray<TLOnJoinGroupMemberInfo *> *)members permissions:(int64_t)permissions signature:(nullable NSString *)signature {
    DDLogVerbose(@"%@ processOnJoinGroupWithGroupTwincodeId: %@ invitationDescriptor: %@ signature: %@", LOG_TAG, groupTwincodeId, invitationDescriptor, signature);

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (groupConversation == nil) {
        return;
    }

    TLGroupConversationStateType currentState = groupConversation.state;
    TLTwincodeOutbound *memberTwincode = groupConversation.subject.twincodeOutbound;
    if (currentState == TLGroupConversationStateLeaving && memberTwincode) {
        return;
    }

    BOOL joinStatus;
    if (invitationDescriptor) {
        joinStatus = [groupConversation joinWithPermissions:permissions];
        if (joinStatus) {
            [self.serviceProvider updateGroupConversation:groupConversation];
        }
    } else {
        joinStatus = currentState == TLGroupConversationStateJoined;
    }

    // inviterTwincode can be null for the legacy onJoinGroup().
    if (inviterTwincode) {
        // If we have an invitation, keep the contactId of the conversation to which the invitation was sent.
        [self addMember:groupConversation memberTwincode:inviterTwincode permissions:inviterPermissions invitedContactId:conversation.contactId returnMembers:nil propagate:false signedOffTwincodeId:nil signature:nil];

        TLTwincodeOutbound *previousPeerTwincode = conversation.peerTwincodeOutbound;
        if (previousPeerTwincode && [inviterTwincode isSigned] && memberTwincode) {
            [self.twincodeOutboundService associateTwincodes:memberTwincode previousPeerTwincode:previousPeerTwincode peerTwincode:inviterTwincode];
            [self.cryptoService validateSecretWithTwincode:memberTwincode peerTwincodeOutbound:inviterTwincode];
        }
    }
    if (members) {
        NSUUID *signedOffTwincodeId = inviterTwincode ? inviterTwincode.uuid : nil;
        for (TLOnJoinGroupMemberInfo *member in members) {
            TLGroupJoinOperation *groupOperation = [[TLGroupJoinOperation alloc] initWithConversation:conversation type:TLConversationServiceOperationTypeInvokeAddMember groupTwincodeId:groupTwincodeId memberTwincodeId:member.memberTwincodeId permissions:member.permissions publicKey:member.publicKey signedOffTwincodeId:signedOffTwincodeId signature:signature];

            [self.serviceProvider storeOperation:groupOperation];
            [self.scheduler addOperation:groupOperation conversation:conversation];
        }
    }
                        
    if (joinStatus) {
        if (invitationDescriptor) {
            invitationDescriptor.status = TLInvitationDescriptorStatusTypeJoined;
            [self.serviceProvider updateDescriptorTimestamps:invitationDescriptor];
        }

        // With an invitation, notify upper layers that the join operation is finished.
        // But do this only once when we transition from CREATED to JOINED.
        if (currentState == TLGroupConversationStateCreated) {
            for (id delegate in self.conversationService.delegates) {
                if ([delegate respondsToSelector:@selector(onJoinGroupResponseWithRequestId:group:invitation:)]) {
                    id<TLConversationServiceDelegate> lDelegate = delegate;
                    dispatch_async([self.twinlife twinlifeQueue], ^{
                        [lDelegate onJoinGroupResponseWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:groupConversation invitation:invitationDescriptor];
                    });
                }
            }
        }
    }
}

- (void)processOnJoinGroupWithdrawnWithInvitation:(nonnull TLInvitationDescriptor *)invitationDescriptor {
    DDLogVerbose(@"%@ processOnJoinGroupWithdrawnWithInvitation: %@", LOG_TAG, invitationDescriptor);

    // The join was finally withdrawn, drop the group if it is still waiting to be joined.
    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:invitationDescriptor.groupTwincodeId];
    if (groupConversation != nil && groupConversation.state == TLGroupConversationStateCreated) {
        [self deleteGroupConversation:groupConversation];
    }

    invitationDescriptor.status = TLInvitationDescriptorStatusTypeWithdrawn;
    [self.serviceProvider updateWithDescriptor:invitationDescriptor];
}

- (void)processOnLeaveGroupWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId peerTwincodeId:(nonnull NSUUID *)peerTwincodeId {
    DDLogVerbose(@"%@ processOnLeaveGroupWithGroupTwincodeId: %@ memberTwincodeId: %@ peerTwincodeId: %@", LOG_TAG, groupTwincodeId, memberTwincodeId, peerTwincodeId);
    
    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (!groupConversation) {
        return;
    }
    BOOL groupDeleted = false;
    NSUUID *deletedMemberId = nil;

    // We have left the group, finish the process by deleting the conversation.
    // We have sent a leave-group operation for each peer we know.  We have to wait
    // for all the leave-group operation to proceed and we can delete the conversation
    // only at the end.  If we delete the conversation immediately, some peers will not
    // be informed that we left the group.
    if ([groupConversation.twincodeOutboundId isEqual:memberTwincodeId]) {
        // Delete the member that received this leave-group request.
        BOOL deleted = [self delMember:groupConversation memberTwincodeId:peerTwincodeId];
        if ([groupConversation isEmpty]) {
            [self deleteGroupConversation:groupConversation];
            groupDeleted = true;
        }
        if (deleted) {
            deletedMemberId = peerTwincodeId;
        }

        // We can delete the member only when it acknowledged the leave-group operation.
    } else if ([memberTwincodeId isEqual:peerTwincodeId]) {
        BOOL deleted = [self delMember:groupConversation memberTwincodeId:memberTwincodeId];
        if (deleted) {
            deletedMemberId = memberTwincodeId;
        }

    } else {
        // We informed another member that `memberTwincodeId` has left the group.
    }
    
    // A member was removed, notify upper layers.
    if (deletedMemberId && !groupDeleted) {
        for (id delegate in self.conversationService.delegates) {
            if ([delegate respondsToSelector:@selector(onLeaveGroupWithRequestId:group:memberId:)]) {
                id<TLConversationServiceDelegate> lDelegate = delegate;
                dispatch_async([self.twinlife twinlifeQueue], ^{
                    [lDelegate onLeaveGroupWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] group:groupConversation memberId:deletedMemberId];
                });
            }
        }
    }
}

- (void)processUpdateGroupMemberWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId permissions:(int64_t)permissions {
    DDLogVerbose(@"%@ processUpdateGroupMemberWithConversation: %@ groupTwincodeId: %@ memberTwincodeId: %@ permissions: %lld", LOG_TAG, conversation, groupTwincodeId, memberTwincodeId, permissions);

    TLGroupConversationImpl *groupConversation = [self.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    if (groupConversation && [conversation isGroup] && [conversation hasPermissionWithPermission:TLPermissionTypeUpdateMember]) {
        if ([memberTwincodeId isEqual:groupConversation.twincodeOutboundId]) {
            groupConversation.permissions = permissions;
            [self.serviceProvider updateGroupConversation:groupConversation];
        } else {
            TLGroupMemberConversationImpl *member = [groupConversation getMemberWithTwincodeId:memberTwincodeId];
            if (member) {
                member.permissions = permissions;
                [self.serviceProvider updateConversation:member];
            }
        }
    }
}

#pragma mark - internal operations

/// Verify the member signature before adding it to the group.
- (TLBaseServiceErrorCode)verifySignatureWithTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId publicKey:(nonnull NSString *)publicKey permissions:(int64_t)permissions signature:(nonnull NSString *)signature {
    DDLogVerbose(@"%@ verifySignatureWithTwincode: %@ groupTwincodeId: %@ memberTwincodeId: %@ publicKey: %@ permissions: %lld signature: %@", LOG_TAG, twincodeOutbound, groupTwincodeId, memberTwincodeId, publicKey, permissions, signature);
    
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
    
    [binaryEncoder writeUUID:groupTwincodeId];
    [binaryEncoder writeUUID:memberTwincodeId];
    [binaryEncoder writeString:publicKey];
    [binaryEncoder writeLong:permissions];

    return [self.cryptoService verifyContentWithTwincode:twincodeOutbound content:data signature:signature];
}

/// Sign the new member that joined the group so that other members can verify the new member's public key and trust it.
- (nullable NSString *)signMemberWithTwincode:(nullable TLTwincodeOutbound *)twincodeOutbound groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId publicKey:(nullable NSString *)publicKey permissions:(int64_t)permissions {
    DDLogVerbose(@"%@ signMemberWithTwincode: %@ groupTwincodeId: %@ memberTwincodeId: %@ publicKey: %@ permissions: %lld", LOG_TAG, twincodeOutbound, groupTwincodeId, memberTwincodeId, publicKey, permissions);
    
    if (!publicKey || !twincodeOutbound) {
        return nil;
    }
    
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
    
    [binaryEncoder writeUUID:groupTwincodeId];
    [binaryEncoder writeUUID:memberTwincodeId];
    [binaryEncoder writeString:publicKey];
    [binaryEncoder writeLong:permissions];
    DDLogError(@"%@ sign: %@ groupTwincodeId: %@ memberTwincodeId: %@ publicKey: %@ permissions: %lld", LOG_TAG, twincodeOutbound, groupTwincodeId, memberTwincodeId, publicKey, permissions);

    return [self.cryptoService signContentWithTwincode:twincodeOutbound content:data];
}

- (TLGroupConversationAddMemberStatusType)addMember:(nonnull TLGroupConversationImpl *)groupConversation memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode permissions:(int64_t)permissions invitedContactId:(nullable NSUUID *)invitedContactId returnMembers:(nullable NSMutableArray<TLOnJoinGroupMemberInfo*> *)returnMembers propagate:(BOOL)propagate signedOffTwincodeId:(nullable NSUUID *)signedOffTwincodeId signature:(nullable NSString *)signature {

    TLTwincodeOutbound *twincodeOutbound = groupConversation.subject.twincodeOutbound;
    if (groupConversation.state == TLGroupConversationStateLeaving || !twincodeOutbound) {
        return TLGroupConversationAddMemberStatusTypeError;
    }
    
    NSUUID *memberTwincodeId = memberTwincode.uuid;
    if ([memberTwincodeId isEqual:twincodeOutbound.uuid]) {
        return TLGroupConversationAddMemberStatusTypeNoChange;
    }

    TLGroupMemberConversationImpl *memberConversation = [groupConversation getMemberWithTwincodeId:memberTwincodeId];

    TLGroupConversationAddMemberStatusType result;
    if (!memberConversation) {
        memberConversation = [self.serviceProvider createGroupMemberWithConversation:groupConversation memberTwincodeId:memberTwincodeId permissions:permissions invitedContactId:invitedContactId];
        if (!memberConversation) {
            // A limit is reached on the number of members, refuse the join.
            // The caller will get back a WITHDRAWN status.
            return TLGroupConversationAddMemberStatusTypeError;
        }
        result = TLGroupConversationAddMemberStatusTypeNewMember;
    } else {
        // Save the updated group member in the database.
        if (memberConversation.permissions != permissions) {
            memberConversation.permissions = permissions;
            [self.serviceProvider updateConversation:memberConversation];
        }
        result = TLGroupConversationAddMemberStatusTypeNoChange;
    }

    if (returnMembers) {
        NSMutableDictionary<NSUUID*,TLGroupMemberConversationImpl*> *otherMembers = [groupConversation listMembers];
        
        for (NSUUID *memberId in otherMembers) {
            TLGroupMemberConversationImpl *member = otherMembers[memberId];
            TLTwincodeOutbound *peerTwincode = member.peerTwincodeOutbound;
            if (peerTwincode && ![peerTwincode.uuid isEqual:memberTwincodeId] && ![member isLeaving]) {
                NSString *publicKey = [self.cryptoService getPublicKeyWithTwincode:peerTwincode];
                    
                [returnMembers addObject:[[TLOnJoinGroupMemberInfo alloc] initWithTwincodeId:peerTwincode.uuid publicKey:publicKey permissions:member.permissions]];
            }
        }
    }
    
    // This is a new member and we must propagate ourselves to him so that he knows us:
    // - for a legacy member, the twincode is not signed and we must do the join through a P2P connexion,
    // - for a signed member, we can invoke that member's twincode with secureInvokeTwincode().
    if (propagate && result == TLGroupConversationAddMemberStatusTypeNewMember) {
        NSString *publicKey = [self.cryptoService getPublicKeyWithTwincode:twincodeOutbound];

        TLGroupJoinOperation *groupOperation = [[TLGroupJoinOperation alloc] initWithConversation:memberConversation type:([memberTwincode isSigned] ? TLConversationServiceOperationTypeInvokeJoinGroup : TLConversationServiceOperationTypeJoinGroup) groupTwincodeId:groupConversation.peerTwincodeOutboundId memberTwincodeId:twincodeOutbound.uuid permissions:groupConversation.permissions publicKey:publicKey signedOffTwincodeId:signedOffTwincodeId signature:signature];
            
        [self.serviceProvider storeOperation:groupOperation];
        [self.scheduler addOperation:groupOperation conversation:memberConversation];
    }
    
    return result;
}

- (BOOL)delMember:(nonnull TLGroupConversationImpl *)groupConversation memberTwincodeId:(NSUUID *)memberTwincodeId {
    
    TLGroupMemberConversationImpl *member = [groupConversation delMemberWithTwincodeId:memberTwincodeId];
    if (!member) {
        return false;
    }

    // Delete the conversation associated with the member that is removed.
    [self.conversationService deleteConversation:member];
    return true;
}

- (void)deleteGroupConversation:(TLGroupConversationImpl *)groupConversation {
    DDLogVerbose(@"%@ deleteGroupConversation: %@", LOG_TAG, groupConversation);
    
    // Delete the conversation we had for each member.
    while (true) {
        TLGroupMemberConversationImpl *peer = [groupConversation firstMember];
        if (!peer) {
            break;
        }
        [self.conversationService deleteConversation:peer];
    }
    [self.serviceProvider deleteConversationWithConversation:groupConversation];
    [self.conversationService deleteFilesWithConversation:groupConversation];
    
    // The group conversation was deleted, notify upper layers.
    for (id delegate in self.conversationService.delegates) {
        if ([delegate respondsToSelector:@selector(onDeleteGroupConversationWithRequestId:conversationId:groupId:)]) {
            id<TLConversationServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDeleteGroupConversationWithRequestId:0 conversationId:groupConversation.uuid groupId:groupConversation.contactId];
            });
        }
    }
}

@end

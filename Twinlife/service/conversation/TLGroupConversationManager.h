/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationService.h"

@class TLOnJoinGroupMemberInfo;

typedef enum {
    TLGroupConversationAddMemberStatusTypeError,
    TLGroupConversationAddMemberStatusTypeNoChange,
    TLGroupConversationAddMemberStatusTypeNewMember
} TLGroupConversationAddMemberStatusType;

//
// Interface: TLGroupJoinResult ()
//

@interface TLGroupJoinResult : NSObject

@property (readonly) TLInvitationDescriptorStatusType status;
@property (readonly) int64_t memberPermissions;
@property (readonly, nullable) NSMutableArray<TLOnJoinGroupMemberInfo *> *members;
@property (readonly, nullable) TLTwincodeOutbound *inviterMemberTwincode;
@property (readonly) int64_t inviterMemberPermissions;
@property (readonly, nullable) NSString *signature;

- (nonnull instancetype)initWithStatus:(TLInvitationDescriptorStatusType)status inviterMemberTwincode:(nullable TLTwincodeOutbound *)inviterMemberTwincode inviterMemberPermissions:(int64_t)inviterMemberPermissions memberPermissions:(int64_t)memberPermissions members:(nullable NSMutableArray<TLOnJoinGroupMemberInfo *> *)members signature:(nullable NSString *)signature;

@end

//
// Interface: TLConversationService ()
//

@class TLGroupConversationImpl;
@class TLConversationImpl;
@class TLConversationServiceProvider;
@class TLConversationService;
@class TLConversationServiceScheduler;
@class TLGroupMemberConversationImpl;
@class TLCryptoService;
@class TLTwincodeOutboundService;
@class TLGroupJoinOperation;
@class TLGroupLeaveOperation;
@class TLSecureRosterService;

@interface TLGroupConversationManager : NSObject

@property (readonly, nonnull) TLConversationService *conversationService;
@property (readonly, nonnull) TLConversationServiceProvider *serviceProvider;
@property (readonly, nonnull) TLConversationServiceScheduler *scheduler;
@property (readonly, nonnull) TLTwinlife *twinlife;
@property (readonly, nonnull) TLCryptoService *cryptoService;
@property (readonly, nonnull) TLTwincodeOutboundService *twincodeOutboundService;
@property (readonly, nonnull) TLSecureRosterService *secureRosterService;

- (nonnull instancetype)initWithConversationService:(nonnull TLConversationService *)conversationService;

- (void)onTwinlifeReady;

- (nullable id<TLGroupConversation>)createGroupConversationWithSubject:(nonnull id<TLRepositoryObject>)subject owner:(BOOL)owner;

- (TLBaseServiceErrorCode)inviteGroupWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation group:(nonnull id<TLRepositoryObject>)group name:(nonnull NSString *)name;

- (TLBaseServiceErrorCode)withdrawInviteGroupWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitationDescriptor *)invitation;

- (TLBaseServiceErrorCode)joinGroupWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId group:(nullable id<TLRepositoryObject>)group;

- (TLBaseServiceErrorCode)registeredGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group adminTwincodeOutbound:(nonnull TLTwincodeOutbound *)adminTwincodeOutbound adminPermissions:(long)adminPermissions permissions:(long)permissions;

- (TLBaseServiceErrorCode)leaveGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group memberTwincodeId:(nonnull NSUUID*)memberTwincodeId;

- (TLBaseServiceErrorCode)setPermissionsWithSubject:(nullable id<TLRepositoryObject>)group memberTwincodeId:(nonnull NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

/// Update the group according to a new list of members provided by the secure roster service.
/// From this list we have to:
/// - identify and record new members,
/// - update existing members (mostly permissions since twincodes and public key don't change)
/// - remove members that are not in the new list.
/// @param group the group to refresh.
/// @param members the list of roster members as known and reported by the server.
/// @param memberTwincodes the map of twincodes for these members.
/// @return SUCCESS if the refresh operation succeeded.
- (TLBaseServiceErrorCode)refreshWithGroup:(nonnull id<TLRepositoryObject>)group members:(nonnull NSArray<TLRosterMember *> *)members memberTwincodes:(nonnull NSDictionary<NSUUID *, TLTwincodeOutbound *> *)memberTwincodes;

- (void)deleteGroupConversation:(nonnull TLGroupConversationImpl *)groupConversation;

- (TLGroupConversationAddMemberStatusType)addMember:(nonnull TLGroupConversationImpl *)groupConversation memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode permissions:(int64_t)permissions invitedContactId:(nullable NSUUID *)invitedContactId returnMembers:(nullable NSMutableArray<TLOnJoinGroupMemberInfo*> *)returnMembers propagate:(BOOL)propagate useSecureRoster:(BOOL)useSecureRoster signedOffTwincodeId:(nullable NSUUID *)signedOffTwincodeId signature:(nullable NSString *)signature;

- (BOOL)delMember:(nonnull TLGroupConversationImpl *)groupConversation memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (TLBaseServiceErrorCode)invokeJoinGroupWithConversation:(nonnull TLConversationImpl *)conversation groupOperation:(nonnull TLGroupJoinOperation *)groupOperation;

- (TLBaseServiceErrorCode)invokeDeleteRosterMemberWithConversation:(nonnull TLConversationImpl *)conversation groupOperation:(nonnull TLGroupLeaveOperation *)groupOperation;

- (TLBaseServiceErrorCode)invokeLeaveGroupWithConversation:(nonnull TLConversationImpl *)conversation groupOperation:(nonnull TLGroupLeaveOperation *)groupOperation;

- (TLBaseServiceErrorCode)invokeAddMemberWithConversation:(nonnull TLConversationImpl *)conversation groupOperation:(nonnull TLGroupJoinOperation *)groupOperation;

- (int64_t)processInviteGroupWithConnection:(nonnull TLConversationConnection *)connection invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor;

- (void)processRevokeInviteGroup:(nonnull TLConversationImpl *)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)processJoinGroupAsyncWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode descriptorId:(nonnull TLDescriptorId *)descriptorId publicKey:(nullable NSString *)publicKey withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLGroupJoinResult *_Nullable joinResult))block;

- (nullable TLGroupJoinResult *)processJoinGroupLegacyWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (nullable TLGroupJoinResult *)processJoinGroupLegacyWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincode:(nonnull TLTwincodeOutbound *)memberTwincode memberPermissions:(int64_t)memberPermissions;

- (void)processRejectJoinGroupWithConversation:(nullable TLConversationImpl *)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)processLeaveGroupWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (void)processOnJoinGroupWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nonnull NSUUID *)groupTwincodeId invitationDescriptor:(nullable TLInvitationDescriptor *)invitationDescriptor inviterTwincode:(nullable TLTwincodeOutbound *)inviterTwincode inviterPermissions:(int64_t)inviterPermissions members:(nullable NSArray<TLOnJoinGroupMemberInfo *> *)members permissions:(int64_t)permissions signature:(nullable NSString *)signature;

- (void)processOnJoinGroupWithdrawnWithInvitation:(nonnull TLInvitationDescriptor *)invitationDescriptor ;

- (void)processOnLeaveGroupWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId peerTwincodeId:(nonnull NSUUID *)peerTwincodeId;

- (void)processUpdateGroupMemberWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

@end

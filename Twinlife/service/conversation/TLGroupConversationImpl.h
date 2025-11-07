/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationService.h"
#import "TLPeerConnectionService.h"
#import "TLSerializer.h"
#import "TLConversationImpl.h"
#import "TLGroupMemberConversationImpl.h"
#import "TLDatabaseService.h"

@class TLDescriptorId;

//
// Interface: TLGroupConversationFactory
//

@interface TLGroupConversationFactory : NSObject <TLDatabaseObjectFactory>

@property (readonly, nonnull) TLDatabaseService *database;

- (nonnull instancetype)initWithDatabase:(nonnull TLDatabaseService *)database;

@end

//
// Interface: TLGroupConversationObject ()
//

@interface TLGroupConversationImpl : NSObject<TLGroupConversation>

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property (readonly, nonnull) id<TLRepositoryObject> subject;
@property (readonly) int64_t creationDate;
@property int flags;
@property (readonly, nonnull) TLGroupMemberConversationImpl *incomingConversation;
@property int64_t permissions;
@property int64_t joinPermissions;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier conversationId:(nonnull NSUUID *)conversationId subject:(nonnull id<TLRepositoryObject>)subject creationDate:(int64_t)creationDate resourceId:(nonnull NSUUID *)resourceId permissions:(int64_t)permissions joinPermissions:(int64_t)joinPermissions flags:(int)flags;

- (void)updateWithPermissions:(int64_t)permissions joinPermissions:(int64_t)joinPermissions flags:(int)flags;

/// Get the number of active members (we exclude the members that are leaving but still in our list).
- (long)activeMemberCount;

/// Get a copy of the list of known members.
- (nonnull NSMutableDictionary<NSUUID*,TLGroupMemberConversationImpl*> *)listMembers;

- (void)rejoin;

- (nonnull TLGroupMemberConversationImpl *)addMemberWithConversation:(nonnull TLGroupMemberConversationImpl *)member;

- (nullable TLGroupMemberConversationImpl *)delMemberWithTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (nullable TLGroupMemberConversationImpl *)getMemberWithTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (nullable TLGroupMemberConversationImpl *)leaveGroupWithTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (nullable TLGroupMemberConversationImpl *)firstMember;

- (nullable TLGroupMemberConversationImpl *)getConversationWithId:(int64_t)conversationId;

/// Update the group state to join it with the given permissions.
- (BOOL)joinWithPermissions:(int64_t)permissions;

- (BOOL)isEmpty;

/// Get the list of conversations to which some operation must be made.  When the `sendTo` is
/// defined, we only return the conversation for the matching group member.
- (nonnull NSMutableArray<TLConversationImpl *> *)getConversations:(nullable NSUUID *)sendTo;

@end

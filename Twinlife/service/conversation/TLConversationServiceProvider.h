/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDatabaseServiceProvider.h"
#import "TLConversationService.h"

//
// Interface: TLConversationServiceProvider
//

typedef enum {
    TLConversationServiceProviderModeStore,
    TLConversationServiceProviderModeUpdate,
    TLConversationServiceProviderModeStoreOrUpdate
} TLConversationServiceProviderMode;

typedef enum {
    TLConversationServiceProviderResultStored,
    TLConversationServiceProviderResultUpdated,
    TLConversationServiceProviderResultError
} TLConversationServiceProviderResult;

@class TLTwinlife;
@protocol TLConversation;
@class TLConversationImpl;
@class TLGroupConversationImpl;
@class TLGroupMemberConversationImpl;
@class TLDescriptor;
@class TLConversationServiceOperation;
@class TLConversationService;
@class TLPushFileOperation;

@interface TLConversationServiceProvider : TLDatabaseServiceProvider <TLConversationsCleaner>

+ (int)fromDescriptorType:(TLDescriptorType)type;

+ (TLDescriptorAnnotationType)toDescriptorAnnotationType:(int)type;

- (nonnull instancetype)initWithService:(nonnull TLConversationService *)service database:(nonnull TLDatabaseService *)database;

- (nonnull NSMutableArray<id<TLConversation>> *)listConversationsWithFilter:(nullable TLFilter *)filter;

/// Load a conversation from the id, databaseId, UUID, subject, identity twincode.
- (nullable id <TLConversation>)loadConversationWithId:(int64_t)conversationId;

- (nullable id <TLConversation>)loadConversationWithSubject:(nonnull id<TLRepositoryObject>)subject;

/// Create a new conversation for a contact.
/// If the contact already has a conversation, return it.
- (nullable TLConversationImpl *)createConversationWithSubject:(nonnull id<TLRepositoryObject>)subject;

/// Create a group conversation object and insert it in the database.  Before inserting the
/// new group conversation, verify in the database if a group conversation existed for the
/// repository object.  It is loaded and used if necessary.
- (nullable TLGroupConversationImpl *)createGroupConversationWithSubject:(nonnull id<TLRepositoryObject>)subject isOwner:(BOOL)isOwner;

/// Create a group member conversation object and insert it in the database.  Before inserting the
/// new group member conversation, check that the group member with the given twincode is not already
/// inserted and update and return it if necessary.  The member twincode may not be known yet and we
/// have to insert an entry in the database and mark it for the TwincodeOutboundService to fetch the
/// attributes on the server later on.
- (nullable TLGroupMemberConversationImpl *)createGroupMemberWithConversation:(nonnull TLGroupConversationImpl *)groupConversation memberTwincodeId:(nonnull NSUUID *)memberTwincodeId permissions:(int64_t)permissions invitedContactId:(nullable NSUUID *)invitedContactId;

/// Find the group conversation associated with the group twincode.
- (nullable TLGroupConversationImpl *)findGroupWithTwincodeId:(nonnull NSUUID *)twincodeId;

- (void)updateConversation:(nonnull TLConversationImpl *)conversation;

- (void)updateConversation:(nonnull TLConversationImpl *)conversation peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound;

- (void)updateGroupConversation:(nonnull TLGroupConversationImpl *)conversation;

- (void)deleteConversationWithConversation:(nonnull id <TLConversation>)conversation;

/// Get the list of pending invitations for the group.
- (nonnull NSMutableDictionary<NSUUID *, TLInvitationDescriptor *> *)listPendingInvitationsWithGroup:(nonnull id<TLRepositoryObject>)group;

/// Identify a list of descriptors that must be removed for the conversation and before the given date.
- (nullable NSDictionary<NSUUID *, TLDescriptorId *> *)listDescriptorsToDeleteWithConversation:(nonnull id<TLConversation>)conversation twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId resetDate:(int64_t)resetDate;

- (nullable NSArray<TLConversationDescriptorPair *> *)listLastConversationDescriptorsWithFilter:(nullable TLFilter *)filter callsMode:(TLDisplayCallsMode)callsMode;

- (nullable NSArray<TLConversationDescriptorPair *> *)searchDescriptorsWithConversations:(nonnull NSArray<id<TLConversation>> *)conversations searchText:(nonnull NSString *)searchText beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors;

/// Delete the descriptors that have been identified by listDescriptorsToDeleteWithConversation. When keepMediaMessages is set, we keep the messages,
/// images, video, invitation descriptors.
- (BOOL)deleteDescriptorsWithMap:(nonnull NSDictionary<NSUUID *, TLDescriptorId *> *)descriptorList conversation:(nonnull id<TLConversation>)conversation keepMediaMessages:(BOOL)keepMediaMessages  deletedOperations:(nonnull NSMutableArray<NSNumber *> *)deletedOperations;

/// Delete the media descriptors before a given date and return 3 lists:
/// - [0]: descriptors that are removed and can be removed immediately without creating any operation,
/// - [1]: descriptors created by the current conversation which must be removed on the peer,
/// - [2]: descriptors owned by the peer and which we must inform we have removed.
- (nonnull NSMutableArray<NSMutableSet<TLDescriptorId *> *> *)deleteMediaDescriptorsWithConversation:(nonnull id<TLConversation>)conversation beforeDate:(int64_t)beforeDate resetDate:(int64_t)resetDate;

/// The peer has cleared the descriptors on its side and we have to mark those descriptors as deleted by the peer.
/// If some descriptors are marked DELETED, it means we were waiting for the peer deletion and we can remove them.
/// To notify upper layers, we return a list of DescriptorId that are really deleted now. When keepMediaMessages is set, we don't mark
/// the messages, images, video and invitations because the peer has kept same in the conversation (see deleteDescriptorsWithMap).
- (nullable NSSet<TLDescriptorId *> *)markDescriptorDeletedWithConversation:(nonnull id<TLConversation>)conversation clearDate:(int64_t)clearDate resetDate:(int64_t)resetDate twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId keepMediaMessages:(BOOL)keepMediaMessages;

/// Load the descriptor annotations which are local (ie, created by current user, ie with a  NULL peerTwincodeOutboundId) and associated with the descriptor.
- (nonnull NSMutableArray<TLDescriptorAnnotation *> *)loadLocalAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversation:(nonnull id<TLConversation>)conversation;

/// Set the descriptor annotations for a given descriptor and annotated by a given peer twincode.
/// Existing annotations of the given peer twincode are either updated or removed.
/// Return true if the descriptor was modified (some annotations added, updated or removed).
- (BOOL)setAnnotationsWithDescriptor:(nonnull TLDescriptor *)descriptor peerTwincodeOutboundId:(nonnull NSUUID *)peerTwincodeOutboundId annotations:(nonnull NSArray<TLDescriptorAnnotation *> *)annotations  annotatingUsers:(nonnull NSMutableSet<TLTwincodeOutbound *> *)annotatingUsers;

/// Set the descriptor annotation for the current user to a new value.
/// The descriptor annotation is either inserted or updated if a previous annotation from the user was set.
/// Return true if the annotation was inserted or updated and false if it existed and was not modified.
- (BOOL)setAnnotationWithDescriptor:(nonnull TLDescriptor *)descriptor type:(TLDescriptorAnnotationType)type value:(int)value;

/// Delete the descriptor annotation from current user only.
/// Return true if an annotation was removed and false if there was not change.
- (BOOL)deleteAnnotationWithDescriptor:(nonnull TLDescriptor *)descriptor type:(TLDescriptorAnnotationType)type;

/// Toggle the descriptor annotation for current user only:
/// - If the annotation with the value exists, it is removed.
/// - If the annotation with the value does not exist, it is either inserted or updated.
/// Return true if the annotation was inserted or updated and false if it existed and was not modified.
- (BOOL)toggleAnnotationWithDescriptor:(nonnull TLDescriptor *)descriptor type:(TLDescriptorAnnotationType)type value:(int)value;

/// Get the descriptor annotation indexed by the owner twincode id.
- (nullable NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair *> *)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (int64_t)lockConversation:(nonnull TLConversationImpl *)conversation lockIdentifier:(int)lockIdentifier now:(int64_t)now;

- (int64_t)unlockConversation:(nonnull TLConversationImpl *)conversation lockIdentifier:(int)lockIdentifier connected:(BOOL)connected;

- (int64_t)newSequenceId;

/// Get the list of twincodes associated with all descriptors matching the condition.
/// A twincode appears only once if the user has send at least one message.
- (nonnull NSSet<NSUUID *> *)listDescriptorTwincodesWithConversation:(nullable id<TLConversation>)conversation descriptorType:(TLDescriptorType)descriptorType beforeTimestamp:(int64_t)beforeTimestamp;

- (nullable TLDescriptor *)loadDescriptorWithId:(int64_t)descriptorId;

- (nullable TLDescriptor *)loadDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (nonnull NSArray<TLDescriptor *> *)listDescriptorWithConversation:(nullable id<TLConversation>)conversation types:(nullable NSArray<NSNumber *> *)types callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors;

- (nonnull NSArray<TLDescriptor *> *)listDescriptorWithDescriptorIds:(nonnull NSArray<NSNumber *> *)descriptorIds;

/// Create a new descriptor for the conversation.  The createBlock is called with the
/// assigned descriptor id, new sequence id and the conversation id.  It must create the final
/// descriptor instance and populate it with values.  The method is called within a database transaction.
- (nullable TLDescriptor *)createDescriptorWithConversation:(nonnull id<TLConversation>)conversation createBlock:(nonnull TLDescriptor * _Nullable (^)(int64_t descriptorId, int64_t conversationId, int64_t sequenceId))block;

/// Create an invitation for the group and check if there are enough room for the new member.
- (nullable TLInvitationDescriptor *)createInvitationWithConversation:(nonnull id<TLConversation>)conversation group:(nonnull id<TLGroupConversation>)group name:(nonnull NSString *)name publicKey:(nullable NSString *)publicKey;

- (TLConversationServiceProviderResult)insertOrUpdateDescriptorWithConversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor;

/// Update the descriptor content, flags and timestamps.
- (void)updateWithDescriptor:(nonnull TLDescriptor *)descriptor;

/// Update the invitation descriptor content, flags and timestamps when it is accepted.
/// This is special because we create a row in the `invitation` table between the invitation
/// descriptor and the group conversation.
- (void)acceptInvitationWithDescriptor:(nonnull TLInvitationDescriptor *)descriptor groupConversation:(nonnull TLGroupConversationImpl *)groupConversation;

- (void)updateDescriptorTimestamps:(nonnull TLDescriptor *)descriptor;

- (void)deleteDescriptorWithDescriptor:(nonnull TLDescriptor *)descriptor conversation:(nonnull id<TLConversation>)conversation;

- (void)deleteDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversation:(nonnull id<TLConversation>)conversation;

/// Count the number of descriptors for this conversation.
- (int)countDescriptorsWithConversation:(nonnull id<TLConversation>)conversation;

- (nullable NSMutableDictionary<TLDatabaseIdentifier *, NSMutableArray<TLConversationServiceOperation *> *> * )loadOperations;

- (nonnull NSMutableArray<TLConversationServiceOperation *> *)loadOperationsWithCid:(int64_t)cid;

- (void)storeOperation:(nonnull TLConversationServiceOperation *)operation;

/// Store a list of operations within a same database transaction.
- (void)storeOperations:(nonnull NSMapTable<TLConversationImpl *, NSObject *> *)operations;

- (void)updateFileOperation:(nonnull TLPushFileOperation *)operation;

- (void)deleteOperationWithOperationId:(int64_t)operationId;

@end

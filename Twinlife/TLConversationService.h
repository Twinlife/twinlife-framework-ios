/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"
#import "TLSerializer.h"
#import "TLPeerConnectionService.h"
#import "TLDatabase.h"

typedef enum {
    TLPermissionTypeNone = -1,
    TLPermissionTypeInviteMember = 0,
    TLPermissionTypeUpdateMember,
    TLPermissionTypeRemoveMember,
    TLPermissionTypeSendMessage,
    TLPermissionTypeSendImage,
    TLPermissionTypeSendAudio,
    TLPermissionTypeSendVideo,
    TLPermissionTypeSendFile,
    TLPermissionTypeDeleteMessage,
    TLPermissionTypeDeleteImage,
    TLPermissionTypeDeleteAudio,
    TLPermissionTypeDeleteVideo,
    TLPermissionTypeDeleteFile,
    TLPermissionTypeResetConversation,
    TLPermissionTypeSendGeolocation,
    TLPermissionTypeSendTwincode,
    TLPermissionTypeReceiveMessage,
    TLPermissionTypeSendCommand
} TLPermissionType;

typedef enum {
    TLGroupMemberFilterTypeAllMembers,
    TLGroupMemberFilterTypeJoinedMembers
} TLGroupMemberFilterType;

@protocol TLGroupConversation;
@protocol TLRepositoryObject;
@class TLTwincodeOutbound;
@class TLFilter;

//
// Interface: TLConversation
//

@protocol TLConversation <TLDatabaseObject>
@required
@property (readonly, nonnull) NSUUID *uuid;
@property (readonly, nonnull) NSUUID *twincodeOutboundId;
@property (readonly, nonnull) NSUUID *peerTwincodeOutboundId;
@property (readonly, nonnull) NSUUID *twincodeInboundId;
@property (readonly, nonnull) id<TLRepositoryObject> subject;

- (nonnull NSUUID *)contactId;

- (BOOL)isActive;

- (BOOL)isGroup;

- (BOOL)isConversationWithUUID:(nonnull NSUUID *)id;

- (BOOL)hasPermissionWithPermission:(TLPermissionType)permission;

- (BOOL)hasPeer;

- (nullable TLTwincodeOutbound *)peerTwincodeOutbound;

@end

//
// Interface: TLGroupMemberConversation
//

@protocol TLGroupMemberConversation <TLConversation>
@required

- (nonnull NSUUID*)memberTwincodeId;

- (nullable NSUUID*)invitedContactId;

- (BOOL)isLeaving;

- (nonnull id<TLGroupConversation>)groupConversation;

@end

//
// Interface: TLGroupConversation
//
@class TLDescriptorId;

typedef enum  {
    TLGroupConversationStateCreated,
    TLGroupConversationStateJoined,
    TLGroupConversationStateLeaving,
    TLGroupConversationStateDeleted
} TLGroupConversationStateType;

@protocol TLGroupConversation <TLConversation>
@required

- (nonnull NSMutableArray<id<TLGroupMemberConversation>>*)groupMembersWithFilter:(TLGroupMemberFilterType)filter;

- (TLGroupConversationStateType) state;

- (int64_t)joinPermissions;

@end

//
// Interface: TLDescriptorId
//

@interface TLDescriptorId : NSObject

@property long id;
@property (readonly, nonnull) NSUUID *twincodeOutboundId;
@property (readonly) int64_t sequenceId;

- (nonnull instancetype)initWithId:(long)id twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId;

- (nullable instancetype)initWithString:(nullable NSString *)value;

- (nonnull NSString *)toString;

@end

//
// Interface: TLDescriptorAnnotation
//

typedef enum {
    TLDescriptorAnnotationTypeInvalid,    /// Null annotation
    TLDescriptorAnnotationTypeForward,    /// The descriptor is the result of a forward.
    TLDescriptorAnnotationTypeForwarded,  /// The descriptor was forwarded.
    TLDescriptorAnnotationTypeSave,       /// The descriptor was saved.
    TLDescriptorAnnotationTypeLike,       /// The descriptor is marked by a like annotation: the getValue() returns the like code.
    TLDescriptorAnnotationTypePoll        /// The descriptor is marked by an answer of a poll: the getValue() gives the vote entry.
} TLDescriptorAnnotationType;

@interface TLDescriptorAnnotation : NSObject

@property (readonly) TLDescriptorAnnotationType type;
@property (readonly) int count;
@property (readonly) int value;

@end

//
// Interface: TLDescriptor
//

typedef enum {
    TLDescriptorTypeDescriptor,
    TLDescriptorTypeObjectDescriptor,
    TLDescriptorTypeTransientObjectDescriptor,
    TLDescriptorTypeFileDescriptor,
    TLDescriptorTypeImageDescriptor,
    TLDescriptorTypeAudioDescriptor,
    TLDescriptorTypeVideoDescriptor,
    TLDescriptorTypeNamedFileDescriptor,
    TLDescriptorTypeInvitationDescriptor,
    TLDescriptorTypeGeolocationDescriptor,
    TLDescriptorTypeTwincodeDescriptor,
    TLDescriptorTypeCallDescriptor,
    TLDescriptorTypeClearDescriptor
} TLDescriptorType;

@interface TLDescriptor : NSObject

@property (readonly, nonnull) TLDescriptorId *descriptorId;
@property (readonly) int64_t updatedTimestamp;
@property (readonly) int64_t sentTimestamp;
@property (readonly) int64_t receivedTimestamp;
@property (readonly) int64_t readTimestamp;
@property (readonly) int64_t deletedTimestamp;
@property (readonly) int64_t peerDeletedTimestamp;
@property (readonly) int64_t expireTimeout;
@property (readonly, nullable) NSUUID *sendTo;
@property (readonly, nullable) TLDescriptorId *replyTo;
@property (nullable) TLDescriptor *replyToDescriptor;

- (int64_t)createdTimestamp;

- (nonnull NSString *)getDescriptorKey;

- (TLDescriptorType)getType;

- (int64_t)expireTimestamp;

/// Returns YES if this descriptor has expired.
- (BOOL)isExpired;

/// Returns YES if the object is the same descriptor.
- (BOOL)isEqual:(nullable id)object;

/// Returns YES if the object is the same descriptor.
- (BOOL)isEqualDescriptor:(nullable TLDescriptor *)descriptor;

/// Returns YES if the descriptor was emitted by the given twincode.
- (BOOL)isTwincodeOutbound:(nonnull NSUUID *)twincodeOutbound;

/// Get the annotation of a given type.
- (nullable TLDescriptorAnnotation *)getDescriptorAnnotationWithType:(TLDescriptorAnnotationType)type;

/// Get the list of annotations of a given type.
- (nullable NSArray<TLDescriptorAnnotation *> *)getDescriptorAnnotationsWithType:(TLDescriptorAnnotationType)type;

@end

//
// Interface: TLObjectDescriptor
//

@interface TLObjectDescriptor : TLDescriptor

@property (readonly, nonnull) NSString *message;
@property (readonly) BOOL copyAllowed;
@property (readonly) BOOL isEdited;

+ (BOOL)DEFAULT_COPY_ALLOWED;

@end

//
// Interface: TLTransientObjectDescriptor
//

@interface TLTransientObjectDescriptor : TLDescriptor

@property (readonly, nonnull) NSObject *object;

@end

//
// Interface: TLFileDescriptor
//

@interface TLFileDescriptor : TLDescriptor

@property (readonly, nullable) NSString *extension;
@property (readonly) int64_t length;
@property (readonly) int64_t end;
@property (readonly) BOOL copyAllowed;
@property (readonly) BOOL hasThumbnail;

- (BOOL)isAvailable;

- (nullable NSURL *)getURL;

/// Get the path to the optional thumbnail file.
- (nullable NSString *)thumbnailPath;

+ (BOOL)DEFAULT_COPY_ALLOWED;

@end

//
// Interface: TLImageDescriptor
//

@interface TLImageDescriptor : TLFileDescriptor

@property (readonly) int width;
@property (readonly) int height;

- (nullable UIImage *)getThumbnailWithMaxSize:(CGFloat)maxSize;

@end

//
// Interface: TLAudioDescriptor
//

@interface TLAudioDescriptor : TLFileDescriptor

@property (readonly) int64_t duration;

@end

//
// Interface: TLVideoDescriptor
//

@interface TLVideoDescriptor : TLFileDescriptor

@property (readonly) int width;
@property (readonly) int height;
@property (readonly) int64_t duration;

- (nullable UIImage *)getThumbnailWithMaxSize:(CGSize)maxSize;

@end

//
// Interface: TLNamedFileDescriptor
//

@interface TLNamedFileDescriptor : TLFileDescriptor

@property (readonly, nonnull) NSString *name;

@end

//
// Interface: TLTwincodeDescriptor
//

@interface TLTwincodeDescriptor : TLDescriptor

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nonnull) NSUUID *schemaId;
@property (readonly) BOOL copyAllowed;
@property (readonly, nullable) NSString *publicKey;

@end

//
// Interface: TLInvitationDescriptor
//

typedef enum {
    TLInvitationDescriptorStatusTypePending,
    TLInvitationDescriptorStatusTypeAccepted,
    TLInvitationDescriptorStatusTypeJoined,
    TLInvitationDescriptorStatusTypeRefused,
    TLInvitationDescriptorStatusTypeWithdrawn
} TLInvitationDescriptorStatusType;

@interface TLInvitationDescriptor : TLDescriptor

@property (readonly, nonnull) NSUUID *groupTwincodeId;
@property (nullable) NSUUID *memberTwincodeId;
@property (readonly, nonnull) NSUUID *inviterTwincodeId;
@property (readonly, nonnull) NSString *name;
@property (readonly, nullable) NSString *publicKey;
@property TLInvitationDescriptorStatusType status;

@end

//
// Interface: TLGeolocationDescriptor
//

@interface TLGeolocationDescriptor : TLDescriptor

@property double latitude;
@property double longitude;
@property double altitude;
@property double mapLatitudeDelta;
@property double mapLongitudeDelta;
@property (nullable) NSString *localMapPath;
@property BOOL isValidLocalMap;

- (nullable NSURL *)getURL;

@end

//
// Interface: TLCallDescriptor
//

@interface TLCallDescriptor : TLDescriptor

@property (readonly) BOOL isVideo;
@property (readonly) BOOL isIncoming;

- (BOOL)isAccepted;

- (BOOL)isTerminated;

- (long)duration;

- (TLPeerConnectionServiceTerminateReason)terminateReason;

@end

//
// Interface: TLClearDescriptor
//

@interface TLClearDescriptor : TLDescriptor

@property (readonly) int64_t clearTimestamp;

@end

//
// Interface: TLConversationServiceConfiguration
//

@interface TLConversationServiceConfiguration : TLBaseServiceConfiguration

@property BOOL enableScheduler;
@property int lockIdentifier;

@end

//
// Protocol: TLConversationServiceDelegate
//

typedef enum {
    TLConversationServiceUpdateTypeContent,
    TLConversationServiceUpdateTypeTimestamps,
    TLConversationServiceUpdateTypePeerAnnotations,
    TLConversationServiceUpdateTypeLocalAnnotations,
    TLConversationServiceUpdateTypeProtection
} TLConversationServiceUpdateType;

typedef enum {
    TLConversationServiceStreamingControlOffer,
    TLConversationServiceStreamingControlAccept,
    TLConversationServiceStreamingControlDecline,
    TLConversationServiceStreamingControlPlay,
    TLConversationServiceStreamingControlPause,
    TLConversationServiceStreamingControlStop
} TLConversationServiceStreamingControl;

typedef enum {
    TLConversationServiceClearMedia,     // Clear local media but keep messages and thumbnails.
    TLConversationServiceClearLocal,     // Clear local only messages and files including thumbnails.
    TLConversationServiceClearBothMedia, // Clear only media on both sides (no clear descriptor inserted).
    TLConversationServiceClearBoth       // Clear on both sides (a clear descriptor is added).
} TLConversationServiceClearMode;

@protocol TLConversationServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onGetConversationsWithRequestId:(int64_t)requestId conversations:(nonnull NSArray *)conversations;

- (void)onGetOrCreateConversationWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation;

- (void)onUpdateConversationPeerTwincodeOutboundIdWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation;

- (void)onResetConversationWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation clearMode:(TLConversationServiceClearMode)clearMode;

- (void)onDeleteConversationWithRequestId:(int64_t)requestId conversationId:(nonnull NSUUID *)conversationId;

- (void)onPushDescriptorRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onPopDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onUpdateDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor updateType:(TLConversationServiceUpdateType)updateType;

- (void)onUpdateAnnotationWithConversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor annotatingUser:(nonnull TLTwincodeOutbound *)annotatingUser;

- (void)onMarkReadDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onDeleteDescriptorsWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptors:(nonnull NSSet<TLDescriptorId *> *)descriptors;

- (void)onMarkDescriptorReadWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onMarkDescriptorDeletedWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor;

- (void)onInviteGroupWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation descriptor:(nonnull TLInvitationDescriptor *)descriptor;

- (void)onInviteGroupRequestWithRequestId:(int64_t)requestId conversation:(nonnull id <TLConversation>)conversation invitation:(nonnull TLInvitationDescriptor *)invitation;

- (void)onJoinGroupWithRequestId:(int64_t)requestId group:(nonnull id <TLGroupConversation>)group invitation:(nullable TLInvitationDescriptor *)invitation;

- (void)onJoinGroupResponseWithRequestId:(int64_t)requestId group:(nonnull id <TLGroupConversation>)group invitation:(nullable TLInvitationDescriptor *)invitation;

- (void)onJoinGroupRequestWithRequestId:(int64_t)requestId group:(nonnull id <TLGroupConversation>)group invitation:(nullable TLInvitationDescriptor *)invitation memberId:(nonnull NSUUID *)memberId;

- (void)onLeaveGroupWithRequestId:(int64_t)requestId group:(nonnull id <TLGroupConversation>)group memberId:(nonnull NSUUID *)memberId;

- (void)onDeleteGroupConversationWithRequestId:(int64_t)requestId conversationId:(nonnull NSUUID *)conversationId groupId:(nonnull NSUUID *)groupId;

- (void)onRevokedWithConversation:(nonnull id<TLConversation>)conversation;

- (void)onSignatureInfoWithConversation:(nonnull id<TLConversation>)conversation signedTwincode:(nonnull TLTwincodeOutbound *)signedTwincode;

@end

//
// Interface: TLConversationDescriptorPair
//

@interface TLConversationDescriptorPair : NSObject

@property (readonly, nonnull) id<TLConversation> conversation;
@property (readonly, nullable) TLDescriptor *descriptor;

- (nonnull instancetype)initWithConversation:(nonnull id<TLConversation>)conversation descriptor:(nullable TLDescriptor *)descriptor;

@end

//
// Interface: TLDescriptorAnnotationPair
//

@interface TLDescriptorAnnotationPair : NSObject

@property (readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (readonly, nonnull) TLDescriptorAnnotation *annotation;

- (nonnull instancetype)initWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound annotation:(nonnull TLDescriptorAnnotation *)annotation;

@end

//
// Interface: TLConversationService
//

@interface TLConversationService : TLBaseService

+ (nonnull NSString *)VERSION;

/**
 * The maximum number of members within the group.
 * - this limit is checked when a member joins/accepts an invitation,
 * - before sending an invitation.
 * Due to the distributed and offline nature of peers, it is still possible to have
 * groups with more members.
 */
+ (int)MAX_GROUP_MEMBERS;

- (void)incomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId subject:(nonnull id<TLRepositoryObject>)subject create:(BOOL)create peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound;

/// Update the 1-1 conversation when the peer twincode is received.  This is called when the peer invoked the `pair::bind`
/// we must update the conversation if it was created with the previous twincode if that conversation exists.
/// Then, we can also trigger the synchronizeConversation to execute the pending operation.
- (void)updateConversationWithSubject:(nonnull id<TLRepositoryObject>)subject peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound;

- (nonnull NSMutableArray<id<TLConversation>> *)listConversationsWithFilter:(nullable TLFilter *)filter;

- (nullable id <TLConversation>)getOrCreateConversationWithSubject:(nonnull id<TLRepositoryObject>)subject create:(BOOL)create;

- (nullable id<TLConversation>)getConversationWithSubject:(nonnull id<TLRepositoryObject>)subject;

- (nullable id<TLGroupConversation>)getGroupConversationWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId;

- (nullable id<TLGroupMemberConversation>)getGroupMemberConversationWithGroupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

- (TLBaseServiceErrorCode)clearConversationWithConversation:(nonnull id<TLConversation>)conversation clearDate:(int64_t)clearDate clearMode:(TLConversationServiceClearMode)clearMode;

- (TLBaseServiceErrorCode)deleteConversationWithSubject:(nonnull id<TLRepositoryObject>)subject;

- (nullable NSArray<TLDescriptor *> *)getDescriptorsWithConversation:(nonnull id<TLConversation>)conversation callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors;

- (void)getReplyTosWithDescriptors:(nonnull NSArray<TLDescriptor *> *)descriptors;

- (nullable NSArray<TLDescriptor *> *)getDescriptorsWithConversation:(nonnull id<TLConversation>)conversation descriptorType:(TLDescriptorType)descriptorType callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors;

- (nullable NSArray<TLDescriptor *> *)getDescriptorsWithDescriptorType:(TLDescriptorType)descriptorType callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors;

- (nullable NSArray<TLDescriptor *> *)getDescriptorsWithConversation:(nonnull id<TLConversation>)conversation types:(nonnull NSArray<NSNumber *> * )types callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors;

/// Get the twincode of descriptors used in the conversation and before the specified date.  When a type is given, look only for descriptors of the given type
- (nullable NSSet<NSUUID *> *)getConversationTwincodesWithSubject:(nonnull id<TLRepositoryObject>)subject beforeTimestamp:(int64_t)beforeTimestamp;

- (nullable NSSet<NSUUID *> *)getConversationTwincodesWithConversation:(nonnull id<TLConversation>)conversation descriptorType:(TLDescriptorType)descriptorType beforeTimestamp:(int64_t)beforeTimestamp;

/// Get a map of conversations filtered by the given filter and for each of them, get the last descriptor
/// sent or received.  If a conversation has no descriptor, a null entry is added for it.
- (nullable NSArray<TLConversationDescriptorPair *> *)getLastConversationDescriptorsWithFilter:(nullable TLFilter *)filter callsMode:(TLDisplayCallsMode)callsMode;

/// Search the descriptors from a list of conversations and matching a given search text.
/// The final list is composed of `{ conversation, descriptor }` pairs and sorted on the descriptor creation date.
- (nullable NSArray<TLConversationDescriptorPair *> *)searchDescriptorsWithConversations:(nonnull NSArray<id<TLConversation>> *)conversations searchText:(nonnull NSString *)searchText beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors;

- (void)forwardDescriptorWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo descriptorId:(nonnull TLDescriptorId *)descriptorId copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (void)pushObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (void)pushTransientObjectWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation object:(nonnull NSObject *)object;

- (void)pushCommandWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation object:(nonnull NSObject *)object;

- (void)pushFileWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(nonnull NSString *)path type:(TLDescriptorType)type toBeDeleted:(BOOL)toBeDeleted copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (void)pushGeolocationWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta localMapPath:(nullable NSString *)localMapPath expireTimeout:(int64_t)expireTimeout;

- (void)updateGeolocationWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta localMapPath:(nullable NSString *)localMapPath;

- (void)saveGeolocationMapWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId path:(nonnull NSString *)path;

- (nullable TLGeolocationDescriptor*)getGeolocationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)pushTwincodeWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo twincodeId:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId publicKey:(nullable NSString *)publicKey copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (void)acceptPushTwincodeWithSchemaId:(nonnull NSUUID *)schemaId;

- (void)updateDescriptorWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId message:(nullable NSString *)message copyAllowed:(nullable NSNumber *)copyAllowed expireTimeout:(nullable NSNumber *)expireTimeout;

- (void)markDescriptorReadWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)markDescriptorDeletedWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId;

/// Set the annotation with the value on the descriptor.  If the annotation already exists, the value is updated.
- (TLBaseServiceErrorCode)setAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value;

/// Remove the annotation on the descriptor.  The operation can only remove the annotations that the current device has set.
- (TLBaseServiceErrorCode)deleteAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type;

/// Toggle the descriptor annotation:
/// - If the annotation with the same value exists, it is removed,
/// - If the annotation with another value exists, the annotation is updated with the new value,
/// - If the annotation does not exist, it is added as a local annotation.
- (TLBaseServiceErrorCode)toggleAnnotationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId type:(TLDescriptorAnnotationType)type value:(int)value;

/// Get the descriptor annotation indexed by the owner twincode id.
- (nullable NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair *> *)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)deleteDescriptorWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (nullable id<TLGroupConversation>)createGroupConversationWithSubject:(nonnull id<TLRepositoryObject>)subject owner:(BOOL)owner;

- (TLBaseServiceErrorCode)inviteGroupWithRequestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation group:(nonnull id<TLRepositoryObject>)group name:(nonnull NSString *)name;

- (TLBaseServiceErrorCode)withdrawInviteGroupWithRequestId:(int64_t)requestId invitation:(nonnull TLInvitationDescriptor *)invitation;

- (TLBaseServiceErrorCode)joinGroupWithRequestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId group:(nullable id<TLRepositoryObject>)group;

- (nonnull NSMutableDictionary<NSUUID *, TLInvitationDescriptor *> *)listPendingInvitationsWithGroup:(nonnull id<TLRepositoryObject>)group;

- (TLBaseServiceErrorCode)registeredGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group adminTwincodeOutbound:(nonnull TLTwincodeOutbound *)adminTwincodeOutbound adminPermissions:(long)adminPermissions permissions:(long)permissions;

- (TLBaseServiceErrorCode)leaveGroupWithRequestId:(int64_t)requestId group:(nullable id<TLRepositoryObject>)group memberTwincodeId:(nonnull NSUUID*)memberTwincodeId;

- (nullable TLInvitationDescriptor*)getInvitationWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (nullable TLTwincodeDescriptor*)getTwincodeWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (nullable TLDescriptor*)getDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

- (TLBaseServiceErrorCode)setPermissionsWithSubject:(nullable id<TLRepositoryObject>)group memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

- (void)startCallWithRequestId:(int64_t)requestId subject:(nonnull id<TLRepositoryObject>)subject video:(BOOL)video incomingCall:(BOOL)incomingCall;

- (void)acceptCallWithRequestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (void)terminateCallWithRequestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId descriptorId:(nonnull TLDescriptorId *)descriptorId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

@end

@class TLBinaryPacketIQSerializer;
typedef void (^TLBinaryPacketListener) (TLBinaryPacketIQ * _Nonnull iq);

//
// Interface: TLConversationHandler
//

@interface TLConversationHandler : NSObject <TLPeerConnectionDataChannelDelegate>

@property (nonatomic, readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (nonatomic, nullable) NSUUID *peerConnectionId;
@property (nonatomic, readonly, nonnull) TLSerializerFactory *serializerFactory;

- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService;

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLBinaryPacketListener)listener;

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding;

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onDataChannelMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId data:(nonnull NSData *)data leadingPadding:(BOOL)leadingPadding;

- (BOOL)sendMessageWithIQ:(nonnull TLBinaryPacketIQ *)iq statType:(TLPeerConnectionServiceStatType)statType;

- (BOOL)sendWithDescriptor:(nonnull TLDescriptor *)descriptor;

/// Update our geolocation descriptor to the P2P data channel connection.
- (BOOL)updateWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor longitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta;

/// Send a DELETE descriptor on the peer to remove our descriptor from the peer's conversation.
- (BOOL)deleteWithDescriptor:(nonnull TLDescriptor *)descriptor;

+ (BOOL)markReadWithDescriptor:(nonnull TLDescriptor *)descriptor;

- (long)newRequestId;

/// Get the current peer geolocation descriptor.
- (nullable TLGeolocationDescriptor *)currentGeolocation;

- (void)onPopWithDescriptor:(nonnull TLDescriptor *)descriptor;

- (void)onUpdateGeolocationWithDescriptor:(nonnull TLGeolocationDescriptor *)descriptor;

- (void)onReadWithDescriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp;

- (void)onDeleteWithDescriptorId:(nonnull TLDescriptorId *)descriptorId;

@end

//
// Interface: TLDescriptorFactory
//

@interface TLDescriptorFactory : NSObject

/// Generate a new descriptorId for one of the createWithXXX operation (must be implemented).
- (nonnull TLDescriptorId *)newDescriptorId;

/// Create a message descriptor to be sent through the conversation handler.
- (nonnull TLDescriptor *)createWithMessage:(nonnull NSString *)message replyTo:(nullable TLDescriptorId *)replyTo copyAllowed:(BOOL)copyAllowed;

/// Create a geolocation descriptor to be sent through the conversation handler.
- (nonnull TLGeolocationDescriptor *)createWithLongitude:(double)longitude latitude:(double)latitude altitude:(double)altitude mapLongitudeDelta:(double)mapLongitudeDelta mapLatitudeDelta:(double)mapLatitudeDelta replyTo:(nullable TLDescriptorId *)replyTo copyAllowed:(BOOL)copyAllowed;

- (nonnull TLDescriptor *)createWithTwincode:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId publicKey:(nullable NSString *)publicKey  replyTo:(nullable TLDescriptorId *)replyTo copyAllowed:(BOOL)copyAllowed;

@end


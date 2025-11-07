/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLServiceRequestIQ.h"
#import "TLServiceResultIQ.h"
#import "TLSerializer.h"
#import "TLFileDescriptorImpl.h"
#import "TLUpdateDescriptorTimestampOperation.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLTwincodeDescriptorImpl.h"
#import "TLOnJoinGroupIQ.h"

#define TWINLIFE_NAME @"conversation"
#define TWINLIFE_NAME_SPACE @"urn:xmpp:twinlife:conversation:1"

//
// Interface: TLUnsupportedException
//

@interface TLUnsupportedException : NSException

@end

#pragma mark - TLConversationServiceResetConversationIQ

//
// Interface: TLConversationServiceResetConversationIQSerializer
//

@interface TLConversationServiceResetConversationIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServiceResetConversationIQ
//

#define RESET_CONVERSATION_ACTION @"reset-conversation"
#define RESET_CONVERSATION_ACTION_1 @"twinlife:conversation:reset-conversation"

@interface TLConversationServiceResetConversationIQ : TLServiceRequestIQ

@property (readonly) int64_t minSequenceId;
@property (readonly) int64_t peerMinSequenceId;
@property (readonly) NSArray<TLDescriptorId*> *resetMembers;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(NSArray<TLDescriptorId*> *)resetMembers;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

//
// Interface: TLConversationServiceOnResetConversationIQSerializer
//

@interface TLConversationServiceOnResetConversationIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnResetConversationIQ
//

#define ON_RESET_CONVERSATION_ACTION @"on-reset-conversation"

#define ON_RESET_CONVERSATION_ACTION_1 @"twinlife:conversation:on-reset-conversation"

@interface TLConversationServiceOnResetConversationIQ : TLServiceResultIQ

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

@end

#pragma mark - TLConversationServicePushCommandIQ

//
// Interface: TLConversationServicePushCommandIQSerializer
//

@interface TLConversationServicePushCommandIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServicePushCommandIQ
//

#define PUSH_COMMAND_ACTION @"push-command"

@class TLTransientObjectDescriptor;

@interface TLConversationServicePushCommandIQ : TLServiceRequestIQ

@property (readonly) TLTransientObjectDescriptor* commandDescriptor;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion commandDescriptor:(TLTransientObjectDescriptor *)commandDescriptor;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

//
// Interface: TLConversationServiceOnPushCommandIQSerializer
//

@interface TLConversationServiceOnPushCommandIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnPushCommandIQ
//

#define ON_PUSH_COMMAND_ACTION @"on-push-command"

@interface TLConversationServiceOnPushCommandIQ : TLServiceResultIQ

@property (readonly) int64_t receivedTimestamp;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

#pragma mark - TLConversationServicePushGeolocationIQ

//
// Interface: TLConversationServicePushGeolocationIQSerializer
//

@interface TLConversationServicePushGeolocationIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServicePushGeolocationIQ
//

#define PUSH_GEOLOCATION_ACTION @"push-geolocation"

@class TLGeolocationDescriptor;

@interface TLConversationServicePushGeolocationIQ : TLServiceRequestIQ

@property (readonly) TLGeolocationDescriptor* geolocationDescriptor;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion geolocationDescriptor:(TLGeolocationDescriptor *)geolocationDescriptor;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

//
// Interface: TLConversationServiceOnPushGeolocationIQSerializer
//

@interface TLConversationServiceOnPushGeolocationIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnPushGeolocationIQ
//

#define ON_PUSH_GEOLOCATION_ACTION @"on-push-geolocation"

@interface TLConversationServiceOnPushGeolocationIQ : TLServiceResultIQ

@property (readonly) int64_t receivedTimestamp;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp;

@end

#pragma mark - TLConversationServicePushObjectIQ

//
// Interface: TLConversationServicePushObjectIQSerializer
//

@interface TLConversationServicePushObjectIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServicePushObjectIQ
//

#define PUSH_OBJECT_ACTION @"push-object"

#define PUSH_OBJECT_ACTION_1 @"twinlife:conversation:push-object"

@class TLObjectDescriptor;

@interface TLConversationServicePushObjectIQ : TLServiceRequestIQ

@property (readonly) TLObjectDescriptor* objectDescriptor;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion objectDescriptor:(TLObjectDescriptor *)objectDescriptor;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

//
// Interface: TLConversationServiceOnPushObjectIQSerializer
//

@interface TLConversationServiceOnPushObjectIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnPushObjectIQ
//

#define ON_PUSH_OBJECT_ACTION @"on-push-object"
#define ON_PUSH_OBJECT_ACTION_1 @"twinlife:conversation:on-push-object"

@interface TLConversationServiceOnPushObjectIQ : TLServiceResultIQ

@property (readonly) int64_t receivedTimestamp;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp;

@end

#pragma mark - TLConversationServicePushTransientObjectIQ

//
// Interface: TLConversationServicePushTransientObjectIQSerializer
//

@interface TLConversationServicePushTransientObjectIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServicePushTransientObjectIQ
//

#define PUSH_TRANSIENT_OBJECT_ACTION @"push-transient-object"

@class TLTransientObjectDescriptor;

@interface TLConversationServicePushTransientObjectIQ : TLServiceRequestIQ

@property (readonly) TLTransientObjectDescriptor* transientObjectDescriptor;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion transientObjectDescriptor:(TLTransientObjectDescriptor *)transientObjectDescriptor;

@end

#pragma mark - TLConversationServicePushTwincodeIQ

//
// Interface: TLConversationServicePushTwincodeIQSerializer
//

@interface TLConversationServicePushTwincodeIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServicePushTwincodeIQ
//

#define PUSH_TWINCODE_ACTION @"push-twincode"

@class TLTwincodeDescriptor;

@interface TLConversationServicePushTwincodeIQ : TLServiceRequestIQ

@property (readonly) TLTwincodeDescriptor* twincodeDescriptor;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion twincodeDescriptor:(TLTwincodeDescriptor *)twincodeDescriptor;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

//
// Interface: TLConversationServiceOnPushTwincodeIQSerializer
//

@interface TLConversationServiceOnPushTwincodeIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnPushTwincodeIQ
//

#define ON_PUSH_TWINCODE_ACTION @"on-push-twincode"

@interface TLConversationServiceOnPushTwincodeIQ : TLServiceResultIQ

@property (readonly) int64_t receivedTimestamp;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

#pragma mark - TLConversationServicePushFileIQ

//
// Interface: TLConversationServicePushFileIQSerializer
//

@interface TLConversationServicePushFileIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServicePushFileIQ
//

#define PUSH_FILE_ACTION @"push-file"

@interface TLConversationServicePushFileIQ : TLServiceRequestIQ

@property TLFileDescriptor *fileDescriptor;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion fileDescriptor:(TLFileDescriptor *)fileDescriptor;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

//
// Interface: TLConversationServicePushFileIQSerializer
//

@interface TLConversationServiceOnPushFileIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnPushFileIQ
//

#define ON_PUSH_FILE_ACTION @"on-push-file"

@interface TLConversationServiceOnPushFileIQ : TLServiceResultIQ

@property int64_t receivedTimestamp;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp;

@end

#pragma mark - TLConversationServicePushFileChunkIQ

//
// Interface: TLConversationServicePushFileChunkIQSerializer
//

@interface TLConversationServicePushFileChunkIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServicePushFileChunkIQ
//

#define PUSH_FILE_CHUNK_ACTION @"push-file-chunk"

@interface TLConversationServicePushFileChunkIQ : TLServiceRequestIQ

@property TLDescriptorId *descriptorId;
@property int64_t chunkStart;
@property NSData *chunk;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId descriptorId:(TLDescriptorId *)descriptorId majorVersion:(int)majorVersion minorVersion:(int)minorVersion chunkStart:(int64_t)chunkStart chunk:(NSData *)chunk;

@end

//
// Interface: TLConversationServiceOnPushFileChunkIQSerializer
//

@interface TLConversationServiceOnPushFileChunkIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnPushFileChunkIQ
//

#define ON_PUSH_FILE_CHUNK_ACTION @"on-push-file-chunk"

@interface TLConversationServiceOnPushFileChunkIQ : TLServiceResultIQ

@property int64_t receivedTimestamp;
@property int64_t nextChunkStart;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion receivedTimestamp:(int64_t)receivedTimestamp nextChunkStart:(int64_t)nextChunkStart;

@end

#pragma mark - TLConversationServiceUpdateDescriptorTimestampIQ

//
// Interface: TLUpdateDescriptorTimestampIQSerializer
//

@interface TLUpdateDescriptorTimestampIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLUpdateDescriptorTimestampIQ
//

#define UPDATE_DESCRIPTOR_TIMESTAMP_ACTION @"update-descriptor-timestamp"

@interface TLUpdateDescriptorTimestampIQ : TLServiceRequestIQ

@property TLUpdateDescriptorTimestampType timestampType;
@property TLDescriptorId *descriptorId;
@property int64_t timestamp;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion timestampType:(TLUpdateDescriptorTimestampType)timestampType descriptorId:(TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp;

@end

//
// Interface: TLOnUpdateDescriptorTimestampIQSerializer
//

@interface TLOnUpdateDescriptorTimestampIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLOnUpdateDescriptorTimestampIQ
//

#define ON_UPDATE_DESCRIPTOR_TIMESTAMP_ACTION @"on-update-descriptor-timestamp"

@interface TLOnUpdateDescriptorTimestampIQ : TLServiceResultIQ

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

@end


#pragma mark - TLConversationServiceInviteGroupIQ

//
// Interface: TLConversationServiceInviteGroupIQSerializer
//

@interface TLConversationServiceInviteGroupIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServiceInviteGroupIQ
//

#define INVITE_GROUP_ACTION @"invite-group"

@interface TLConversationServiceInviteGroupIQ : TLServiceRequestIQ

@property (readonly) TLInvitationDescriptor *invitationDescriptor;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

#pragma mark - TLConversationServiceRevokeInviteGroupIQ

//
// Interface: TLConversationServiceRevokeInviteGroupIQSerializer
//

@interface TLConversationServiceRevokeInviteGroupIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServiceRevokeInviteGroupIQ
//

#define REVOKE_INVITE_GROUP_ACTION @"revoke-invite-group"

@interface TLConversationServiceRevokeInviteGroupIQ : TLServiceRequestIQ

@property (readonly) TLInvitationDescriptor *invitationDescriptor;

+ (NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

#pragma mark - TLConversationServiceJoinGroupIQ

//
// Interface: TLConversationServiceJoinGroupIQSerializer
//

@interface TLConversationServiceJoinGroupIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServiceJoinGroupIQ
//

#define JOIN_GROUP_ACTION @"join-group"

@interface TLConversationServiceJoinGroupIQ : TLServiceRequestIQ

@property (readonly) TLInvitationDescriptor *invitationDescriptor;
@property (readonly) NSUUID* groupTwincodeId;
@property (readonly) NSUUID* memberTwincodeId;
@property (readonly) int64_t permissions;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

#pragma mark - TLConversationServiceLeaveGroupIQ

//
// Interface: TLConversationServiceLeaveGroupIQSerializer
//

@interface TLConversationServiceLeaveGroupIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServiceLeaveGroupIQ
//

#define LEAVE_GROUP_ACTION @"leave-group"

@interface TLConversationServiceLeaveGroupIQ : TLServiceRequestIQ

@property (readonly) NSUUID *groupTwincodeId;
@property (readonly) NSUUID *memberTwincodeId;

+ (NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory withLeadingPadding:(BOOL)withLeadingPadding;

@end

#pragma mark - TLConversationServiceUpdateGroupMemberIQ

//
// Interface: TLConversationServiceUpdateGroupMemberIQSerializer
//

@interface TLConversationServiceUpdateGroupMemberIQSerializer : TLServiceRequestIQSerializer

@end

//
// Interface: TLConversationServiceUpdateGroupMemberIQ
//

#define UPDATE_GROUP_MEMBER_ACTION @"update-group-member"

@interface TLConversationServiceUpdateGroupMemberIQ : TLServiceRequestIQ

@property (readonly) NSUUID *groupTwincodeId;
@property (readonly) NSUUID *memberTwincodeId;
@property (readonly) int64_t permissions;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId majorVersion:(int)majorVersion minorVersion:(int)minorVersion groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

//
// Interface: TLConversationServiceOnResultGroupIQSerializer
//

@interface TLConversationServiceOnResultGroupIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnResultGroupIQ
//

#define ON_INVITE_GROUP_ACTION @"on-invite-group"
#define ON_REVOKE_INVITE_GROUP_ACTION @"on-revoke-invite-group"
#define ON_LEAVE_GROUP_ACTION @"on-leave-group"
#define ON_UPDATE_GROUP_MEMBER_ACTION @"on-update-group-member"

@interface TLConversationServiceOnResultGroupIQ : TLServiceResultIQ

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory withLeadingPadding:(BOOL)withLeadingPadding;

@end

//
// Interface: TLConversationServiceOnResultJoinGroupIQSerializer
//

@interface TLConversationServiceOnResultJoinGroupIQSerializer : TLServiceResultIQSerializer

@end

//
// Interface: TLConversationServiceOnResultJoinGroupIQ
//

#define ON_JOIN_GROUP_ACTION @"on-join-group"

@interface TLConversationServiceOnResultJoinGroupIQ : TLServiceResultIQ

@property TLInvitationDescriptorStatusType status;
@property int64_t permissions;
@property (readonly) NSArray<TLOnJoinGroupMemberInfo*> *members;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion status:(TLInvitationDescriptorStatusType)status permissions:(int64_t)permissions members:(NSArray<TLOnJoinGroupMemberInfo *>*)members;

- (NSMutableData *)serializeWithSerializerFactory:(TLSerializerFactory *)factory;

@end

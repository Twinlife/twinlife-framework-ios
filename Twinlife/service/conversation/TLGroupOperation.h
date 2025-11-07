/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLGroupOperation
//

#define GROUP_OPERATION_SCHEMA_VERSION_1 1
#define GROUP_OPERATION_SCHEMA_VERSION_2 2

@class TLInvitationDescriptor;
@class TLDescriptorId;
@class TLDatabaseIdentifier;

@interface TLGroupOperation : TLConversationServiceOperation

@property (readonly, nullable) NSUUID *memberTwincodeId;
@property (readonly, nullable) NSUUID *groupTwincodeId;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

/// Serialize the specific part of the operation (used for the V20 migration).
+ (nullable NSData *)serializeOperation:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions publicKey:(nullable NSString *)publicKey signedOffTwincodeId:(nullable NSUUID *)signedOffTwincodeId signature:(nullable NSString *)signature;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type invitationDescriptor:(nullable TLInvitationDescriptor *)invitationDescriptor groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId;

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId;

@end

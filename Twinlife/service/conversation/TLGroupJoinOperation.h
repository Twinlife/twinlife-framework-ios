/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGroupOperation.h"

//
// Interface: TLGroupJoinOperation
//

@interface TLGroupJoinOperation : TLGroupOperation

@property (readonly) int64_t permissions;
@property (readonly, nullable) NSString *publicKey;
@property (readonly, nullable) NSString *signature;
@property (readonly, nullable) NSUUID *signedOffTwincodeId;
@property (nullable) TLInvitationDescriptor* invitationDescriptor;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions publicKey:(nullable NSString *)publicKey signedOffTwincodeId:(nullable NSUUID *)signedOffTwincodeId signature:(nullable NSString *)signature;

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content;

@end

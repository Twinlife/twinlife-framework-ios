/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGroupOperation.h"

//
// Interface: TLGroupInviteOperation
//

@interface TLGroupInviteOperation : TLGroupOperation

@property (nullable) TLInvitationDescriptor* invitationDescriptor;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type invitationDescriptor:(nonnull TLInvitationDescriptor *)invitationDescriptor;

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId;

@end

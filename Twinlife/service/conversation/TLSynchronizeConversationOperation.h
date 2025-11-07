/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

@class TLDatabaseIdentifier;

//
// Interface: TLSynchronizeConversationOperation
//

@interface TLSynchronizeConversationOperation : TLConversationServiceOperation

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate;

@end

/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGroupOperation.h"

//
// Interface: TLGroupUpdateOperation
//

@interface TLGroupUpdateOperation : TLGroupOperation

@property (readonly) int64_t permissions;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content;

@end

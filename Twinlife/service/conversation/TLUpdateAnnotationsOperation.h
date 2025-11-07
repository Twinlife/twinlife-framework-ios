/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLUpdateAnnotationsOperation
//

@class TLDescriptorId;
@class TLDatabaseIdentifier;

@interface TLUpdateAnnotationsOperation : TLConversationServiceOperation

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId;

@end

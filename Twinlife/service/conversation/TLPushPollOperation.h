/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLPushPollOperation
//

@class TLPollDescriptor;
@class TLDescriptorId;
@class TLDatabaseIdentifier;

@interface TLPushPollOperation : TLConversationServiceOperation

@property (nullable) TLPollDescriptor *pollDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation pollDescriptor:(nonnull TLPollDescriptor *)pollDescriptor;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId;

@end

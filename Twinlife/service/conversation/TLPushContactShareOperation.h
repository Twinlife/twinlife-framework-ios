/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLPusContactShareOperation
//

@class TLContactShareDescriptor;
@class TLDescriptorId;
@class TLDatabaseIdentifier;

@interface TLPushContactShareOperation : TLConversationServiceOperation

@property (nullable) TLContactShareDescriptor *contactShareDescriptor;
@property (nullable) NSData *avatar;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation contactShareDescriptor:(nonnull TLContactShareDescriptor *)contactShareDescriptor avatar:(nonnull NSData *)avatar;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId;

@end

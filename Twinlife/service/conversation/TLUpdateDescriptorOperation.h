/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLUpdateDescriptorOperation
//

@class TLDescriptor;
@class TLDescriptorId;
@class TLDatabaseIdentifier;

// Update operation flags (must match the same values as on Java implementation).
#define TL_UPDATE_MESSAGE      0x01
#define TL_UPDATE_COPY_ALLOWED 0x02
#define TL_UPDATE_EXPIRATION   0x08

@interface TLUpdateDescriptorOperation : TLConversationServiceOperation

@property (nullable) TLDescriptor *descriptorImpl;
@property (readonly) int updateFlags;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation descriptor:(nonnull TLDescriptor *)descriptor updateFlags:(int)updateFlags;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content;

+ (int)buildFlagsWithMessage:(nullable NSString *)message copyAllowed:(nullable NSNumber *)copyAllowed expireTimeout:(nullable NSNumber *)expireTimeout;

@end

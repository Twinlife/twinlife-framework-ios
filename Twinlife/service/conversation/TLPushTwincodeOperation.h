/*
 *  Copyright (c) 2019-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLPushTwincodeOperation
//

@class TLTwincodeDescriptor;
@class TLDescriptorId;
@class TLDatabaseIdentifier;

@interface TLPushTwincodeOperation : TLConversationServiceOperation

@property (nullable) TLTwincodeDescriptor *twincodeDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation twincodeDescriptor:(nonnull TLTwincodeDescriptor *)twincodeDescriptor;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId;

@end

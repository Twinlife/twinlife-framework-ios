/*
 *  Copyright (c) 2019-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLPushGeolocationOperation
//

@class TLGeolocationDescriptor;
@class TLDescriptorId;
@class TLDatabaseIdentifier;

@interface TLPushGeolocationOperation : TLConversationServiceOperation

@property (nullable) TLGeolocationDescriptor *geolocationDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation geolocationDescriptor:(nonnull TLGeolocationDescriptor *)geolocationDescriptor;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId;

@end

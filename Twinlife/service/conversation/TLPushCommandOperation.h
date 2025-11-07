/*
 *  Copyright (c) 2020-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLPushCommandOperation
//

@class TLTransientObjectDescriptor;

@interface TLPushCommandOperation : TLConversationServiceOperation

@property (readonly, nonnull) TLTransientObjectDescriptor *commandDescriptor;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation commandDescriptor:(nonnull TLTransientObjectDescriptor *)commandDescriptor;

@end

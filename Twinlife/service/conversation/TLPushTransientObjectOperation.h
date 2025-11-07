/*
 *  Copyright (c) 2016-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

//
// Interface: TLPushTransientObjectOperation
//

@class TLTransientObjectDescriptor;

@interface TLPushTransientObjectOperation : TLConversationServiceOperation

@property (readonly) TLTransientObjectDescriptor *transientObjectDescriptor;

- (instancetype)initWithConversation:(TLConversationImpl *)conversation transientObjectDescriptor:(TLTransientObjectDescriptor *)transientObjectDescriptor;

@end

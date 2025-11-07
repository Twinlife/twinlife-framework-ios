/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLConversationProtocol
//

@interface TLConversationProtocol : NSObject

+ (nonnull NSString *)ACTION_CONVERSATION_SYNCHRONIZE;

+ (nonnull NSString *)ACTION_CONVERSATION_NEED_SECRET;

+ (nonnull NSString *)invokeTwincodeActionMemberTwincodeOutboundId;

@end

/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationService.h"
#import "TLConversationImpl.h"

//
// Interface: TLGroupMemberConversationImpl
//

@interface TLGroupMemberConversationImpl : TLConversationImpl <TLGroupMemberConversation>

@property (readonly, weak, nullable) TLGroupConversationImpl *group;
@property (readonly, nonnull) TLTwincodeOutbound *peerTwincodeOutbound;

+ (nonnull NSUUID *)SCHEMA_ID;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier conversationId:(nonnull NSUUID *)conversationId group:(nonnull TLGroupConversationImpl *)group creationDate:(int64_t)creationDate resourceId:(nonnull NSUUID *)resourceId peerResourceId:(nullable NSUUID *)peerResourceId permissions:(int64_t)permissions lastConnectDate:(int64_t)lastConnectDate lastRetryDate:(int64_t)lastRetryDate flags:(int)flags peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound invitedContactId:(nullable NSUUID *)invitedContactId;

- (void)markLeaving;

@end

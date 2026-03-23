/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHandler.h"
#import "TLConversationService.h"

#define TL_GROUP_CONVERSATION_BACKUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"f1bba3af-1432-47d0-9cc9-e91ff533f2a4"]
#define TL_GROUP_CONVERSATION_BACKUP_SCHEMA_VERSION 1

@interface TLGroupConversationHandler : TLBackupHandler<id<TLConversation>>

- (nonnull instancetype)initWithConversationService:(nonnull TLConversationService *)conversationService;

@end



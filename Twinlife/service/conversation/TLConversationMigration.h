/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDatabaseService.h"

@class TLBaseService;
@class TLConversationFactory;

//
// Interface: TLConversationMigration
//

@interface TLConversationMigration : NSObject

- (nonnull instancetype)initWithService:(nonnull TLBaseService *)service database:(nonnull TLDatabaseService *)database conversationFactory:(nonnull TLConversationFactory *)conversationFactory;

- (void)upgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion;

@end

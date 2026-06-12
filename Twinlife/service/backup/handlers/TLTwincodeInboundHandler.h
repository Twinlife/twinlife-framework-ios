/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHandler.h"
#import "TLTwincodeInboundService.h"

@class TLTwincodeOutboundService;

#define TL_TWINCODE_INBOUND_BACKUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"592d44e0-a1fb-4451-b015-5f355406faae"]
#define TL_TWINCODE_INBOUND_BACKUP_SCHEMA_VERSION 2

@interface TLTwincodeInboundHandler : TLBackupHandler<TLTwincodeInbound *>

- (nonnull instancetype)initWithTwincodeInboundService:(nonnull TLTwincodeInboundService *)twincodeInboundService twincodeOutboundService:(nonnull TLTwincodeOutboundService *)twincodeOutboundService;

@end



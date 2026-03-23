/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHandler.h"
#import "TLTwincodeOutboundService.h"

@class TLCryptoService;

#define TL_TWINCODE_OUTBOUND_BACKUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"b1a6f07f-364d-451d-a03b-054afcb3d61a"]
#define TL_TWINCODE_OUTBOUND_BACKUP_SCHEMA_VERSION 1

@interface TLTwincodeOutboundHandler : TLBackupHandler<TLTwincodeOutbound *>

- (nonnull instancetype)initWithTwincodeOutboundService:(nonnull TLTwincodeOutboundService *)twincodeOutboundService cryptoService:(nonnull TLCryptoService *)cryptoService;

@end


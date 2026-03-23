/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHandler.h"
#import "TLAccountServiceSecuredConfiguration.h"

@class TLTwinlife;

#define TL_ACCOUNT_CONFIGURATION_BACKUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"83ff7730-08fd-4242-a9d3-36697be0d963"]
#define TL_ACCOUNT_CONFIGURATION_BACKUP_SCHEMA_VERSION 1

@interface TLAccountSecuredConfigurationHandler : TLBackupHandler<TLAccountServiceSecuredConfiguration *>

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife;

@end

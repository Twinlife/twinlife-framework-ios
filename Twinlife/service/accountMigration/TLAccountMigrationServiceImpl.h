/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAccountMigrationService.h"

@class TLAccountMigrationServiceSecuredConfiguration;

//
// Interface: TLAccountMigrationService ()
//

@interface TLAccountMigrationService ()

@property (nullable) NSUUID *activeMigrationId;

/// If a migration is finished but was not installed, do it now before starting the account service.
- (void)finishMigration;

@end


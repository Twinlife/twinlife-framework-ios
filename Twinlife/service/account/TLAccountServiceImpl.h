/*
 *  Copyright (c) 2014-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAccountService.h"

//
// Interface: TLAccountService ()
//

@class TLAccountServiceSecuredConfiguration;

@interface TLAccountService ()

@property (nullable) TLAccountServiceSecuredConfiguration *securedConfiguration;
@property (readonly, nonnull) NSMutableSet *allowedFeatures;

- (void)configure:(nonnull TLBaseServiceConfiguration*)baseServiceConfiguration applicationId:(nonnull NSUUID *)applicationId serviceId:(nonnull NSUUID *)serviceId;

/// Get the environment id that was configured for the device by the server.
- (nullable NSUUID *)environmentId;

- (nullable NSString *)user;

/// Check if the account was disabled.
- (BOOL)isAccountDisabled;

@end

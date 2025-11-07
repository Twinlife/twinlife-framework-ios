/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAccountService.h"

#define ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY @"TLAccountServiceSecuredConfiguration"
#define ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG @"TLAccountServiceSecuredConfigurationTag"

//
// Interface: TLAccountServiceSecuredConfiguration
//

@class TLSerializerFactory;
@class TLSerializer;

@interface TLAccountServiceSecuredConfiguration : NSObject

@property (nonatomic, setter=setAuthenticationAuthority:) TLAccountServiceAuthenticationAuthority authenticationAuthority;
@property (nonatomic, nullable, setter=setEnvironmentId:) NSUUID *environmentId;
@property (readonly) BOOL isSignOut;
@property (readonly, nullable) NSString *deviceUsername;
@property (readonly, nullable) NSString *devicePassword;
@property (nonatomic, nullable, setter=setSubscribedFeatures:) NSString *subscribedFeatures;
@property (readonly) BOOL twinlifeRememberPassword;
@property (readonly) BOOL modified;

/// Load the account secure configuration from the secure storage.
/// When alternateApplication is set, load from an alternate keychain (ie, the Twinme Lite keychain).
/// Returns nil if there is no account secure configuration or it cannot be deserialized.
+ (nullable TLAccountServiceSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory alternateApplication:(BOOL)alternateApplication;

+ (nullable TLAccountServiceSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory content:(nonnull NSData *)content;

/// Export the account secured configuration for the migration service using schema version 4 (compatible with new Android starting 2024-07-09).
+ (nullable NSData *)exportWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory;

#ifdef TWINME_PLUS
/// Import in the secure storage the account secure configuration from the alternate application (ie, Twinme Lite).
/// Returns YES if the import succeeded.
+ (BOOL)importApplicationData:(nonnull TLSerializerFactory *)serializerFactory;
#endif

- (nonnull instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory deviceIdentifier:(nonnull NSString *)deviceIdentifier;

/// Check if the secure configuration needs an update for the environment id.
- (BOOL)isUpdatedWithEnvironmentId:(nullable NSUUID *)environmentId;

/// Check if the secure configuration needs an update for the subscribed features.
- (BOOL)isUpdatedWithSubscribedFeatures:(nullable NSString *)features;

- (void)synchronize;

- (void)erase;

@end

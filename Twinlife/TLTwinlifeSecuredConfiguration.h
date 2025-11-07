/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLTwinlife.h"

#define TWINLIFE_SECURED_CONFIGURATION_KEY @"TLTwinlifeSecuredConfiguration"
#define TWINLIFE_SECURED_CONFIGURATION_TAG @"TLTwinlifeSecuredConfigurationTag"

//
// Interface: TLTwinlifeSecuredConfiguration
//

@class TLSerializerFactory;
@class TLSerializer;
@class TLTwinlifeConfiguration;

@interface TLTwinlifeSecuredConfiguration : NSObject

@property (nullable, readonly) NSString *databaseKey;
@property (nonnull, readonly) NSString *deviceIdentifier;
@property (nullable, readonly) NSString *oldDatabaseKey;

/// Generate a database key with salt in a 96 bytes hexadecimal string.
/// The key is composed of a 32-bytes random followed by a 16-bytes random salt used by SQLCipher and then converted in hexadecimal.
/// The database key is then configured by using the SQL statement:
/// PRAGMA key = "x'<hexadecimal key>'"
+ (nullable NSString *)generateDatabaseKey;

/// Load the secure configuration from the secure storage.
/// When alternateApplication is set, load from an alternate keychain (ie, the Twinme Lite keychain).
/// Returns nil if there is no secure configuration or it cannot be deserialized.
+ (nullable TLTwinlifeSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory alternateApplication:(BOOL)alternateApplication;

/// Load the secure configuration referenced by the key from the secure storage.
/// When alternateApplication is set, load from an alternate keychain (ie, the Twinme Lite keychain).
/// Returns nil if there is no secure configuration for this key or it cannot be deserialized.
+ (nullable TLTwinlifeSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory key:(nonnull NSString *)key alternateApplication:(BOOL)alternateApplication;

/// Load the secure configuration from the given content.
+ (nullable TLTwinlifeSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory content:(nonnull NSData *)content;

/// Export the secure configuration for the migration service using schema version 2 with the correct schema Id compatible with Android.
+ (nullable NSData *)exportWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory;

#ifdef TWINME_PLUS
+ (BOOL)importApplicationData;
#endif

- (nullable instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory;

/// Change the database encryption key. This is used only when we migrate the SQLCipher database from V3 to V4.
- (BOOL)changeDatabaseKeyWithKey:(nonnull NSString *)key;

- (void)erase;

- (nonnull NSData *)exportWithKey:(nonnull NSString *)key;

@end

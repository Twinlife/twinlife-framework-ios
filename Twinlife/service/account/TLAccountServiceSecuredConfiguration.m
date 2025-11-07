/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#include <CommonCrypto/CommonDigest.h>

#import "TLAccountServiceSecuredConfiguration.h"

#import "TLSerializer.h"

#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLKeyChain.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

/**
 * <pre>
 * Schema version 4 == Schema version 3 used by Android
 *  Date: 2024-07-09
 *   This schema version must be used for iOS <-> Android migration.
 * {
 *  "type":"record",
 *  "name":"AccountServiceSecuredConfiguration",
 *  "namespace":"org.twinlife.schemas.services",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"authenticationAuthority", "type":"org.twinlife.schemas.AccountServiceAuthenticationAuthority"}
 *   {"name":"isSignOut", "type":"boolean"}
 *   {"name":"deviceUsername", [null, "type":"string"]}
 *   {"name":"devicePassword", [null, "type":"string"]}
 *   {"name":"subscribedFeatures", [null, "type":"string"]}
 *   {"name":"environmentId", [null, "type":"uuid"]}
 * }
 *
 * Schema version 3 (not compatible with Android!!!!)
 *  Date: 2021-12-01
 * {
 *  "type":"enum",
 *  "name":"AccountServiceAuthenticationAuthority",
 *  "namespace":"org.twinlife.schemas",
 *  "symbols" : ["Device", "Twinlife", "Unregistered", "Disabled"]
 * }
 * {
 *  "type":"record",
 *  "name":"AccountServiceSecuredConfiguration",
 *  "namespace":"org.twinlife.schemas.services",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"authenticationAuthority", "type":"org.twinlife.schemas.AccountServiceAuthenticationAuthority"}
 *   {"name":"isSignOut", "type":"boolean"}
 *   {"name":"deviceUsername", [null, "type":"string"]}
 *   {"name":"devicePassword", [null, "type":"string"]}
 *   {"name":"twinlifeUsername", [null]} // Difference with Android!
 *   {"name":"twinlifePassword", [null]} // Difference with Android!
 *   {"name":"twinlifeRememberPassword", [false]} // Difference with Android!
 *   {"name":"subscribedFeatures", [null, "type":"string"]}
 *   {"name":"environmentId", [null, "type":"uuid"]}
 * }
 *
 * Schema version 2
 *  Date: 2019/11/07
 *
 * {
 *  "type":"enum",
 *  "name":"AccountServiceAuthenticationAuthority",
 *  "namespace":"org.twinlife.schemas",
 *  "symbols" : ["Device", "Twinlife", "Unregistered"]
 * }
 *
 * {
 *  "type":"record",
 *  "name":"AccountServiceSecuredConfiguration",
 *  "namespace":"org.twinlife.schemas.services",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"authenticationAuthority", "type":"org.twinlife.schemas.AccountServiceAuthenticationAuthority"}
 *   {"name":"isSignOut", "type":"boolean"}
 *   {"name":"deviceUsername", [null, "type":"string"]}
 *   {"name":"devicePassword", [null, "type":"string"]}
 *   {"name":"twinlifeUsername", [null, "type":"string"]}
 *   {"name":"twinlifePassword", [null, "type":"string"]}
 *   {"name":"twinlifeRememberPassword", "type":"boolean"}
 *   {"name":"subscribedFeatures", [null, "type":"string"]}
 * }
 *
 * Schema version 1
 *  Date: 2017/06/19
 *
 * {
 *  "type":"enum",
 *  "name":"AccountServiceAuthenticationAuthority",
 *  "namespace":"org.twinlife.schemas",
 *  "symbols" : ["Device", "Twinlife", "Facebook"]
 * }
 *
 * {
 *  "type":"record",
 *  "name":"AccountServiceSecuredConfiguration",
 *  "namespace":"org.twinlife.schemas.services",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"authenticationAuthority", "type":"org.twinlife.schemas.AccountServiceAuthenticationAuthority"}
 *   {"name":"isSignOut", "type":"boolean"}
 *   {"name":"deviceUsername", [null, "type":"string"]}
 *   {"name":"devicePassword", [null, "type":"string"]}
 *   {"name":"twinlifeUsername", [null, "type":"string"]}
 *   {"name":"twinlifePassword", [null, "type":"string"]}
 *   {"name":"twinlifeRememberPassword", "type":"boolean"}
 * }
 *
 * </pre>
 */

//
// Interface: TLAccountServiceSecuredConfiguration ()
//

@interface TLAccountServiceSecuredConfiguration ()

@property TLSerializerFactory *serializerFactory;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_4;

+ (int)SCHEMA_VERSION_3;

+ (int)SCHEMA_VERSION_2;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLSerializer *)SERIALIZER_4;

+ (nonnull TLSerializer *)SERIALIZER_3;

+ (nonnull TLSerializer *)SERIALIZER_2;

+ (nonnull TLSerializer *)SERIALIZER_1;

- (nonnull instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory authenticationAuthority:(TLAccountServiceAuthenticationAuthority)authenticationAuthority isSignOut:(BOOL)isSignOut deviceUsername:(nullable NSString *)deviceUsername devicePassword:(nullable NSString *)devicePassword features:(nullable NSString *)features environmentId:(nullable NSUUID *)environmentId;

@end

//
// Interface: TLAccountServiceSecuredConfigurationSerializer_4
//

@interface TLAccountServiceSecuredConfigurationSerializer_4 : TLSerializer

@end

//
// Implementation: TLAccountServiceSecuredConfigurationSerializer_4
//

static NSUUID *ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_ID = nil;
static int ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_4 = 4;
static TLSerializer *ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_4 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLAccountServiceSecuredConfigurationSerializer_4"

@implementation TLAccountServiceSecuredConfigurationSerializer_4

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_4 class:[TLAccountServiceSecuredConfiguration class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLAccountServiceSecuredConfiguration *securedConfiguration = (TLAccountServiceSecuredConfiguration *)object;
    switch (securedConfiguration.authenticationAuthority) {
        case TLAccountServiceAuthenticationAuthorityDevice:
            [encoder writeEnum:0];
            break;
            
        case TLAccountServiceAuthenticationAuthorityTwinlife:
            [encoder writeEnum:1];
            break;

        case TLAccountServiceAuthenticationAuthorityUnregistered:
            [encoder writeEnum:2];
            break;

        case TLAccountServiceAuthenticationAuthorityDisabled:
            [encoder writeEnum:3];
            break;
    }
    [encoder writeBoolean:securedConfiguration.isSignOut];
    [encoder writeOptionalString:securedConfiguration.deviceUsername];
    [encoder writeOptionalString:securedConfiguration.devicePassword];
    [encoder writeOptionalString:securedConfiguration.subscribedFeatures];
    [encoder writeOptionalUUID:securedConfiguration.environmentId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    int value = [decoder readEnum];
    TLAccountServiceAuthenticationAuthority authenticationAuthority;
    switch (value) {
        case 0:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityDevice;
            break;
            
        case 1:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityTwinlife;
            break;
            
        case 2:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            break;
            
        case 3:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityDisabled;
            break;

        default:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            break;
    }
    BOOL isSignOut = [decoder readBoolean];
    NSString *deviceUsername = [decoder readOptionalString];
    NSString *devicePassword = [decoder readOptionalString];
    NSString *subscribedFeatures = [decoder readOptionalString];
    NSUUID *environmentId = [decoder readOptionalUUID];

    return [[TLAccountServiceSecuredConfiguration alloc] initWithSerializerFactory:serializerFactory authenticationAuthority:authenticationAuthority isSignOut:isSignOut deviceUsername:deviceUsername devicePassword:devicePassword features:subscribedFeatures environmentId:environmentId];
}

@end

//
// Interface: TLAccountServiceSecuredConfigurationSerializer_3
//

@interface TLAccountServiceSecuredConfigurationSerializer_3 : TLSerializer

@end

//
// Implementation: TLAccountServiceSecuredConfigurationSerializer_3
//

static int ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_3 = 3;
static TLSerializer *ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_3 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLAccountServiceSecuredConfigurationSerializer_3"

@implementation TLAccountServiceSecuredConfigurationSerializer_3

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_3 class:[TLAccountServiceSecuredConfiguration class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLAccountServiceSecuredConfiguration *securedConfiguration = (TLAccountServiceSecuredConfiguration *)object;
    switch (securedConfiguration.authenticationAuthority) {
        case TLAccountServiceAuthenticationAuthorityDevice:
            [encoder writeEnum:0];
            break;
            
        case TLAccountServiceAuthenticationAuthorityTwinlife:
            [encoder writeEnum:1];
            break;

        case TLAccountServiceAuthenticationAuthorityUnregistered:
            [encoder writeEnum:2];
            break;

        case TLAccountServiceAuthenticationAuthorityDisabled:
            [encoder writeEnum:3];
            break;
    }
    [encoder writeBoolean:securedConfiguration.isSignOut];
    [encoder writeOptionalString:securedConfiguration.deviceUsername];
    [encoder writeOptionalString:securedConfiguration.devicePassword];
    // There is no twinlifeUsername, twinlifePassword
    [encoder writeEnum:0];
    [encoder writeEnum:0];
    [encoder writeBoolean:false];
    [encoder writeOptionalString:securedConfiguration.subscribedFeatures];
    [encoder writeOptionalUUID:securedConfiguration.environmentId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    int value = [decoder readEnum];
    TLAccountServiceAuthenticationAuthority authenticationAuthority;
    switch (value) {
        case 0:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityDevice;
            break;
            
        case 1:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityTwinlife;
            break;
            
        case 2:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            break;
            
        case 3:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityDisabled;
            break;

        default:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            break;
    }
    BOOL isSignOut = [decoder readBoolean];
    NSString *deviceUsername = [decoder readOptionalString];
    NSString *devicePassword = [decoder readOptionalString];

    // Skip the twinlifeUsername
    [decoder readOptionalString];
    // Skip the twinlifePassword
    [decoder readOptionalString];
    // Skip the rememberPassword
    [decoder readBoolean];

    NSString *subscribedFeatures = [decoder readOptionalString];
    NSUUID *environmentId = [decoder readOptionalUUID];

    return [[TLAccountServiceSecuredConfiguration alloc] initWithSerializerFactory:serializerFactory authenticationAuthority:authenticationAuthority isSignOut:isSignOut deviceUsername:deviceUsername devicePassword:devicePassword features:subscribedFeatures environmentId:environmentId];
}

@end

//
// Interface: TLAccountServiceSecuredConfigurationSerializer_2
//

@interface TLAccountServiceSecuredConfigurationSerializer_2 : TLSerializer

@end

//
// Implementation: TLAccountServiceSecuredConfigurationSerializer_2
//

static int ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_2 = 2;
static TLSerializer *ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_2 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLAccountServiceSecuredConfigurationSerializer_2"

@implementation TLAccountServiceSecuredConfigurationSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_2 class:[TLAccountServiceSecuredConfiguration class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLAccountServiceSecuredConfiguration *securedConfiguration = (TLAccountServiceSecuredConfiguration *)object;
    switch (securedConfiguration.authenticationAuthority) {
        case TLAccountServiceAuthenticationAuthorityDevice:
            [encoder writeEnum:0];
            break;
            
        case TLAccountServiceAuthenticationAuthorityTwinlife:
            [encoder writeEnum:1];
            break;

        case TLAccountServiceAuthenticationAuthorityUnregistered:
            [encoder writeEnum:2];
            break;

        case TLAccountServiceAuthenticationAuthorityDisabled:
            [encoder writeEnum:3];
            break;
    }
    [encoder writeBoolean:securedConfiguration.isSignOut];
    [encoder writeOptionalString:securedConfiguration.deviceUsername];
    [encoder writeOptionalString:securedConfiguration.devicePassword];
    // There is no twinlifeUsername, twinlifePassword
    [encoder writeEnum:0];
    [encoder writeEnum:0];
    [encoder writeBoolean:false];
    [encoder writeOptionalString:securedConfiguration.subscribedFeatures];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    int value = [decoder readEnum];
    TLAccountServiceAuthenticationAuthority authenticationAuthority;
    switch (value) {
        case 0:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityDevice;
            break;
            
        case 1:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityTwinlife;
            break;
            
        case 2:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            break;
            
        case 3:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityDisabled;
            break;

        default:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            break;
    }
    BOOL isSignOut = [decoder readBoolean];
    NSString *deviceUsername = [decoder readOptionalString];
    NSString *devicePassword = [decoder readOptionalString];

    // Skip the twinlifeUsername
    [decoder readOptionalString];
    // Skip the twinlifePassword
    [decoder readOptionalString];
    // Skip the rememberPassword
    [decoder readBoolean];

    NSString *subscribedFeatures = [decoder readOptionalString];

    return [[TLAccountServiceSecuredConfiguration alloc] initWithSerializerFactory:serializerFactory authenticationAuthority:authenticationAuthority isSignOut:isSignOut deviceUsername:deviceUsername devicePassword:devicePassword features:subscribedFeatures environmentId:nil];
}

@end

//
// Interface: TLAccountServiceSecuredConfigurationSerializer_1
//

@interface TLAccountServiceSecuredConfigurationSerializer_1 : TLSerializer

@end

//
// Implementation: TLAccountServiceSecuredConfigurationSerializer_1
//

static int ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_1 = 1;
static TLSerializer *ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLAccountServiceSecuredConfigurationSerializer_1"

@implementation TLAccountServiceSecuredConfigurationSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_1 class:[TLAccountServiceSecuredConfiguration class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    int value = [decoder readEnum];
    TLAccountServiceAuthenticationAuthority authenticationAuthority;
    switch (value) {
        case 0:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityDevice;
            break;
            
        case 1:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityTwinlife;
            break;
            
        default:
            authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
            break;
    }
    BOOL isSignOut = [decoder readBoolean];
    NSString *deviceUsername = [decoder readOptionalString];
    NSString *devicePassword = [decoder readOptionalString];

    // Skip the twinlifeUsername
    [decoder readOptionalString];
    // Skip the twinlifePassword
    [decoder readOptionalString];
    // Skip the rememberPassword
    [decoder readBoolean];

    return [[TLAccountServiceSecuredConfiguration alloc] initWithSerializerFactory:serializerFactory authenticationAuthority:authenticationAuthority isSignOut:isSignOut deviceUsername:deviceUsername devicePassword:devicePassword features:nil environmentId:nil];
}

@end

//
// Implementation: TLAccountServiceSecuredConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLAccountServiceSecuredConfiguration"

@implementation TLAccountServiceSecuredConfiguration

+ (void)initialize {
    
    ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"17a04202-d50a-4150-a490-de671e639dc4"];
    ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_4 = [[TLAccountServiceSecuredConfigurationSerializer_4 alloc] init];
    ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_3 = [[TLAccountServiceSecuredConfigurationSerializer_3 alloc] init];
    ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_2 = [[TLAccountServiceSecuredConfigurationSerializer_2 alloc] init];
    ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_1 = [[TLAccountServiceSecuredConfigurationSerializer_1 alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_4 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_4;
}

+ (int)SCHEMA_VERSION_3 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_2;
}

+ (int)SCHEMA_VERSION_1 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SCHEMA_VERSION_1;
}

+ (TLSerializer *)SERIALIZER_4 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_4;
}

+ (TLSerializer *)SERIALIZER_3 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_3;
}

+ (TLSerializer *)SERIALIZER_2 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_2;
}

+ (TLSerializer *)SERIALIZER_1 {
    
    return ACCOUNT_SERVICE_SECURED_CONFIGURATION_SERIALIZER_1;
}

+ (nullable TLAccountServiceSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory content:(NSData *)content {

    if (!content) {
        return nil;
    }

    NSUUID *schemaId = nil;
    int schemaVersion = -1;
    TLBinaryDecoder *binaryDecoder = [[TLBinaryDecoder alloc] initWithData:content];
    @try {
        schemaId = [binaryDecoder readUUID];
        schemaVersion = [binaryDecoder readInt];
            
        if ([[TLAccountServiceSecuredConfiguration SCHEMA_ID] isEqual:schemaId]) {
            if ([TLAccountServiceSecuredConfiguration SCHEMA_VERSION_4] == schemaVersion) {
                return (TLAccountServiceSecuredConfiguration *)[[TLAccountServiceSecuredConfiguration SERIALIZER_4] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
            if ([TLAccountServiceSecuredConfiguration SCHEMA_VERSION_3] == schemaVersion) {
                return (TLAccountServiceSecuredConfiguration *)[[TLAccountServiceSecuredConfiguration SERIALIZER_3] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
            if ([TLAccountServiceSecuredConfiguration SCHEMA_VERSION_2] == schemaVersion) {
                return (TLAccountServiceSecuredConfiguration *)[[TLAccountServiceSecuredConfiguration SERIALIZER_2] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
            if ([TLAccountServiceSecuredConfiguration SCHEMA_VERSION_1] == schemaVersion) {
                return (TLAccountServiceSecuredConfiguration *)[[TLAccountServiceSecuredConfiguration SERIALIZER_1] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
        }
    } @catch (NSException *exception) {
        // TBD
        DDLogError(@"%@ initWithSerializerFactory:accountServiceConfiguration: deserialize exception: %@", LOG_TAG, exception);
    }

    return nil;
}

+ (nullable TLAccountServiceSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory alternateApplication:(BOOL)alternateApplication {

    NSData *content = [TLKeyChain getKeyChainDataWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG alternateApplication:alternateApplication];

    return [TLAccountServiceSecuredConfiguration loadWithSerializerFactory:serializerFactory content:content];
}

+ (nullable NSData *)exportWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory {
    DDLogVerbose(@"%@ exportWithSerializerFactory", LOG_TAG);
    
    TLAccountServiceSecuredConfiguration *securedConfiguration = [TLAccountServiceSecuredConfiguration loadWithSerializerFactory:serializerFactory alternateApplication:NO];
    if (!securedConfiguration) {
        return nil;
    }

    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];
    [[TLAccountServiceSecuredConfiguration SERIALIZER_4] serializeWithSerializerFactory:serializerFactory encoder:binaryEncoder object:securedConfiguration];
    return content;
}

#ifdef TWINME_PLUS
+ (BOOL)importApplicationData:(TLSerializerFactory *)serializerFactory {
    DDLogVerbose(@"%@ importApplicationData", LOG_TAG);

    // Get the raw content and deserialize it.
    NSData *content = [TLKeyChain getKeyChainDataWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG alternateApplication:YES];

    TLAccountServiceSecuredConfiguration *config = [TLAccountServiceSecuredConfiguration loadWithSerializerFactory:serializerFactory content:content];

    // Make sure the account is valid before importing the content.
    if (!config && config.authenticationAuthority != TLAccountServiceAuthenticationAuthorityDevice) {
        return NO;
    }

    if (![TLKeyChain updateKeyChainWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
        return NO;
    }

    // Invalidate the account in the Twinme Lite application.
    config.authenticationAuthority = TLAccountServiceAuthenticationAuthorityDisabled;

    NSMutableData *updateContent = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:updateContent];
    @try {
        [[TLAccountServiceSecuredConfiguration SERIALIZER_2] serializeWithSerializerFactory:serializerFactory encoder:binaryEncoder object:config];
        
        if (![TLKeyChain updateKeyChainWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG data:updateContent alternateApplication:YES]) {
            DDLogError(@"%@ importApplicationData: updateKeyChain error", LOG_TAG);
        }
    } @catch (NSException *exception) {
        DDLogError(@"%@ importApplicationData: serialize exception: %@", LOG_TAG, exception);
    }

    return YES;
}
#endif

- (nonnull instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory authenticationAuthority:(TLAccountServiceAuthenticationAuthority)authenticationAuthority isSignOut:(BOOL)isSignOut deviceUsername:(nullable NSString *)deviceUsername devicePassword:(nullable NSString *)devicePassword features:(nullable NSString *)features environmentId:(nullable NSUUID *)environmentId {
    DDLogVerbose(@"%@ initWithIsSignOut: %@ deviceUsername: %@ devicePassword: %@ features: %@ environmentId: %@", LOG_TAG, isSignOut ? @"YES" : @"NO", deviceUsername, devicePassword, features, environmentId);
    
    self = [super init];
    
    if (self) {
        _serializerFactory = serializerFactory;
        _authenticationAuthority = authenticationAuthority;
        _isSignOut = isSignOut;
        _deviceUsername = deviceUsername;
        _devicePassword = devicePassword;
        _subscribedFeatures = features;
        _environmentId = environmentId;
        _modified = NO;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory deviceIdentifier:(nonnull NSString *)deviceIdentifier {
    DDLogVerbose(@"%@ initWithSerializerFactory: %@ deviceIdentifier: %@", LOG_TAG, serializerFactory, deviceIdentifier);

    self = [super init];
    
    if (self) {
        _serializerFactory = serializerFactory;
        // A new account is now always unregistered.
        _authenticationAuthority = TLAccountServiceAuthenticationAuthorityUnregistered;
        _isSignOut = NO;
        _deviceUsername = nil;
        _devicePassword = nil;
        _subscribedFeatures = nil;
        _modified = NO;
        _environmentId = nil;
        
        NSString *username = [NSString stringWithFormat:@"%@%@", @"device/", [[NSUUID UUID] UUIDString]];

        // Generate device password (160-bits is the max because the final string password is truncated to 32 chars).
        void *passwordData = malloc(20);
        if (!passwordData) {
            return nil;
        }
        int result = SecRandomCopyBytes(kSecRandomDefault, 20, passwordData);
        if (result != errSecSuccess) {
            free(passwordData);
            return nil;
        }

        NSData *devicePassword = [[NSData alloc] initWithBytesNoCopy:passwordData length:20];

        NSString *password = [[devicePassword base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        _deviceUsername = username;
        _devicePassword = password;

        NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];
        @try {
            [[TLAccountServiceSecuredConfiguration SERIALIZER_4] serializeWithSerializerFactory:serializerFactory encoder:binaryEncoder object:self];
            
            if (![TLKeyChain updateKeyChainWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
                    // TBD
                DDLogError(@"%@ initWithSerializerFactory:accountServiceConfiguration: createKeyChain error", LOG_TAG);
            }
        } @catch (NSException *exception) {
            // TBD
            DDLogError(@"%@ initWithSerializerFactory:accountServiceConfiguration: serialize exception: %@", LOG_TAG, exception);
        }
    }
    
    return self;
}

- (void)setAuthenticationAuthority:(TLAccountServiceAuthenticationAuthority)authenticationAuthority {

    if (_authenticationAuthority != authenticationAuthority) {
        _authenticationAuthority = authenticationAuthority;
        _isSignOut = authenticationAuthority == TLAccountServiceAuthenticationAuthorityUnregistered;
        _modified = YES;
    }
}

- (void)setEnvironmentId:(nullable NSUUID *)environmentId {

    if (_environmentId != environmentId) {
        _environmentId = environmentId;
        _modified = YES;
    }
}

- (void)setSubscribedFeatures:(NSString *)subscribedFeatures {

    _subscribedFeatures = subscribedFeatures;
    _modified = YES;
}

- (BOOL)isUpdatedWithEnvironmentId:(nullable NSUUID *)environmentId {
    
    return environmentId != nil ? ![environmentId isEqual:self.environmentId] : self.environmentId != nil;
}

- (BOOL)isUpdatedWithSubscribedFeatures:(nullable NSString *)subscribedFeatures {

    return subscribedFeatures != nil ? ![subscribedFeatures isEqual:self.subscribedFeatures] : self.subscribedFeatures != nil;
}

- (void)synchronize {
    DDLogVerbose(@"%@ synchronize", LOG_TAG);
    
    if (!self.modified) {
        return;
    }

    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];
    @try {
        [[TLAccountServiceSecuredConfiguration SERIALIZER_4] serializeWithSerializerFactory:self.serializerFactory encoder:binaryEncoder object:self];
        
        if (![TLKeyChain updateKeyChainWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
            // TBD
            DDLogError(@"%@ initWithSerializerFactory:synchronize: updateKeyChain error", LOG_TAG);
        } else {
            _modified = NO;
        }
    } @catch (NSException *exception) {
        // TBD
        DDLogError(@"%@ initWithSerializerFactory:synchronize: serialize exception: %@", LOG_TAG, exception);
    }
}

- (void)erase {
    DDLogVerbose(@"%@ erase", LOG_TAG);
    
    _isSignOut = YES;
    _modified = NO;

    if (![TLKeyChain removeKeyChainWithKey:ACCOUNT_SERVICE_SECURED_CONFIGURATION_KEY tag:ACCOUNT_SERVICE_SECURED_CONFIGURATION_TAG]) {
        DDLogError(@"%@ erase: removeKeyChainWithKey error", LOG_TAG);
    }
    
    // Erase everything from the keychain to make sure we don't try to use the device secure information again.
    [TLKeyChain removeAllKeyChain];
}

@end


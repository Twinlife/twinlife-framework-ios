/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLTwinlifeSecuredConfiguration.h"

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
 * Important note 2024-07-09:
 *  iOS and Android were using different schema from the beginning: "3e20d024-2dcb-4a60-9331-216849fc3065" for iOS and
 *  "0e20d024-2dcb-4a60-9331-216849fc3065" for Android.
 *
 * <pre>
 * Schema version 3
 *  Date: 2023/01/26 [iOS]
 *
 * {
 *  "type":"record",
 *  "name":"TwinlifeSecuredConfiguration",
 *  "namespace":"org.twinlife.schemas",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"databaseKey", [null, "type":"string"]}
 *   {"name":"deviceIdentifier", [null, "type":"string"]}
 *   {"name":"oldDatabaseKey", [null, "type":"string"]}
 * }
 *
 * Schema version 2
 *  Date: 2020/09/07 [iOS]
 *  Date: 2019/10/07 [Android]
 *
 * {
 *  "type":"record",
 *  "name":"TwinlifeSecuredConfiguration",
 *  "namespace":"org.twinlife.schemas",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"databaseKey", [null, "type":"string"]}
 *   {"name":"deviceIdentifier", [null, "type":"string"]}
 * }
 *
 * Schema version 1
 *  Date: 2017/06/21
 *
 * {
 *  "type":"record",
 *  "name":"TwinlifeSecuredConfiguration",
 *  "namespace":"org.twinlife.schemas",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"databaseKey", [null, "type":"string"]}
 * }
 *
 * </pre>
 */


@interface TLTwinlifeSecuredConfiguration ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLSerializer *)SERIALIZER_1;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLSerializer *)SERIALIZER_2;

+ (int)SCHEMA_VERSION_3;

+ (nonnull TLSerializer *)SERIALIZER_3;

- (nonnull instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory databaseKey:(nullable NSString *)databaseKey deviceIdentifier:(nonnull NSString *)deviceIdentifier oldDatabaseKey:(nullable NSString *)oldDatabaseKey;

@end

//
// Interface: TLTwinlifeSecuredConfigurationSerializer_3
//

@interface TLTwinlifeSecuredConfigurationSerializer_3 : TLSerializer

@end

//
// Implementation: TLTwinlifeSecuredConfigurationSerializer_3
//

static NSUUID *TWINLIFE_SECURED_CONFIGURATION_SCHEMA_ID = nil;
static int TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_3 = 3;
static TLSerializer *TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_3 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLTwinlifeSecuredConfigurationSerializer_3"

@implementation TLTwinlifeSecuredConfigurationSerializer_3

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TWINLIFE_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_3 class:[TLTwinlifeSecuredConfiguration class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLTwinlifeSecuredConfiguration *securedConfiguration = (TLTwinlifeSecuredConfiguration *)object;
    [encoder writeOptionalString:securedConfiguration.databaseKey];
    [encoder writeString:securedConfiguration.deviceIdentifier];
    [encoder writeOptionalString:securedConfiguration.oldDatabaseKey];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    NSString *databaseKey = [decoder readOptionalString];
    NSString *deviceIdentifier = [decoder readString];
    NSString *oldDatabaseKey = [decoder readOptionalString];
    return [[TLTwinlifeSecuredConfiguration alloc] initWithSerializerFactory:serializerFactory databaseKey:databaseKey deviceIdentifier:deviceIdentifier oldDatabaseKey:oldDatabaseKey];
}

@end

//
// Interface: TLTwinlifeSecuredConfigurationSerializer_2
//

@interface TLTwinlifeSecuredConfigurationSerializer_2 : TLSerializer

@end

//
// Implementation: TLTwinlifeSecuredConfigurationSerializer_2
//

static int TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_2 = 2;
static TLSerializer *TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_2 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLTwinlifeSecuredConfigurationSerializer_2"

@implementation TLTwinlifeSecuredConfigurationSerializer_2

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TWINLIFE_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_2 class:[TLTwinlifeSecuredConfiguration class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLTwinlifeSecuredConfiguration *securedConfiguration = (TLTwinlifeSecuredConfiguration *)object;
    if (!securedConfiguration.databaseKey) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeString:securedConfiguration.databaseKey];
    }
    [encoder writeString:securedConfiguration.deviceIdentifier];
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    NSString *databaseKey = nil;
    int position = [decoder readEnum];
    if (position == 1) {
        databaseKey = [decoder readString];
    }
    NSString *deviceIdentifier = [decoder readString];
    return [[TLTwinlifeSecuredConfiguration alloc] initWithSerializerFactory:serializerFactory databaseKey:databaseKey deviceIdentifier:deviceIdentifier oldDatabaseKey:nil];
}

@end

//
// Interface: TLTwinlifeSecuredConfigurationSerializer_1
//

@interface TLTwinlifeSecuredConfigurationSerializer_1 : TLSerializer

@end

//
// Implementation: TLTwinlifeSecuredConfigurationSerializer_1
//

static int TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_1 = 1;
static TLSerializer *TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLTwinlifeSecuredConfigurationSerializer_1"

@implementation TLTwinlifeSecuredConfigurationSerializer_1

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TWINLIFE_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_1 class:[TLTwinlifeSecuredConfiguration class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLTwinlifeSecuredConfiguration *securedConfiguration = (TLTwinlifeSecuredConfiguration *)object;
    if (!securedConfiguration.databaseKey) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        [encoder writeString:securedConfiguration.databaseKey];
    }
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    NSString *databaseKey = nil;
    int position = [decoder readEnum];
    if (position == 1) {
        databaseKey = [decoder readString];
    }
    NSString *deviceIdentifier = [[NSUUID UUID] UUIDString];
    return [[TLTwinlifeSecuredConfiguration alloc] initWithSerializerFactory:serializerFactory databaseKey:databaseKey deviceIdentifier:deviceIdentifier oldDatabaseKey:nil];
}

@end

//
// Implementation: TLTwinlifeAppSecuredConfigurationSerializer_2
//

static NSUUID *TWINLIFE_APP_SECURED_CONFIGURATION_SCHEMA_ID = nil;
static int TWINLIFE_APP_SECURED_CONFIGURATION_SCHEMA_VERSION_2 = 2;
static TLSerializer *TWINLIFE_APP_SECURED_CONFIGURATION_SERIALIZER_2 = nil;

//
// Interface: TLTwinlifeAppSecuredConfigurationSerializer_2
//

@interface TLTwinlifeAppSecuredConfigurationSerializer_2 : TLTwinlifeSecuredConfigurationSerializer_2

@end

#undef LOG_TAG
#define LOG_TAG @"TLTwinlifeAppSecuredConfigurationSerializer_2"

@implementation TLTwinlifeAppSecuredConfigurationSerializer_2

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TWINLIFE_APP_SECURED_CONFIGURATION_SCHEMA_ID schemaVersion:TWINLIFE_APP_SECURED_CONFIGURATION_SCHEMA_VERSION_2 class:[TLTwinlifeSecuredConfiguration class]];
    return self;
}

@end

//
// Interface: TLTwinlifeSecuredConfiguration ()
//

@interface TLTwinlifeSecuredConfiguration ()

@property TLSerializerFactory *serializerFactory;

@end

//
// Implementation: TLTwinlifeSecuredConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLTwinlifeSecuredConfiguration"

@implementation TLTwinlifeSecuredConfiguration

+ (void)initialize {
    
    // iOS legacy schema
    TWINLIFE_SECURED_CONFIGURATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"3e20d024-2dcb-4a60-9331-216849fc3065"];
    TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_1 = [[TLTwinlifeSecuredConfigurationSerializer_1 alloc] init];
    TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_2 = [[TLTwinlifeSecuredConfigurationSerializer_2 alloc] init];
    TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_3 = [[TLTwinlifeSecuredConfigurationSerializer_3 alloc] init];
    
    // Android and Desktop compatible schema which must be used after 2024-07-09.
    TWINLIFE_APP_SECURED_CONFIGURATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"0e20d024-2dcb-4a60-9331-216849fc3065"];
    TWINLIFE_APP_SECURED_CONFIGURATION_SERIALIZER_2 = [[TLTwinlifeAppSecuredConfigurationSerializer_2 alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return TWINLIFE_SECURED_CONFIGURATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_3 {
    
    return TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_2;
}

+ (int)SCHEMA_VERSION_1 {
    
    return TWINLIFE_SECURED_CONFIGURATION_SCHEMA_VERSION_1;
}

+ (TLSerializer *)SERIALIZER_3 {
    
    return TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_3;
}

+ (TLSerializer *)SERIALIZER_2 {
    
    return TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_2;
}

+ (TLSerializer *)SERIALIZER_1 {
    
    return TWINLIFE_SECURED_CONFIGURATION_SERIALIZER_1;
}

+ (nullable NSString *)generateDatabaseKey {
    DDLogVerbose(@"%@ generateDatabaseKey", LOG_TAG);

    // Generate a new 32 bytes key followed by a 16 bytes random salf.
    // (See https://www.zetetic.net/sqlcipher/sqlcipher-api/#key)
    unsigned char* randData = (unsigned char*) malloc(48);
    if (!randData) {
        return nil;
    }
    int result = SecRandomCopyBytes(kSecRandomDefault, 48, randData);
    if (result != errSecSuccess) {
        free(randData);
        return nil;
    }

    NSMutableString *newKey = [NSMutableString stringWithCapacity:100];
    for (int i = 0; i < 48; i++) {
        [newKey appendFormat:@"%02x", randData[i]];
    }
    free(randData);

    assert(newKey.length == 96);

    DDLogVerbose(@"%@ generateDatabaseKey => %@", LOG_TAG, newKey);
    return newKey;
}

#ifdef TWINME_PLUS
+ (BOOL)importApplicationData {
    DDLogVerbose(@"%@ importApplicationData", LOG_TAG);

    NSData *content = [TLKeyChain getKeyChainDataWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG alternateApplication:YES];
    if (!content) {
        return NO;
    }
    
    return [TLKeyChain updateKeyChainWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO];
}
#endif

+ (nullable TLTwinlifeSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory alternateApplication:(BOOL)alternateApplication {
    return [TLTwinlifeSecuredConfiguration loadWithSerializerFactory:serializerFactory key:TWINLIFE_SECURED_CONFIGURATION_KEY alternateApplication:alternateApplication];
}

+ (nullable TLTwinlifeSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory key:(nonnull NSString *)key alternateApplication:(BOOL)alternateApplication {

    DDLogVerbose(@"%@ loadWithSerializerFactory: %@ alternateApplication: %d", LOG_TAG, serializerFactory, alternateApplication);

    NSData *content = [TLKeyChain getKeyChainDataWithKey:key tag:TWINLIFE_SECURED_CONFIGURATION_TAG alternateApplication:alternateApplication];
    if (!content) {
        return nil;
    }

    NSUUID *schemaId = nil;
    int schemaVersion = -1;
    TLBinaryDecoder *binaryDecoder = [[TLBinaryDecoder alloc] initWithData:content];
    @try {
        schemaId = [binaryDecoder readUUID];
        schemaVersion = [binaryDecoder readInt];
        
        // Check for correct schema id: we can only have version 2 because version 1 (2017/06/21)
        // is never exported (see Android implementation).
        if ([TWINLIFE_APP_SECURED_CONFIGURATION_SCHEMA_ID isEqual:schemaId]) {
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_2] == schemaVersion) {
                return (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_2] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
        } else if ([[TLTwinlifeSecuredConfiguration SCHEMA_ID] isEqual:schemaId]) {
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_3] == schemaVersion) {
                return (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_3] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_2] == schemaVersion) {
                return (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_2] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_1] == schemaVersion) {
                TLTwinlifeSecuredConfiguration *twinlifeSecuredConfiguration = (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_1] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];

                if (!alternateApplication) {
                    // Save configuration because we have a new deviceIdentifier that must be saved.
                    @try {
                        NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
                        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];

                        [[TLTwinlifeSecuredConfiguration SERIALIZER_2] serializeWithSerializerFactory:serializerFactory encoder:binaryEncoder object:twinlifeSecuredConfiguration];
                        if (![TLKeyChain updateKeyChainWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
                            DDLogError(@"%@ loadWithSerializerFactory:twinlifeConfiguration: updateKeyChainWithKey error 2", LOG_TAG);
                        }
                    } @catch (NSException *exception) {
                        DDLogError(@"%@ loadWithSerializerFactory:twinlifeConfiguration: serialize exception: %@", LOG_TAG, exception);
                    }
                }

                return twinlifeSecuredConfiguration;
            }
        }
    } @catch (NSException *exception) {
        // TBD
        DDLogError(@"%@ initWithSerializerFactory:twinlifeConfiguration: deserialize exception: %@", LOG_TAG, exception);
    }

    return nil;
}

+ (nullable TLTwinlifeSecuredConfiguration *)loadWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory content:(nonnull NSData *)content {
    DDLogVerbose(@"%@ loadWithSerializerFactory: %@ data: %@", LOG_TAG, serializerFactory, content);

    NSUUID *schemaId = nil;
    int schemaVersion = -1;
    TLBinaryDecoder *binaryDecoder = [[TLBinaryDecoder alloc] initWithData:content];
    @try {
        schemaId = [binaryDecoder readUUID];
        schemaVersion = [binaryDecoder readInt];
        
        // Check for correct schema id: we can only have version 2 because version 1 (2017/06/21)
        // is never exported (see Android implementation).
        if ([TWINLIFE_APP_SECURED_CONFIGURATION_SCHEMA_ID isEqual:schemaId]) {
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_2] == schemaVersion) {
                return (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_2] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
        } else if ([[TLTwinlifeSecuredConfiguration SCHEMA_ID] isEqual:schemaId]) {
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_3] == schemaVersion) {
                return (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_3] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_2] == schemaVersion) {
                return (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_2] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];
            }
            if ([TLTwinlifeSecuredConfiguration SCHEMA_VERSION_1] == schemaVersion) {
                TLTwinlifeSecuredConfiguration *twinlifeSecuredConfiguration = (TLTwinlifeSecuredConfiguration *)[[TLTwinlifeSecuredConfiguration SERIALIZER_1] deserializeWithSerializerFactory:serializerFactory decoder:binaryDecoder];

                return twinlifeSecuredConfiguration;
            }
        }
    } @catch (NSException *exception) {
        // TBD
        DDLogError(@"%@ initWithSerializerFactory:twinlifeConfiguration: deserialize exception: %@", LOG_TAG, exception);
    }

    return nil;
}

+ (nullable NSData *)exportWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory {
    DDLogVerbose(@"%@ exportWithSerializerFactory: %@", LOG_TAG, serializerFactory);
    
    TLTwinlifeSecuredConfiguration *twinlifeSecuredConfiguration = [TLTwinlifeSecuredConfiguration loadWithSerializerFactory:serializerFactory alternateApplication:NO];
    if (!twinlifeSecuredConfiguration) {
        return nil;
    }

    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];

    [TWINLIFE_APP_SECURED_CONFIGURATION_SERIALIZER_2 serializeWithSerializerFactory:serializerFactory encoder:binaryEncoder object:twinlifeSecuredConfiguration];
    return content;
}

- (nonnull instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory databaseKey:(nullable NSString *)databaseKey deviceIdentifier:(nonnull NSString *)deviceIdentifier oldDatabaseKey:(nullable NSString *)oldDatabaseKey {
    DDLogVerbose(@"%@ initWithSerializerFactory: %@ databaseKey: %@ deviceIdentifier: %@", LOG_TAG, serializerFactory, databaseKey, deviceIdentifier);
    
    self = [super init];
    
    if (self) {
        _serializerFactory = serializerFactory;
        _databaseKey = databaseKey;
        _deviceIdentifier = deviceIdentifier;
        _oldDatabaseKey = oldDatabaseKey;
    }
    
    return self;
}

- (nullable instancetype)initWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory {
    DDLogVerbose(@"%@ initWithSerializerFactory: %@", LOG_TAG, serializerFactory);

    self = [super init];
    
    if (self) {
        _serializerFactory = serializerFactory;
        _databaseKey = [TLTwinlifeSecuredConfiguration generateDatabaseKey];
        _deviceIdentifier = [[NSUUID UUID] UUIDString];
        _oldDatabaseKey = nil;
        NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];
        @try {
            [[TLTwinlifeSecuredConfiguration SERIALIZER_2] serializeWithSerializerFactory:serializerFactory encoder:binaryEncoder object:self];
            if (![TLKeyChain updateKeyChainWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
                // TBD
                DDLogError(@"%@ initWithSerializerFactory:twinlifeConfiguration: createKeyChain error", LOG_TAG);
                return nil;
            }
        } @catch (NSException *exception) {
            // TBD
            DDLogError(@"%@ initWithSerializerFactory:twinlifeConfiguration: serialize exception: %@", LOG_TAG, exception);
            return nil;
        }
    }
    return self;
}

- (BOOL)changeDatabaseKeyWithKey:(nonnull NSString *)key {
    DDLogVerbose(@"%@ changeDatabaseKeyWithKey: %@", LOG_TAG, key);

    // Keep the old database key if the new key is for cipher V4.
    if (key.length == 96) {
        _oldDatabaseKey = _databaseKey;
    }
    _databaseKey = key;
    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];
    @try {
        [[TLTwinlifeSecuredConfiguration SERIALIZER_3] serializeWithSerializerFactory:self.serializerFactory encoder:binaryEncoder object:self];

        if (![TLKeyChain updateKeyChainWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG data:content alternateApplication:NO]) {
            DDLogError(@"%@ changeDatabaseKeyWithKey updateKeyChainWithKey error", LOG_TAG);
            return NO;
        }
        DDLogWarn(@"%@ configuration (database key) was updated successfully", LOG_TAG);
        return YES;

    } @catch (NSException *exception) {
        DDLogError(@"%@ changeDatabaseKeyWithKey: serialize exception: %@", LOG_TAG, exception);
        return NO;
    }
}

- (void)erase {
    DDLogVerbose(@"%@ erase", LOG_TAG);

    if (![TLKeyChain removeKeyChainWithKey:TWINLIFE_SECURED_CONFIGURATION_KEY tag:TWINLIFE_SECURED_CONFIGURATION_TAG]) {
        DDLogError(@"%@ erase: removeKeyChainWithKey error", LOG_TAG);
    }
}

- (nonnull NSData *)exportWithKey:(nonnull NSString *)key {
    DDLogVerbose(@"%@ exportWithKey: %@", LOG_TAG, key);

    _databaseKey = key;
    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:content];
    [TWINLIFE_APP_SECURED_CONFIGURATION_SERIALIZER_2 serializeWithSerializerFactory:self.serializerFactory encoder:binaryEncoder object:self];

    return content;
}

@end


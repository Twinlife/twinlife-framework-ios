/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConfigIdentifier.h"
#import "TLTwinlife.h"
#import "TLTwincode.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static NSMutableDictionary<NSUUID *, TLConfigIdentifier *> *configRegistry;

//
// TLConfigIdentifier
//

@interface TLConfigIdentifier ()

- (nonnull instancetype)initWithName:(nonnull NSString *)name;

- (nonnull instancetype)initWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid;

- (BOOL)isShared;

@end

#undef LOG_TAG
#define LOG_TAG @"TLConfigIdentifier"

@implementation TLConfigIdentifier

+ (void)initialize {
    
    if (!configRegistry) {
        configRegistry = [[NSMutableDictionary alloc] init];
    }
}

+ (nonnull NSDictionary<NSUUID *, TLConfigIdentifier *> *)configs {
    
    return configRegistry;
}

+ (nonnull NSDictionary<NSUUID *, NSString *> *)exportConfig {
    DDLogVerbose(@"%@ exportConfig", LOG_TAG);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSUserDefaults *sharedUserDefaults = [TLTwinlife getAppSharedUserDefaults];
    NSMutableDictionary<NSUUID *, NSString *> *result = [[NSMutableDictionary alloc] initWithCapacity:configRegistry.count];
    for (NSUUID *uuid in configRegistry) {
        TLConfigIdentifier *config = configRegistry[uuid];
        NSString *value;

        if ([config isShared]) {
            value = [sharedUserDefaults stringForKey:config.name];
        } else {
            value = [userDefaults stringForKey:config.name];
        }
        if (value) {
            [result setObject:value forKey:uuid];
        }
    }
    return result;
}

+ (void)importConfig:(nonnull NSDictionary<NSUUID *, NSString *> *)values {
    DDLogVerbose(@"%@ importConfig: %@", LOG_TAG, values);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSUserDefaults *sharedUserDefaults = [TLTwinlife getAppSharedUserDefaults];

    // Before importing new values, erase existing ones because default values
    // are not sent in the device migration process.
    for (TLConfigIdentifier *config in configRegistry.allValues) {
        if ([config isShared]) {
            [sharedUserDefaults removeObjectForKey:config.name];
        } else {
            [userDefaults removeObjectForKey:config.name];
        }
    }
    for (NSUUID *uuid in values) {
        TLConfigIdentifier *config = [configRegistry objectForKey:uuid];
        if (config) {
            NSString *value = [values objectForKey:uuid];

            DDLogVerbose(@"%@ import: %@=%@", LOG_TAG, config.name, value);

            if ([config isShared]) {
                [sharedUserDefaults setValue:value forKey:config.name];
            } else {
                [userDefaults setValue:value forKey:config.name];
            }
        }
    }
    [userDefaults synchronize];
    [sharedUserDefaults synchronize];
}

- (nonnull instancetype)initWithName:(nonnull NSString *)name {

    self = [super init];
    if (self) {
        _name = name;
        _uuid = [TLTwincode NOT_DEFINED];
    }
    return self;
}

- (nonnull instancetype)initWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid {

    self = [super init];
    if (self) {
        _name = name;
        _uuid = [[NSUUID alloc] initWithUUIDString:uuid];
        [configRegistry setObject:self forKey:_uuid];
    }
    return self;
}

+ (nonnull TLConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@", LOG_TAG, name, uuid);

    return [[TLConfigIdentifier alloc] initWithName:name uuid:uuid];
}

- (void)remove {
    DDLogVerbose(@"%@ remove: %@", LOG_TAG, self.name);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObjectForKey:self.name];
    [userDefaults synchronize];
}

- (BOOL)isShared {
    
    return NO;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLUUIDConfigIdentifier"

@implementation TLUUIDConfigIdentifier

+ (nonnull TLUUIDConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@", LOG_TAG, name, uuid);

    return [[TLUUIDConfigIdentifier alloc] initWithName:name uuid:uuid];
}

- (nullable NSUUID *)uuidValue {

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSUUID * result = [[NSUUID alloc] initWithUUIDString:[userDefaults stringForKey:self.name]];
    DDLogVerbose(@"%@ uuidValue.%@=%@", LOG_TAG, self.name, result);
    return result;
}

- (void)setUuidValue:(nullable NSUUID *)value {
    DDLogVerbose(@"%@ setUuidValue: %@ value: %@", LOG_TAG, self.name, value);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (!value) {
        [userDefaults removeObjectForKey:self.name];
    } else {
        [userDefaults setObject:value.UUIDString forKey:self.name];
    }
    [userDefaults synchronize];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLStringConfigIdentifier"

@implementation TLStringConfigIdentifier

+ (nonnull TLStringConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@", LOG_TAG, name, uuid);

    return [[TLStringConfigIdentifier alloc] initWithName:name uuid:uuid];
}

- (nullable NSString *)stringValue {

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    NSString *result = [userDefaults stringForKey:self.name];
    DDLogVerbose(@"%@ stringValue.%@=%@", LOG_TAG, self.name, result);
    return result;
}

- (void)setStringValue:(nullable NSString *)value {
    DDLogVerbose(@"%@ setStringValue: %@ value: %@", LOG_TAG, self.name, value);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (!value) {
        [userDefaults removeObjectForKey:self.name];
    } else {
        [userDefaults setObject:value forKey:self.name];
    }
    [userDefaults synchronize];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLStringSharedConfigIdentifier"

@implementation TLStringSharedConfigIdentifier

+ (nonnull TLStringSharedConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@", LOG_TAG, name, uuid);

    return [[TLStringSharedConfigIdentifier alloc] initWithName:name uuid:uuid];
}

- (nullable NSString *)stringValue {

    NSUserDefaults *sharedUserDefaults = [TLTwinlife getAppSharedUserDefaults];

    NSString *result = [sharedUserDefaults stringForKey:self.name];
    DDLogVerbose(@"%@ stringValue.%@=%@", LOG_TAG, self.name, result);
    return result;
}

- (void)setStringValue:(nullable NSString *)value {
    DDLogVerbose(@"%@ setStringValue: %@ value: %@", LOG_TAG, self.name, value);

    NSUserDefaults *sharedUserDefaults = [TLTwinlife getAppSharedUserDefaults];
    if (!value) {
        [sharedUserDefaults removeObjectForKey:self.name];
    } else {
        [sharedUserDefaults setObject:value forKey:self.name];
    }
    [sharedUserDefaults synchronize];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLBooleanConfigIdentifier"

@implementation TLBooleanConfigIdentifier

- (nonnull instancetype)initWithName:(nonnull NSString *)name defaultValue:(BOOL)defaultValue {

    self = [super initWithName:name];
    if (self) {
        _defaultValue = defaultValue;
    }
    return self;
}

- (nonnull instancetype)initWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(BOOL)defaultValue {

    self = [super initWithName:name uuid:uuid];
    if (self) {
        _defaultValue = defaultValue;
    }
    return self;
}

+ (nonnull TLBooleanConfigIdentifier *)defineWithName:(nonnull NSString *)name defaultValue:(BOOL)defaultValue {
    DDLogVerbose(@"%@ defineWithName: %@", LOG_TAG, name);

    return [[TLBooleanConfigIdentifier alloc] initWithName:name defaultValue:defaultValue];
}

+ (nonnull TLBooleanConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(BOOL)defaultValue {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@", LOG_TAG, name, uuid);

    return [[TLBooleanConfigIdentifier alloc] initWithName:name uuid:uuid defaultValue:defaultValue];
}

- (BOOL)boolValue {

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    id object = [userDefaults objectForKey:self.name];
    BOOL result = object ? [object boolValue] : self.defaultValue;
    DDLogVerbose(@"%@ boolValue.%@=%@", LOG_TAG, self.name, result ? @"YES" : @"NO");
    return result;
}

- (void)setBoolValue:(BOOL)value {
    DDLogVerbose(@"%@ setBoolValue: %@ value: %@", LOG_TAG, self.name, value ? @"YES" : @"NO");

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:value forKey:self.name];
    [userDefaults synchronize];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLBooleanSharedConfigIdentifier"

@implementation TLBooleanSharedConfigIdentifier

- (nonnull instancetype)initWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(BOOL)defaultValue {

    self = [super initWithName:name uuid:uuid];
    if (self) {
        _defaultValue = defaultValue;
    }
    return self;
}

+ (nonnull TLBooleanSharedConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(BOOL)defaultValue {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@", LOG_TAG, name, uuid);

    return [[TLBooleanSharedConfigIdentifier alloc] initWithName:name uuid:uuid defaultValue:defaultValue];
}

- (BOOL)boolValue {

    NSUserDefaults *sharedUserDefaults = [TLTwinlife getAppSharedUserDefaults];

    id object = [sharedUserDefaults objectForKey:self.name];
    BOOL result = object ? [object boolValue] : self.defaultValue;
    DDLogVerbose(@"%@ boolValue.%@=%@", LOG_TAG, self.name, result ? @"YES" : @"NO");
    return result;
}

- (void)setBoolValue:(BOOL)value {
    DDLogVerbose(@"%@ setBoolValue: %@ value: %@", LOG_TAG, self.name, value ? @"YES" : @"NO");

    NSUserDefaults *sharedUserDefaults = [TLTwinlife getAppSharedUserDefaults];
    [sharedUserDefaults setBool:value forKey:self.name];
    [sharedUserDefaults synchronize];
}

- (BOOL)isShared {
    
    return YES;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLIntegerConfigIdentifier"

@implementation TLIntegerConfigIdentifier

- (nonnull instancetype)initWithName:(nonnull NSString *)name defaultValue:(int)defaultValue {

    self = [super initWithName:name];
    if (self) {
        _defaultValue = defaultValue;
    }
    return self;
}

- (nonnull instancetype)initWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(int)defaultValue {

    self = [super initWithName:name uuid:uuid];
    if (self) {
        _defaultValue = defaultValue;
    }
    return self;
}

+ (nonnull TLIntegerConfigIdentifier *)defineWithName:(nonnull NSString *)name defaultValue:(int)defaultValue {
    DDLogVerbose(@"%@ defineWithName: %@ defaultValue: %d", LOG_TAG, name, defaultValue);

    return [[TLIntegerConfigIdentifier alloc] initWithName:name defaultValue:defaultValue];
}

+ (nonnull TLIntegerConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(int)defaultValue {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@ defaultValue: %d", LOG_TAG, name, uuid, defaultValue);

    return [[TLIntegerConfigIdentifier alloc] initWithName:name uuid:uuid defaultValue:defaultValue];
}

- (int)intValue {

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    id object = [userDefaults objectForKey:self.name];
    int result = object ? (int)[object integerValue] : self.defaultValue;
    DDLogVerbose(@"%@ intValue.%@=%d", LOG_TAG, self.name, result);
    return result;
}

- (void)setIntValue:(int)value {
    DDLogVerbose(@"%@ setIntValue: %@ value: %d", LOG_TAG, self.name, value);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:value forKey:self.name];
    [userDefaults synchronize];
}

- (int64_t)int64Value {

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    id object = [userDefaults objectForKey:self.name];
    int64_t result = object ? [object longLongValue] : self.defaultValue;
    DDLogVerbose(@"%@ intValue.%@=%lld", LOG_TAG, self.name, result);
    return result;
}

- (void)setInt64Value:(int64_t)value {
    DDLogVerbose(@"%@ setInt64Value: %@ value: %lld", LOG_TAG, self.name, value);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[NSNumber numberWithLongLong:value] forKey:self.name];
    [userDefaults synchronize];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLFloatConfigIdentifier"

@implementation TLFloatConfigIdentifier

- (nonnull instancetype)initWithName:(nonnull NSString *)name defaultValue:(float)defaultValue {

    self = [super initWithName:name];
    if (self) {
        _defaultValue = defaultValue;
    }
    return self;
}

- (nonnull instancetype)initWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(float)defaultValue {

    self = [super initWithName:name uuid:uuid];
    if (self) {
        _defaultValue = defaultValue;
    }
    return self;
}

+ (nonnull TLFloatConfigIdentifier *)defineWithName:(nonnull NSString *)name defaultValue:(float)defaultValue {
    DDLogVerbose(@"%@ defineWithName: %@ defaultValue: %f", LOG_TAG, name, defaultValue);

    return [[TLFloatConfigIdentifier alloc] initWithName:name defaultValue:defaultValue];
}

+ (nonnull TLFloatConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(float)defaultValue {
    DDLogVerbose(@"%@ defineWithName: %@ uuid: %@ defaultValue: %f", LOG_TAG, name, uuid, defaultValue);

    return [[TLFloatConfigIdentifier alloc] initWithName:name uuid:uuid defaultValue:defaultValue];
}

- (float)floatValue {

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    float result = [userDefaults objectForKey:self.name] ? [userDefaults floatForKey:self.name] : self.defaultValue;
    DDLogVerbose(@"%@ floatValue.%@=%f", LOG_TAG, self.name, result);
    return result;
}

- (void)setFloatValue:(float)value {
    DDLogVerbose(@"%@ setFloatValue: %@ value: %f", LOG_TAG, self.name, value);

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setFloat:value forKey:self.name];
    [userDefaults synchronize];
}

@end

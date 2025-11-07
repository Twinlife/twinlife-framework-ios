/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

/**
 * Configuration identifier that describes a configuration parameter which is recognized by the
 * account migration service and can migrate between two devices.
 * <p>
 * The UUID identifier is unique and must be the same between different implementations (Android, iOS, Desktop).
 * <p>
 * The configuration name and parameter name are specific to the implementation.
 * They can be different between Android, iOS and Desktop.
 * <p>
 * On Android, we must use the `ConfigurationService` to load and save values buy on iOS we don't have
 * the constraint of Android application Context and we can get/set on the configuration instance directly.
 * <p>
 * The `TLConfigIdentifier` class is the root class for every configuration and values are available throught
 * the `TL<type>ConfigIdentifier` classes.
 */

//
// Interface: TLConfigIdentifier
//

@interface TLConfigIdentifier : NSObject

@property (readonly, nonnull) NSString *name;
@property (readonly, nonnull) NSUUID *uuid;

- (void)remove;

/// Export the list of configuration parameters saved in user's preference and that the migration must take into account.
+ (nonnull NSDictionary<NSUUID *, NSString *> *)exportConfig;

/// Import from the migration a list of configuration parameters to restore in the user's preference.
+ (void)importConfig:(nonnull NSDictionary<NSUUID *, NSString *> *)values;

@end

//
// Interface: TLUUIDConfigIdentifier
//

@interface TLUUIDConfigIdentifier : TLConfigIdentifier

@property (nullable) NSUUID *uuidValue;

+ (nonnull TLUUIDConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid;

@end

//
// Interface: TLStringConfigIdentifier
//

@interface TLStringConfigIdentifier : TLConfigIdentifier

@property (nullable) NSString *stringValue;

+ (nonnull TLStringConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid;

@end

//
// Interface: TLStringSharedConfigIdentifier
//

@interface TLStringSharedConfigIdentifier : TLConfigIdentifier

@property (nullable) NSString *stringValue;

+ (nonnull TLStringSharedConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid;

@end

//
// Interface: TLBooleanConfigIdentifier
//

@interface TLBooleanConfigIdentifier : TLConfigIdentifier

@property (readonly) BOOL defaultValue;
@property BOOL boolValue;

+ (nonnull TLBooleanConfigIdentifier *)defineWithName:(nonnull NSString *)name defaultValue:(BOOL)defaultValue;

+ (nonnull TLBooleanConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(BOOL)defaultValue;

@end

//
// Interface: TLBooleanSharedConfigIdentifier
//
// Same as TLBooleanConfigIdentifier but shared with the ShareExtension (only used for specific properties).
//
@interface TLBooleanSharedConfigIdentifier : TLConfigIdentifier

@property (readonly) BOOL defaultValue;
@property BOOL boolValue;

+ (nonnull TLBooleanSharedConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(BOOL)defaultValue;

@end

//
// Interface: TLIntegerConfigIdentifier
//

@interface TLIntegerConfigIdentifier : TLConfigIdentifier

@property (readonly) int defaultValue;
@property int intValue;

@property int64_t int64Value;

+ (nonnull TLIntegerConfigIdentifier *)defineWithName:(nonnull NSString *)name defaultValue:(int)defaultValue;

+ (nonnull TLIntegerConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(int)defaultValue;

@end

//
// Interface: TLFloatConfigIdentifier
//

@interface TLFloatConfigIdentifier : TLConfigIdentifier

@property (readonly) float defaultValue;
@property float floatValue;

+ (nonnull TLFloatConfigIdentifier *)defineWithName:(nonnull NSString *)name defaultValue:(float)defaultValue;

+ (nonnull TLFloatConfigIdentifier *)defineWithName:(nonnull NSString *)name uuid:(nonnull NSString *)uuid defaultValue:(float)defaultValue;

@end

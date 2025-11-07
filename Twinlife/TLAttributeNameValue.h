/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLExportedImageId;

//
// Interface: TLAttributeNameValue
//

@interface TLAttributeNameValue : NSObject

@property (nullable) NSString *name;
@property (nullable) NSObject *value;

- (nonnull instancetype)initWithName:(nullable NSString *)name value:(nonnull NSObject *)value;

+ (nullable TLAttributeNameValue *)getAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list;

+ (nullable NSString *)getStringAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list;

+ (nullable NSUUID *)getUUIDAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list;

+ (int64_t)getLongAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list defaultValue:(int64_t)defaultValue;

+ (nullable TLAttributeNameValue *)removeAttributeWithName:(nonnull NSString *)name list:(nonnull NSMutableArray<TLAttributeNameValue *> *)list;

@end

//
// Interface: TLAttributeNameBooleanValue
//

@interface TLAttributeNameBooleanValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name boolValue:(BOOL)boolValue;

@end

//
// Interface: TLAttributeNameLongValue
//

@interface TLAttributeNameLongValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name longValue:(int64_t)longValue;

@end

//
// Interface: TLAttributeNameStringValue
//

@interface TLAttributeNameStringValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name stringValue:(nonnull NSString *)stringValue;

@end

//
// Interface: TLAttributeNameUUIDValue
//

@interface TLAttributeNameUUIDValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name uuidValue:(nonnull NSUUID *)uuidValue;

@end

//
// Interface: TLAttributeNameImageIdValue
//

@interface TLAttributeNameImageIdValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name imageId:(nonnull TLExportedImageId *)imageId;

@end

//
// Interface: TLAttributeNameVoidValue
//

@interface TLAttributeNameVoidValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name;

@end

//
// Interface: TLAttributeNameListValue
//

@interface TLAttributeNameListValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name listValue:(nonnull NSArray<TLAttributeNameValue *> *)listValue;

@end

//
// Interface: TLAttributeNameDataValue
//

@interface TLAttributeNameDataValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name data:(nonnull NSData *)data;

@end

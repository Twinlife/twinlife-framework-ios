/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLAttributeNameValue.h"
#import "TLImageService.h"

//
// Implementation: TLAttributeNameValue
//

@implementation TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name value:(nonnull NSObject *)value {
    
    self = [super init];
    
    _name = name;
    _value = value;
    return self;
}

+ (nullable TLAttributeNameValue *)getAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list {
    
    if (list) {
        for (TLAttributeNameValue *attribute in list) {
            if ([name isEqualToString:attribute.name]) {
                return attribute;
            }
        }
    }
    return nil;
}
+ (nullable NSString *)getStringAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list {
    
    TLAttributeNameValue *attribute = [TLAttributeNameValue getAttributeWithName:name list:list];
    if (attribute && [attribute.value isKindOfClass:[NSString class]]) {
        return (NSString *)attribute.value;
    }
    return nil;
}

+ (nullable NSUUID *)getUUIDAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list {

    TLAttributeNameValue *attribute = [TLAttributeNameValue getAttributeWithName:name list:list];
    if (attribute) {
        if ([attribute.value isKindOfClass:[NSUUID class]]) {
            return (NSUUID *)attribute.value;
        }
        if ([attribute.value isKindOfClass:[NSString class]]) {
            return [[NSUUID alloc] initWithUUIDString:(NSString *)attribute.value];
        }
    }
    return nil;
}

+ (int64_t)getLongAttributeWithName:(nonnull NSString *)name list:(nullable NSArray<TLAttributeNameValue *> *)list defaultValue:(int64_t)defaultValue {

    TLAttributeNameValue *attribute = [TLAttributeNameValue getAttributeWithName:name list:list];
    if (attribute && [attribute.value isKindOfClass:[NSNumber class]]) {
        return ((NSNumber *)attribute.value).longLongValue;
    }
    return defaultValue;
}

+ (nullable TLAttributeNameValue *)removeAttributeWithName:(nonnull NSString *)name list:(nonnull NSMutableArray<TLAttributeNameValue *> *)list {
    
    for (int i = 0; i < list.count; i++) {
        TLAttributeNameValue *attribute = [list objectAtIndex:i];
        if ([name isEqual:attribute.name]) {
            [list removeObjectAtIndex:i];
            return attribute;
        }
    }
    return nil;
}

@end

//
// Implementation: TLAttributeNameBooleanValue
//

@implementation TLAttributeNameBooleanValue

- (nonnull instancetype)initWithName:(nullable NSString *)name boolValue:(BOOL)boolValue {
    
    return [super initWithName:name value:[NSNumber numberWithBool:boolValue]];
}

@end


//
// Implementation: TLAttributeNameLongValue
//

@implementation TLAttributeNameLongValue

- (nonnull instancetype)initWithName:(nullable NSString *)name longValue:(int64_t)longValue {
    
    return [super initWithName:name value:[NSNumber numberWithLongLong:longValue]];
}

@end

//
// Implementation: TLAttributeNameStringValue
//

@implementation TLAttributeNameStringValue

- (nonnull instancetype)initWithName:(nullable NSString *)name stringValue:(nonnull NSString *)stringValue {
    
    return [super initWithName:name value:stringValue];
}

@end

//
// Implementation: TLAttributeNameUUIDValue
//

@implementation TLAttributeNameUUIDValue

- (nonnull instancetype)initWithName:(nullable NSString *)name uuidValue:(nonnull NSUUID *)uuidValue {
    
    return [super initWithName:name value:uuidValue];
}

@end

//
// Implementation: TLAttributeNameImageIdValue
//

@implementation TLAttributeNameImageIdValue :TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name imageId:(nonnull TLExportedImageId *)imageId {
    
    return [super initWithName:name value:imageId];
}

@end

//
// Implementation: TLAttributeNameVoidValue
//

@implementation TLAttributeNameVoidValue

- (nonnull instancetype)initWithName:(nullable NSString *)name {
    
    return [super initWithName:name value:[NSObject alloc]];
}

@end

//
// Implementation: TLAttributeNameListValue
//

@implementation TLAttributeNameListValue

- (nonnull instancetype)initWithName:(nullable NSString *)name listValue:(nonnull NSArray<TLAttributeNameValue *> *)listValue {
    
    return [super initWithName:name value:listValue];
}

@end

//
// Implementation: TLAttributeNameDataValue
//

@implementation TLAttributeNameDataValue : TLAttributeNameValue

- (nonnull instancetype)initWithName:(nullable NSString *)name data:(nonnull NSData *)data {
    
    return [super initWithName:name value:data];
}

@end

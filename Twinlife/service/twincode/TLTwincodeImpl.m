/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLBaseService.h"
#import "TLTwincodeImpl.h"
#import "TLAttributeNameValue.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLTwincodePendingRequest
//

@implementation TLTwincodePendingRequest

@end

//
// TLTwincode
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincode"

@implementation TLTwincode

static NSUUID* NOT_DEFINED_UUID;

+ (void) initialize {
    
    NOT_DEFINED_UUID = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}

+ (nonnull NSUUID *)NOT_DEFINED {
    
    return NOT_DEFINED_UUID;
}

- (nonnull instancetype)initWithUUID:(nonnull NSUUID *)twincodeId modificationDate:(int64_t)modificationDate attributes:(nullable NSMutableArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@ initWithUUID: %@ modificationDate: %lld attributes: %@", LOG_TAG, twincodeId, modificationDate, attributes);
    
    self = [super init];
    if (self) {
        _uuid = twincodeId;
        _modificationDate = modificationDate;
        _attributes = attributes;
    }
    return self;
}

- (nonnull NSUUID *)objectId {
    DDLogVerbose(@"%@ objectId: %@", LOG_TAG, self.uuid);

    return self.uuid;
}

- (nullable id)getAttributeWithName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ getAttributeWithName: %@", LOG_TAG, name);
    
    for (TLAttributeNameValue* attribute in self.attributes) {
        if ([attribute.name isEqualToString:name]) {
            return attribute.value;
        }
    }
    
    return nil;
}

- (BOOL)hasAttributeWithName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ hasAttributeWithName: %@", LOG_TAG, name);
    
    for (TLAttributeNameValue* attribute in self.attributes) {
        if ([attribute.name isEqualToString:name]) {
            return true;
        }
    }
    
    return false;
}

- (TLTwincodeFacet)getFacet {
    
    return NOT_USED;
}

- (BOOL)isTwincodeFactory {
    
    return false;
}

- (BOOL)isTwincodeInbound {
    
    return false;
}

- (BOOL)isTwincodeOutbound {
    
    return false;
}

- (BOOL)isTwincodeSwitch {
    
    return false;
}

- (BOOL)isEqual:(nullable id)object {
    
    if (self == object) {
        return true;
    }
    if (!object || ![object isKindOfClass:[TLTwincode class]]) {
        return false;
    }
    TLTwincode* twincode = (TLTwincode *)object;
    return [twincode.uuid isEqual:self.uuid] && twincode.modificationDate == self.modificationDate;
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    result = 31 * result + self.uuid.hash;
    return result;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLTwincode\n"];
    [string appendFormat:@" id: %@\n", [self.uuid UUIDString]];
    [string appendFormat:@" modificationDate: %lld\n", self.modificationDate];
    [string appendString:@" attributes:\n"];
    for (TLAttributeNameValue *attribute in self.attributes) {
        [string appendFormat:@" %@: %@\n", attribute.name, attribute.value];
    }
    return string;
}

@end

//
// TLTwincodeImpl
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeImpl"

@implementation TLTwincodeImpl

- (nonnull instancetype)initWithUUID:(nonnull NSUUID *)uuid modificationDate:(int64_t)modificationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@ initWithUUID: %@ modificationDate: %lld attributes: %@", LOG_TAG, uuid, modificationDate, attributes);
    
    self = [super init];
    
    _uuid = uuid;
    _modificationDate = modificationDate;
    _attributes = attributes;
    return self;
}

- (nullable id)getAttributeWithName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ getAttributeWithName: %@", LOG_TAG, name);
    
    for (TLAttributeNameValue* attribute in self.attributes) {
        if ([attribute.name isEqualToString:name]) {
            return attribute;
        }
    }
    
    return nil;
}

- (BOOL)hasAttributeWithName:(nonnull NSString *)name {
    DDLogVerbose(@"%@ hasAttributeWithName: %@", LOG_TAG, name);
    
    for (TLAttributeNameValue* attribute in self.attributes) {
        if ([attribute.name isEqualToString:name]) {
            return true;
        }
    }
    
    return false;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLTwincodeImpl\n"];
    [string appendFormat:@" id: %@\n", [self.uuid UUIDString]];
    [string appendFormat:@" modificationDate: %lld\n", self.modificationDate];
    [string appendString:@" attributes:\n"];
    for (TLAttributeNameValue* attribute in self.attributes) {
        [string appendFormat:@" %@: %@\n", attribute.name, attribute.value];
    }
    return string;
}

@end

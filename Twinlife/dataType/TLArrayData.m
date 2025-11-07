/*
 *  Copyright (c) 2014-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <KissXML.h>

#import "TLArrayData.h"
#import "TLDataImpl.h"
#import "TLStringData.h"
#import "TLRecordData.h"
#import "TLCDATAData.h"
#import "TLLongData.h"
#import "TLVoidData.h"
#import "TLBooleanData.h"
#import "TLUUIDData.h"
#import "TLAttributeNameValue.h"

//
// Interface(): TLArrayData
//

@interface TLArrayData()

@property NSMutableArray *array;

@end

//
// Implementation: TLArrayData
//

@implementation TLArrayData

- (instancetype)init {
    
    self = [super init];
    
    _array = [[NSMutableArray alloc] init];
    return self;
}


#pragma mark - Public methods

- (instancetype)initWithName:(NSString *)name {
    
    self = [super initWithName:name value:nil];
    
    _array = [[NSMutableArray alloc] init];
    return self;
}

- (NSArray *)values {
    
    return [self.array copy];
}

- (void)setValues:(NSArray *)array {
    
    self.array = [array mutableCopy];
}

- (void)addData:(TLData *)data {
    
    [self.array addObject:data];
}

- (void)addAttributes:(NSArray *)attributes {
    
    if (!attributes) {
        return;
    }
    
    for (TLAttributeNameValue * attribute in attributes) {
        TLData* data;
        if ([attribute isKindOfClass:[TLAttributeNameLongValue class]]) {
            data = [[TLLongData alloc] initWithName:attribute.name value:[(NSNumber *)attribute.value longValue]];
        } else  if ([attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
            data = [[TLBooleanData alloc] initWithName:attribute.name value:[(NSNumber *)attribute.value boolValue]];
        } else  if ([attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            data = [[TLStringData alloc] initWithName:attribute.name value:(NSString *)attribute.value];
        } else  if ([attribute isKindOfClass:[TLAttributeNameVoidValue class]]) {
            data = [[TLVoidData alloc] initWithName:attribute.name];
        } else  if ([attribute isKindOfClass:[TLAttributeNameUUIDValue class]]) {
            data = [[TLUUIDData alloc] initWithName:attribute.name value:(NSUUID *)attribute.value];
        } else  if ([attribute isKindOfClass:[TLAttributeNameListValue class]]) {
            data = [[TLArrayData alloc] initWithName:attribute.name];
            [(TLArrayData *)data addAttributes:(NSArray *)attribute.value];
        }
        if (!data) {
            continue;
        }
        [self.array addObject:data];
    }
}

- (NSArray *)attributes {
    
    NSMutableArray *attributes = [[NSMutableArray alloc] init];
    for (TLData *data in self.array) {
        if (data.isPrimitiveData) {
            TLPrimitiveData *primitiveData = (TLPrimitiveData *)data;
            if ([primitiveData.type isEqualToString:@"boolean"]) {
                [attributes addObject:[[TLAttributeNameBooleanValue alloc] initWithName:primitiveData.name boolValue:primitiveData.booleanValue]];
            } else if ([primitiveData.type isEqualToString:@"long"]) {
                [attributes addObject:[[TLAttributeNameLongValue alloc] initWithName:primitiveData.name longValue:primitiveData.longValue]];
            } else if ([primitiveData.type isEqualToString:@"string"]) {
                [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:primitiveData.name stringValue:primitiveData.stringValue]];
            } else if ([primitiveData.type isEqualToString:@"uuid"]) {
                [attributes addObject:[[TLAttributeNameUUIDValue alloc] initWithName:primitiveData.name uuidValue:primitiveData.uuidValue]];
            }
        } else if (data.isVoidData) {
            [attributes addObject:[[TLAttributeNameVoidValue alloc] initWithName:data.name]];
        } else if (data.isArrayData) {
            [attributes addObject:[[TLAttributeNameListValue alloc] initWithName:data.name listValue:[(TLArrayData *)data attributes]]];
        }
    }
    return attributes;
}

- (NSArray *)stringValues {
    
    NSMutableArray *lArray = [[NSMutableArray alloc] init];
    for (TLData* element in self.array) {
        [lArray addObject: [element.toXml XMLString]];
    }
    return [lArray copy];
}

- (NSInteger)count {
    
    return self.array.count;
}

#pragma mark - Override methods

- (NSString *)type {
    
    return @"array";
}

- (BOOL)isArrayData {
    
    return true;
}

- (DDXMLElement *)toXml {
    
    DDXMLElement*xml = [[DDXMLElement alloc] initWithName:@"field"];
    [xml addAttributeWithName:@"type" stringValue:self.type];
    if (self.name) {
        [xml addAttributeWithName:@"name" stringValue:self.name];
    }
    if (self.array.count) {
        for (TLData* element in self.array) {
            [xml addChild:element.toXml];
        }
    }
    return xml;
}

- (void)parse:(DDXMLElement *)xml {
    
    if (!xml || ![xml.name isEqualToString: @"field"]) {
        return;
    }
    
    self.name = [[xml attributeForName:@"name"] stringValue];
    self.array = [[NSMutableArray alloc] init];
    for (DDXMLElement *child in xml.children) {
        TLData* newData = [self decideType:child];
        if (!newData) {
            NSLog(@"this xml file can't be parsed");
            continue;
        }
        [self.array addObject:newData];
        xml = (DDXMLElement *)xml.nextSibling;
    }
}

#pragma mark - Private methods

- (TLData *)decideType:(DDXMLElement *)xml {
    
    NSString* type = [[xml attributeForName:@"type"] stringValue];
    TLData *data;
    if ([type isEqualToString:@"array"]) {
        data = [[TLArrayData alloc] init];
    } else if ([type isEqualToString:@"record"]) {
        data = [[TLRecordData alloc] init];
    } else if ([type isEqualToString:@"boolean"]) {
        data = [[TLBooleanData alloc] init];
    } else if ([type isEqualToString:@"long"]) {
        data = [[TLLongData alloc] init];
    } else if ([type isEqualToString:@"string"]) {
        data = [[TLStringData alloc] init];
    } else if ([type isEqualToString:@"uuid"]) {
        data = [[TLUUIDData alloc] init];
    } else if ([type isEqualToString:@"void"]) {
        data = [[TLVoidData alloc] init];
    } else if ([type isEqualToString:@"cdata"]) {
        data = [[TLCDATAData alloc] init];
    }
    if (data) {
        [data parse:xml];
    }
    
    return data;
}

@end

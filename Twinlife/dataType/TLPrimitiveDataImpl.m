/*
 *  Copyright (c) 2014-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <KissXML.h>

#import "TLDataImpl.h"
#import "TLPrimitiveDataImpl.h"

//
// Implementation: TLPrimitiveData
//

@implementation TLPrimitiveData

- (instancetype)initWithName:(NSString *)name type:(NSString *)type value:(NSString *) value {
    
    self = [super initWithName:name value:value];
    if (self) {
        _type = type;
    }
    return self;
}

- (NSData *)bitmapValue {
    
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (BOOL)booleanValue {
    
    [self doesNotRecognizeSelector:_cmd];
    return false;
}

- (int64_t)longValue {
    
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

- (NSString *)stringValue {
    
    return self.value;
}

- (NSUUID *)uuidValue {
    
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

//
#pragma mark - override methods
//

- (BOOL)isPrimitiveData {
    
    return true;
}

- (void)parse:(DDXMLElement *)xml {
    
    if (!xml || ![xml.name isEqualToString: @"field"]) {
        return;
    }
    self.name = [[xml attributeForName:@"name"] stringValue];
    self.type = [[xml attributeForName:@"type"] stringValue];
    xml = (DDXMLElement *)xml.nextNode;
    if (!xml || ![xml.name isEqualToString: @"value"]) {
        return;
    }
    self.value = [xml stringValue];
}

- (DDXMLElement *)toXml {
    
    DDXMLElement *xml = [[DDXMLElement alloc] initWithName:@"field"];
    if (self.type) {
        [xml addAttributeWithName:@"type" stringValue:self.type];
    }
    if (self.name) {
        [xml addAttributeWithName:@"name" stringValue:self.name];
    }
    NSXMLElement *value = [NSXMLElement elementWithName:@"value" stringValue:[self stringValue]];
    [xml addChild:value];
    
    return xml;
}

@end

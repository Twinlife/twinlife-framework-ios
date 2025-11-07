/*
 *  Copyright (c) 2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <KissXML.h>

#import "TLCDATAData.h"
#import "TLDataImpl.h"

//
// Implementation: TLCDATAData
//

@implementation TLCDATAData

//
#pragma mark - Public methods
//

- (instancetype)initWithName:(NSString *)name value:(NSString *)value {
    
    self = [super initWithName:name value: value];
    return self;
}

- (NSString *)stringValue {
    if (self.value == nil || [self.value isEqualToString:@""]) {
        return nil;
    }
    return self.value;
}

//
#pragma mark - Override methods
//

- (NSString *)type {
    
    return @"cdata";
}

- (BOOL)isCDATAData {
    
    return true;
}

- (DDXMLElement *)toXml {
    
    NSString* value = self.value;
    if (!value) {
        value = @"";
    }
    DDXMLElement* xml = [self createCDataElementWithName:@"field" stringValue:value];
    [xml addAttributeWithName:@"type" stringValue:@"cdata"];
    if (self.name) {
        [xml addAttributeWithName:@"name" stringValue:self.name];
    }
    return xml;
}

- (void)parse:(DDXMLElement *)xml {
    
    if (!xml || ![xml.name isEqualToString: @"field"]) {
        return;
    }
    self.name = [[xml attributeForName:@"name"] stringValue];
    xml = (DDXMLElement *)xml.nextNode;
    self.value = [xml stringValue];
}

//
#pragma mark - private methods
//

- (DDXMLElement *)createCDataElementWithName:(NSString *)name stringValue:(NSString *)string {
    
    NSString* nodeString = [NSString stringWithFormat:@"<%@><![CDATA[%@]]></%@>", name, string, name];
    DDXMLElement* cdataNode = [[DDXMLDocument alloc] initWithXMLString:nodeString
                                                               options:DDXMLDocumentXMLKind
                                                                 error:nil].rootElement;
    return [cdataNode copy];
}

@end

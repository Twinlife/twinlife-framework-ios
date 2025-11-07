/*
 *  Copyright (c) 2014-2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <KissXML.h>
#import "TLVoidData.h"

#import "TLDataImpl.h"
#import "TLPrimitiveDataImpl.h"

@implementation TLVoidData

//
#pragma mark - Public methods
//

- (instancetype)initWithName:(NSString *)name {
    
    self = [super initWithName:name value:nil];
    return self;
}

#pragma mark - Override methods

- (NSString *)type {
    
    return @"void";
}

- (BOOL)isVoidData {
    
    return true;
}

- (DDXMLElement *)toXml {
    
    DDXMLElement*xml = [[DDXMLElement alloc] initWithName:@"field"];
    [xml addAttributeWithName:@"type" stringValue:@"void"];
    
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
}

@end

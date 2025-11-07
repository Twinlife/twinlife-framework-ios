/*
 *  Copyright (c) 2014-2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <KissXML.h>

#import "TLDataImpl.h"
#import "TLRecordData.h"
#import "TLArrayData.h"
#import "TLStringData.h"
#import "TLCDATAData.h"
#import "TLLongData.h"
#import "TLVoidData.h"
#import "TLBooleanData.h"

//
// Interface(): TLRecordData
//

@interface TLRecordData()

@property NSMutableDictionary *dictionary;

@end

//
// Implementation: TLRecordData
//

@implementation TLRecordData

- (instancetype)init {
    
    self = [super init];
    if (self) {
        _dictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Public methods

- (instancetype)initWithName:(NSString *)name {
    
    self = [super initWithName:name value:nil];
    if (self) {
        _dictionary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(TLData *)getDataWithName:(NSString *)name {
    
    if (!name) {
        @throw NSGenericException;
        return nil;
    }
    return self.dictionary[name];
}

- (void)addData:(TLData *)data {
    // TBD
    if (!data.name) {
        @throw NSGenericException;
        return;
    }
    [self.dictionary setValue:data forKey:data.name];
}

- (NSInteger)count {
    return self.dictionary.count;
}

#pragma mark - Override methods

- (NSString *)type {
    
    return @"record";
}


- (BOOL)isRecordData {
    
    return true;
}

- (DDXMLElement *)toXml {
    
    DDXMLElement*xml = [[DDXMLElement alloc] initWithName:@"field"];
    [xml addAttributeWithName:@"type" stringValue:self.type];
    if (self.name) {
        [xml addAttributeWithName:@"name" stringValue:self.name];
    }
    if (self.dictionary.count) {
        [self.dictionary enumerateKeysAndObjectsUsingBlock:^(id key, TLData* obj, BOOL *stop) {
            [xml addChild:obj.toXml];
        }];
    }
    return xml;
}

- (void)parse:(DDXMLElement *)xml {
    
    if (!xml || ![xml.name isEqualToString: @"field"]) {
        return;
    }
    self.name = [[xml attributeForName:@"name"] stringValue];
    self.dictionary = [[NSMutableDictionary alloc] init];
    for (DDXMLElement *child in xml.children) {
        TLData* data =[self decideType:child];
        if (!data) {
            NSLog(@"this xml file can't be parsed");
            continue;
        }
        [self.dictionary setValue:data forKey:data.name];
        xml = (DDXMLElement *)xml.nextSibling;
    }
}

#pragma mark - Private methods

- (TLData *)decideType:(DDXMLElement *)xml {
    
    NSString* type = [[xml attributeForName:@"type"] stringValue];
    TLData *data;
    if ([type isEqualToString:@"array"]) {
        data = [[TLArrayData alloc] init];
    } else if ([type isEqualToString:@"boolean"]) {
        data = [[TLBooleanData alloc] init];
    } else if ([type isEqualToString:@"long"]) {
        data = [[TLLongData alloc] init];
    } else if ([type isEqualToString:@"string"]) {
        data = [[TLStringData alloc] init];
    } else if ([type isEqualToString:@"void"]) {
        data = [[TLVoidData alloc] init];
    } else if ([type isEqualToString:@"cdata"]) {
        data = [[TLCDATAData alloc] init];
    } else if ([type isEqualToString:@"record"]) {
        data = [[TLRecordData alloc] init];
    }
    if (data) {
        [data parse:xml];
    }
    return data;
}

@end

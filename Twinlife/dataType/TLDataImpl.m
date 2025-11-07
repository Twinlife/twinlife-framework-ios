/*
 *  Copyright (c) 2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLDataImpl.h"

@implementation TLData

- (instancetype)initWithName:(NSString *)name value:(NSString *)value {
    
    self = [super init];
    if (self) {
        _name = name;
        _value = value;
    }
    return self;
}

- (BOOL)isArrayData {
    
    return false;
}

- (BOOL)isPrimitiveData {
    
    return false;
}

- (BOOL)isRecordData {
    
    return false;
}

- (BOOL)isVoidData {
    
    return false;
}

- (BOOL)isCDATAData {
    
    return false;
}

#pragma mark - Protect methods

- (NSString *)type {
    
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}


- (DDXMLElement *)toXml {
    
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void)parse:(DDXMLElement *)xml {
    
    [self doesNotRecognizeSelector:_cmd];
}

@end

/*
 *  Copyright (c) 2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 */

#import "TLBooleanData.h"
#import "TLDataImpl.h"
#import "TLPrimitiveDataImpl.h"

//
// Implementation: TLBooleanData
//

@implementation TLBooleanData

//
#pragma mark - public methods
//

- (instancetype)initWithName:(NSString *)name value:(BOOL)value {
    
    self = [super initWithName:name type: @"boolean" value:value ? @"true" : @"false"];
    return self;
}

//
#pragma mark - Override methods
//

- (BOOL)booleanValue {
    
    return [self.value boolValue];
}

@end

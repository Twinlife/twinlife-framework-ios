/*
 *  Copyright (c) 2014-2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLStringData.h"
#import "TLDataImpl.h"
#import "TLPrimitiveDataImpl.h"

//
// Implementation: TLStringData
//

@implementation TLStringData

//
#pragma mark - Public methods
//

- (instancetype)initWithName:(NSString *)name value:(NSString *)value {
    
    self = [super initWithName:name type:@"string" value: value];
    return self;
}

//
#pragma mark - Override methods
//

- (NSString *)stringValue {
    
    if (self.value == nil || [self.value isEqualToString:@""]) {
        self.value = nil;
    }
    return self.value;
}

@end

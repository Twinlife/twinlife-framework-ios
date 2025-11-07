/*
 *  Copyright (c) 2014-2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLLongData.h"
#import "TLDataImpl.h"
#import "TLPrimitiveDataImpl.h"

//
// Implementation: TLLongData
//

@implementation TLLongData

//
#pragma mark - public methods
//

- (instancetype)initWithName:(NSString *)name value:(int64_t)value {
    
    self = [super initWithName:name type:@"long" value:[NSString stringWithFormat:@"%lld", value]];
    return self;
}

//
#pragma mark - Override methods
//

- (int64_t)longValue {
    
    if (self.value == nil || [self.value isEqualToString:@""]) {
        return 0;
    }
    return [self.value longLongValue];
}

@end

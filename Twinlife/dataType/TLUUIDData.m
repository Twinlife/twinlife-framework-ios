/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUUIDData.h"
#import "TLDataImpl.h"
#import "TLPrimitiveDataImpl.h"

//
// Implementation: TLUUIDData
//

@implementation TLUUIDData

//
#pragma mark - Public methods
//

- (nonnull instancetype)initWithName:(nonnull NSString *)name value:(nonnull NSUUID *)value {
    
    self = [super initWithName:name type:@"uuid" value:value.UUIDString];
    return self;
}

//
#pragma mark - Override methods
//

- (NSUUID *)uuidValue {
    
    if (self.value == nil || [self.value isEqualToString:@""]) {
        self.value = nil;
    }
    return [[NSUUID alloc] initWithUUIDString:self.value];
}

@end

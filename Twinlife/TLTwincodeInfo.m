/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLTwincodeInfo.h"

//
// Implementation: TLTwincodeInfo
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeInfo"

@implementation TLTwincodeInfo


- (nonnull instancetype)initWithTwincodeFactoryId:(nonnull NSUUID *)twincodeFactoryId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId {
    self = [super init];
    
    if (self) {
        _twincodeFactoryId = twincodeFactoryId;
        _twincodeOutboundId = twincodeOutboundId;
        _twincodeInboundId = twincodeInboundId;
    }
    
    return self;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:128];
    [string appendFormat:@"TLTwincodeInfo: twincodeFactoryId=%@ twincodeOutboundId=%@ twincodeInboundId=%@", self.twincodeFactoryId, self.twincodeOutboundId, self.twincodeInboundId];
    return string;
}

@end

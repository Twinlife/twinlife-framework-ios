/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLFilter.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
// static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLFilter
//

#undef LOG_TAG
#define LOG_TAG @"TLFilter"

@implementation TLFilter

- (BOOL)acceptWithObject:(nonnull id<TLDatabaseObject>)object {
    
    return YES;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:128];
    [string appendFormat:@"TLFilter: %@", self.owner];
    return string;
}

@end

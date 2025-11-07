/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLVersion.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLVersion
//

#undef LOG_TAG
#define LOG_TAG @"TLVersion"

@implementation TLVersion

- (nonnull instancetype)initWithMajor:(int)major minor:(int)minor patch:(int)patch {
    DDLogVerbose(@"%@ initWithMajor: %d minor: %d patch: %d", LOG_TAG, major, minor, patch);

    self = [super init];
    if (self) {
        _major = major;
        _minor = minor;
        _patch = patch;
    }
    return self;
}

/// Create a version object splitting the string into major, minor and patch components.
- (nonnull instancetype)initWithVersion:(nonnull NSString *)version {
    DDLogVerbose(@"%@ initWithVersion: %@", LOG_TAG, version);

    self = [super init];
    if (self) {
        NSArray<NSString *> *lines = [version componentsSeparatedByString:@"."];
        int count = (int)lines.count;
        if (count > 0) {
            _major = (int)[lines[0] integerValue];
            if (count > 1) {
                _minor = (int)[lines[1] integerValue];
                if (count > 2) {
                    _patch = (int)[lines[2] integerValue];
                } else {
                    _patch = 0;
                }
            } else {
                _minor = 0;
                _patch = 0;
            }
        } else {
            _major = 0;
            _minor = 0;
            _patch = 0;
        }
    }
    return self;
}

/// Compare two versions.
- (NSComparisonResult)compareWithOperationQueue:(nonnull TLVersion *)version {
    
    int result = self.major - version.major;
    if (result == 0) {
        result = self.minor - version.minor;
        if (result == 0) {
            result = self.patch - version.patch;
            if (result == 0) {
                return NSOrderedSame;
            }
        }
    }

    return result < 0 ? NSOrderedDescending : NSOrderedAscending;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:128];
    [string appendFormat:@"TLVersion: %d.%d.%d", self.major, self.minor, self.patch];
    return string;
}

@end

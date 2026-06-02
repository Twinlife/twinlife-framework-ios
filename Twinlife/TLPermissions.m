/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLPermissions.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
// static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLPermissions
//

#undef LOG_TAG
#define LOG_TAG @"TLPermissions"

@implementation TLPermissions

+ (BOOL)hasPermission:(TLPermissionType)kind permissions:(int64_t)permissions {
    
    if (kind < 0) {
        return NO;
    } else {
        return (permissions & (1L << kind)) != 0;
    }
}

+ (int64_t)removePermission:(TLPermissionType)kind permissions:(int64_t)permissions {
    
    if (kind < 0) {
        return permissions;
    } else {
        return (permissions & (~(1L << kind)));
    }
}

@end

/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupInfo.h"

//
// Implementation: TLBackupInfo
//

#undef LOG_TAG
#define LOG_TAG @"TLBackupInfo"

@implementation TLBackupInfo

- (instancetype)initWithUUID:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate {
    
    self = [super init];
    
    if (self) {
        _uuid = uuid;
        _creationDate = creationDate;
    }
    
    return self;
}


@end

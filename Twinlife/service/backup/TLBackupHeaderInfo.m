/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHeaderInfo.h"

@implementation TLBackupHeaderInfo


- (nonnull instancetype)initWithDate:(long)date backupId:(nonnull NSUUID *)backupId salt:(nonnull NSData *)salt applicationName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion {
    
    self = [super init];
    
    if (self) {
        _date = date;
        _backupId = backupId;
        _salt = salt;
        _applicationName = applicationName;
        _applicationVersion = applicationVersion;
    }
    
    return self;
}

@end

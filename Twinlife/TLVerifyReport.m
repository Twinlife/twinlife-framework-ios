/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLVerifyReport.h"
#import "TLRestoreContent.h"
#import "TLTwincodeInfo.h"

//
// Implementation: TLVerifyReport
//

@implementation TLVerifyReport

- (nonnull instancetype)initWithDeleted:(nonnull NSDictionary<NSUUID *,NSArray<NSUUID *> *> *)deleted added:(nonnull NSDictionary<NSUUID *,NSArray<NSUUID *> *> *)added modified:(nonnull NSDictionary<NSUUID *,NSArray<NSUUID *> *> *)modified upToDate:(nonnull NSDictionary<NSUUID *,NSArray<NSUUID *> *> *)upToDate {
    self = [super init];
    
    if (self) {
        _deleted = deleted;
        _added = added;
        _modified = modified;
        _upToDate = upToDate;
    }
    
    return self;
}



- (nonnull TLRestoreContentStats *)getStatsWithSchemaId:(nonnull NSUUID *)schemaId {
    
    NSArray<NSUUID *> *deleted = self.deleted[schemaId];
    NSArray<NSUUID *> *added = self.added[schemaId];
    NSArray<NSUUID *> *modified = self.modified[schemaId];
    NSArray<NSUUID *> *upToDate = self.upToDate[schemaId];
    
    int d = deleted != nil ? (int)deleted.count : 0;
    int a = added != nil ? (int)added.count : 0;
    int m = modified != nil ? (int)modified.count : 0;
    int u = upToDate != nil ? (int)upToDate.count : 0;
    
    return [[TLRestoreContentStats alloc] initWithAdded:a deleted:d modified:m upToDate:u];
}

- (nonnull NSArray<NSUUID *> *)getAddedTwincodeIds {
    
    NSMutableArray<NSUUID *> *allIds = [NSMutableArray array];

    for (NSArray<NSUUID *> *ids in self.added.allValues) {
        [allIds addObjectsFromArray:ids];
    }

    return [allIds copy];
}

- (nonnull NSArray<NSUUID *> *)getDeletedTwincodeIds {
    
    NSMutableArray<NSUUID *> *allIds = [NSMutableArray array];

    for (NSArray<NSUUID *> *ids in self.deleted.allValues) {
        [allIds addObjectsFromArray:ids];
    }

    return [allIds copy];
}

- (nonnull NSArray<NSUUID *> *)getModifiedTwincodeIds {
    
    NSMutableArray<NSUUID *> *allIds = [NSMutableArray array];

    for (NSArray<NSUUID *> *ids in self.modified.allValues) {
        [allIds addObjectsFromArray:ids];
    }

    return [allIds copy];
}

- (nonnull NSArray<NSUUID *> *)getUpToDateTwincodeIds {
    
    NSMutableArray<NSUUID *> *allIds = [NSMutableArray array];

    for (NSArray<NSUUID *> *ids in self.upToDate.allValues) {
        [allIds addObjectsFromArray:ids];
    }

    return [allIds copy];
}


@end


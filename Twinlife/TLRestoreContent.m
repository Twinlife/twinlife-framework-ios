/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLRestoreContent.h"
#import "TLTwincodeInfo.h"

//
// Implementation: TLRestoreContentStats
//

@implementation TLRestoreContentStats

- (nonnull instancetype)initWithAdded:(int)added deleted:(int)deleted modified:(int)modified upToDate:(int)upToDate {
    self = [super init];
    
    if (self) {
        _added = added;
        _deleted = deleted;
        _modified = modified;
        _upToDate = upToDate;
    }
    
    return self;
}

- (BOOL)isStatsUpToDate {
    return self.added == 0 && self.deleted == 0 && self.modified == 0;
}

@end

//
// Implementation: TLRestoreContent
//

@implementation TLRestoreContent

- (nonnull instancetype)initWithAdded:(nonnull NSDictionary<NSUUID *,NSArray *> *)added deleted:(nonnull NSDictionary<NSUUID *,NSArray<NSUUID *> *> *)deleted upToDate:(nonnull NSDictionary<NSUUID *,NSArray<NSUUID *> *> *)upToDate {
    self = [super init];
    
    if (self) {
        _added = added;
        _deleted = deleted;
        _upToDate = upToDate;
    }
    
    return self;
}

- (nonnull NSArray<TLTwincodeInfo *> *)getAddedTwincodeInfos {
    
    NSMutableArray<TLTwincodeInfo *> *allInfos = [NSMutableArray array];

    for (NSArray<TLTwincodeInfo *> *infos in self.added.allValues) {
        [allInfos addObjectsFromArray:infos];
    }

    return [allInfos copy];
}


- (nonnull NSArray<NSUUID *> *)getUpToDateTwincodeIds {
   
    NSMutableArray<TLTwincodeInfo *> *allIds = [NSMutableArray array];

    for (NSArray<TLTwincodeInfo *> *ids in self.upToDate.allValues) {
        [allIds addObjectsFromArray:ids];
    }

    return [allIds copy];
}

- (nonnull NSArray<NSUUID *> *)getDeletedTwincodeIds {
    
    NSMutableArray<TLTwincodeInfo *> *allIds = [NSMutableArray array];

    for (NSArray<TLTwincodeInfo *> *ids in self.deleted.allValues) {
        [allIds addObjectsFromArray:ids];
    }

    return [allIds copy];}


- (nonnull TLRestoreContentStats *)getStatsWithSchemaId:(nonnull NSUUID *)schemaId {
    NSArray<TLTwincodeInfo *> *added = self.added[schemaId];
    NSArray<NSUUID *> *deleted = self.deleted[schemaId];
    NSArray<NSUUID *> *upToDate = self.upToDate[schemaId];
    
    int a = added != nil ? (int)added.count : 0;
    int d = deleted != nil ? (int)deleted.count : 0;
    int u = upToDate != nil ? (int)upToDate.count : 0;
    
    return [[TLRestoreContentStats alloc] initWithAdded:a deleted:d modified:0 upToDate:u];
}

@end


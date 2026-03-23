/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

@class TLTwincodeInfo;
@class TLRestoreContentStats;

//
// Interface: TLVerifyReport
//

@interface TLVerifyReport : NSObject

@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<NSUUID *> *> *deleted;
@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<NSUUID *> *> *added;
@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<NSUUID *> *> *modified;
@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<NSUUID *> *> *upToDate;

- (nonnull instancetype)initWithDeleted:(nonnull NSDictionary<NSUUID *, NSArray<NSUUID *> *> *)deleted added:(nonnull NSDictionary<NSUUID *, NSArray<NSUUID *> *> *)added modified:(nonnull NSDictionary<NSUUID *, NSArray<NSUUID *> *> *)modified upToDate:(nonnull NSDictionary<NSUUID *, NSArray<NSUUID *> *> *)upToDate;

- (nonnull NSArray<NSUUID *> *)getDeletedTwincodeIds;

- (nonnull NSArray<NSUUID *> *)getAddedTwincodeIds;

- (nonnull NSArray<NSUUID *> *)getModifiedTwincodeIds;

- (nonnull NSArray<NSUUID *> *)getUpToDateTwincodeIds;

- (nonnull TLRestoreContentStats *)getStatsWithSchemaId:(nonnull NSUUID *)schemaId;
@end

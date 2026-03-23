/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

@class TLTwincodeInfo;

//
// Interface: TLRestoreContentStats
//

@interface TLRestoreContentStats : NSObject

@property (readonly) int added;
@property (readonly) int deleted;
@property (readonly) int modified;
@property (readonly) int upToDate;

- (nonnull instancetype)initWithAdded:(int)added deleted:(int)deleted modified:(int)modified upToDate:(int)upToDate;

- (BOOL)isStatsUpToDate;
@end


//
// Interface: TLRestoreContent
//

@interface TLRestoreContent : NSObject

@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<TLTwincodeInfo *> *> *added;
@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<NSUUID *> *> *deleted;
@property (readonly, nonnull) NSDictionary<NSUUID *, NSArray<NSUUID *> *> *upToDate;

- (nonnull instancetype)initWithAdded:(nonnull NSDictionary<NSUUID *, NSArray<TLTwincodeInfo *> *> *)added deleted:(nonnull NSDictionary<NSUUID *, NSArray<NSUUID *> *> *)deleted upToDate:(nonnull NSDictionary<NSUUID *, NSArray<NSUUID *> *> *)upToDate;

- (nonnull NSArray<TLTwincodeInfo *> *)getAddedTwincodeInfos;

- (nonnull NSArray<NSUUID *> *)getDeletedTwincodeIds;

- (nonnull NSArray<NSUUID *> *)getUpToDateTwincodeIds;

- (nonnull TLRestoreContentStats *)getStatsWithSchemaId:(nonnull NSUUID *)schemaId;
@end

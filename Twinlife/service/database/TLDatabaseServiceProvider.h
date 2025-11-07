/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDatabaseService.h"

@class TLExportedImageId;

//
// Interface: TLDatabaseServiceProvider
//

@interface TLDatabaseServiceProvider : NSObject

@property (nonnull, readonly) TLBaseService *service;
@property (nonnull, readonly) TLDatabaseService *database;
@property (nonnull, readonly) NSString *createTable;
@property (readonly) TLDatabaseTable table;

- (nonnull instancetype)initWithService:(nonnull TLBaseService *)service database:(nonnull TLDatabaseService *)database sqlCreate:(nonnull NSString *)sqlCreate table:(TLDatabaseTable)table;

- (TLDatabaseTable)kind;

- (void)onCreateWithTransaction:(nonnull TLTransaction *)transaction;

- (void)onOpen;

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion;

- (int)onResumeWithDatabase:(nonnull FMDatabase *)database lastSuspendDate:(int64_t)lastSuspendDate;

- (void)inDatabase:(nonnull __attribute__((noescape)) void (^)(FMDatabase *_Nullable db))block;

- (void)inTransaction:(nonnull __attribute__((noescape)) void (^)(TLTransaction *_Nonnull transaction))block;

- (void)deleteWithObject:(nonnull id<TLDatabaseObject>)object;

- (void)deleteWithUUID:(nonnull NSUUID *)objectId;

- (nullable TLExportedImageId *)publicWithImageId:(nonnull TLImageId *)imageId;

@end


/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDatabaseService.h"

//
// Interface: TLDatabaseServiceProvider
//

@interface TLDatabaseCheck : NSObject

@property (readonly) int errorCount;
@property (readonly, nonnull) NSString *name;
@property (readonly, nullable) NSString *message;

- (nonnull instancetype)initWithException:(nonnull NSException *)exception name:(nonnull NSString *)name;

- (nonnull instancetype)initWithMessage:(nonnull NSString *)message name:(nonnull NSString *)name;

+ (nonnull NSMutableString *)checkConsistencyWithDatabase:(nonnull FMDatabase *)database;

@end

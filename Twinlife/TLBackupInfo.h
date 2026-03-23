/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface: TLBackupInfo
//

@interface TLBackupInfo : NSObject

@property (nonnull, readonly) NSUUID *uuid;
@property (readonly) int64_t creationDate;

- (nonnull instancetype)initWithUUID:(nonnull NSUUID *)uuid creationDate:(int64_t)creationDate;

@end

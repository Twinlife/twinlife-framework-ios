/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface: TLBackupHeaderInfo
//

@interface TLBackupHeaderInfo : NSObject

@property (readonly) long date;
@property (readonly, nonnull) NSUUID *backupId;
@property (readonly, nonnull) NSData *salt;
@property (readonly, nonnull) NSString *applicationName;
@property (readonly, nonnull) NSString *applicationVersion;

- (nonnull instancetype)initWithDate:(long)date backupId:(nonnull NSUUID *)backupId salt:(nonnull NSData *)salt applicationName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion;

@end

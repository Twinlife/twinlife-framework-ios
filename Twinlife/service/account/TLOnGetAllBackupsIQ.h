/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"
#import "TLBackupInfo.h"
//
// Interface: TLOnGetAllBackupsIQSerializer
//

@interface TLOnGetAllBackupsIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnGetAllBackupsIQ
//

@interface TLOnGetAllBackupsIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSArray<TLBackupInfo *> *backups;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq backups:(nonnull NSArray<TLBackupInfo *> *)backups;

@end

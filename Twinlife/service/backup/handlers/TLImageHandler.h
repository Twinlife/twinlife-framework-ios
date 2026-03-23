/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHandler.h"

@class TLImageInfo;
@class TLTwinlife;

#define TL_IMAGE_BACKUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"78aa0d24-95ec-4cd1-8cd9-6d962ed9f80c"]
#define TL_IMAGE_BACKUP_SCHEMA_VERSION 1

@interface TLImageHandler : TLBackupHandler<TLImageInfo *>

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife;

@end

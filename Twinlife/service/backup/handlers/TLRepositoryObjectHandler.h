/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBackupHandler.h"
#import "TLRepositoryService.h"


#define TL_REPOSITORY_OBJECT_BACKUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"a3764e50-4370-4486-8f7e-01927b2c4c71"]
#define TL_REPOSITORY_OBJECT_BACKUP_SCHEMA_VERSION 1

// Dummy TLRepositoryObject, used to identify absent repository objects.
@interface TLUnknownRepositoryObject : NSObject<TLRepositoryObject>

@property (nullable) id<TLRepositoryObject> owner;
@property (nullable) TLTwincodeInbound *twincodeInbound;
@property (nullable) TLTwincodeOutbound *twincodeOutbound;
@property (nullable) TLTwincodeOutbound *peerTwincodeOutbound;
@property int64_t modificationDate;

@end

@interface TLRepositoryObjectHandler : TLBackupHandler<id<TLRepositoryObject>>

- (nonnull instancetype)initWithRepositoryService:(nonnull TLRepositoryService *)repositoryService supportedSchemaIds:(nonnull NSArray<NSUUID *> *)supportedSchemaIds;

@end

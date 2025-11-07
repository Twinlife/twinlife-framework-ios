/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLImageServiceProvider.h"
#import "TLImageServiceImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

/**
 * Image table:
 * id INTEGER PRIMARY KEY: image id
 * copiedFrom INTEGER: image id of the original image
 * uuid TEXT NOT NULL: the public image ID
 * creationDate INTEGER NOT NULL: image creation date
 * flags INTEGER: image flags { LOCAL, OWNER, DELETED, REMOTE, MISSING }
 * modificationDate INTEGER: image last check date
 * uploadRemain1 INTEGER: number of bytes to upload for the normal image
 * uploadRemain2 INTEGER: number of bytes to upload for the large image
 * imageSHAs BLOB: image SHA256 (thumbnail or thumbnail+image or thumbnail+image+largeImage)
 * thumbnail BLOB: image thumbnail data
 */
#define IMAGE_CREATE_TABLE \
    @"CREATE TABLE IF NOT EXISTS image (id INTEGER PRIMARY KEY NOT NULL, copiedFrom INTEGER, uuid TEXT NOT NULL," \
    " creationDate INTEGER NOT NULL, flags INTEGER, modificationDate INTEGER," \
    " uploadRemain1 INTEGER, uploadRemain2 INTEGER, shaThumbnail BLOB, imageSHAs BLOB, thumbnail BLOB);"

/**
 * Table from V7 to V19:
 * CREATE TABLE IF NOT EXISTS twincodeImage (id TEXT PRIMARY KEY NOT NULL,
 *                     status INTEGER, copiedFrom TEXT, createDate INTEGER, updateDate INTEGER,
 *                     uploadRemain1 INTEGER, uploadRemain2 INTEGER, thumbnail BLOB);
 */

//
// Interface: TLImageServiceProvider ()
//

@interface TLImageServiceProvider ()

@property (readonly, nonnull) TLImageService *imageService;

@end


//
// Interface: TLImageInfo
//

@implementation TLImageInfo

- (nonnull instancetype)initWithData:(nullable NSData *)data publicId:(nullable NSUUID *)publicId status:(TLImageStatusType)status copiedImageId:(nullable NSUUID *)copiedImageId {
    
    self = [super init];
    if (self) {
        _data = data;
        _publicId = publicId;
        _status = status;
        _copiedImageId = copiedImageId;
    }
    return self;
}

@end

//
// Interface: TLUploadInfo
//

@implementation TLUploadInfo

- (nonnull instancetype)initWithImageId:(nullable TLExportedImageId *)imageId remainNormalImage:(long)remainNormalImage remainLargeImage:(long)remainLargeImage {
    
    self = [super init];
    if (self) {
        _imageId = imageId;
        _remainNormalImage = remainNormalImage;
        _remainLargeImage = remainLargeImage;
    }
    return self;
}

@end

//
// Interface: TLImageDeleteInfo
//

@implementation TLImageDeleteInfo

- (nonnull instancetype)initWithImageId:(nonnull NSUUID *)imageId status:(TLImageDeleteStatusType)status {

    self = [super init];
    if (self) {
        _publicId = imageId;
        _status = status;
    }
    return self;
}

@end

//
// Implementation: TLImageServiceProvider
//

#undef LOG_TAG
#define LOG_TAG @"TLImageServiceProvider"

@implementation TLImageServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLImageService *)service database:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@: initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service database:database sqlCreate:IMAGE_CREATE_TABLE table:TLDatabaseTableImage];
    if (self) {
        _imageService = service;
    }
    return self;
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);
    
    /*
     * <pre>
     * Database Version 22
     *  Date: 2024/07/19
     *   Fix bad mapping between Android and iOS for TLImageStatusTypeOwner and TLImageStatusTypeLocale
     *
     * Database Version 20
     *  Date: 2023/08/29
     *   New database model with image table and change of primary key
     * </pre>
     */
    
    [super onUpgradeWithTransaction:transaction oldVersion:oldVersion newVersion:newVersion];
    
    if (oldVersion < 20 && [transaction hasTableWithName:@"twincodeImage"]) {
        [self upgrade20WithTransaction:transaction];
    }

    if (oldVersion < 22) {
        // Change 1 to 0 and 0 to 1!
        [transaction executeUpdate:@"UPDATE image SET flags=(flags+1)%2 WHERE flags=0 OR flags=1"];
    }
}

- (nullable TLExportedImageId *)createImageWithImageId:(nonnull NSUUID *)imageId locale:(BOOL)locale thumbnail:(nonnull NSData *)thumbnail imageShas:(nonnull NSData *)imageShas remain1Size:(int64_t)remain1Size remain2Size:(int64_t)remain2Size {
    DDLogVerbose(@"%@ createImageWithImageId: %@ locale: %d remain1Size: %lld remain2Size: %lld", LOG_TAG, imageId, locale, remain1Size, remain2Size);

    __block TLExportedImageId *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        int64_t localId = [transaction allocateIdWithTable:TLDatabaseTableImage];
        int64_t creationDate = [[NSDate date] timeIntervalSince1970] * 1000;
        [transaction executeUpdate:@"INSERT INTO image (id, uuid, creationDate, flags, uploadRemain1, uploadRemain2, thumbnail, imageSHAs) VALUES(?, ?, ?, ?, ?, ?, ?, ?)", [NSNumber numberWithLongLong:localId], [TLDatabaseService toObjectWithUUID:imageId], [NSNumber numberWithLongLong:creationDate], [self fromImageStatusType:locale ? TLImageStatusTypeLocale : TLImageStatusTypeOwner], [NSNumber numberWithLongLong:remain1Size], [NSNumber numberWithLongLong:remain2Size], thumbnail, imageShas];
        [transaction commit];
        result = [[TLExportedImageId alloc] initWithPublicId:imageId localId:localId];
    }];
    return result;
}

- (BOOL)importImageWithImageId:(nonnull TLImageId *)imageId status:(TLImageStatusType)status thumbnail:(nonnull NSData *)thumbnail imageSha:(nonnull NSData *)imageSha {
    DDLogVerbose(@"%@ importImageWithImageId: %@ status: %d", LOG_TAG, imageId, status);

    __block BOOL result = NO;
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE image SET flags=?, thumbnail=?, imageSHAs=? WHERE id=?", [self fromImageStatusType:status], thumbnail, imageSha, [NSNumber numberWithLongLong:imageId.localId]];
        [transaction commit];
        result = YES;
    }];
    return result;
}

- (nullable TLExportedImageId *)copyImageWithImageId:(nonnull NSUUID *)imageId copiedFromImageId:(nonnull TLImageId *)copiedFromImageId {
    DDLogVerbose(@"%@ copyImageWithImageId: %@ copiedFromImageId: %@", LOG_TAG, imageId, copiedFromImageId);

    __block TLExportedImageId *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        int64_t localId = [transaction allocateIdWithTable:TLDatabaseTableImage];
        int64_t creationDate = [[NSDate date] timeIntervalSince1970] * 1000;
        [transaction executeUpdate:@"INSERT INTO image (id, uuid, creationDate, flags, copiedFrom)"
         " VALUES(?, ?, ?, ?, ?)", [NSNumber numberWithLongLong:localId], [TLDatabaseService toObjectWithUUID:imageId], [NSNumber numberWithLongLong:creationDate], [self fromImageStatusType:TLImageStatusTypeOwner], [NSNumber numberWithLongLong:copiedFromImageId.localId]];
        [transaction commit];
        result = [[TLExportedImageId alloc] initWithPublicId:imageId localId:localId];
    }];
    return result;
}

- (nullable TLImageInfo *)loadImageWithImageId:(nonnull TLImageId *)imageId {
    DDLogVerbose(@"%@ loadImageWithImageId: %@", LOG_TAG, imageId);

    __block TLImageInfo *result = nil;
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT img.uuid, img.flags, img.thumbnail,"
                " origin.flags AS origFlags, origin.thumbnail AS originThumbnail, origin.uuid AS originUuid FROM image AS img"
                " LEFT JOIN image AS origin ON img.copiedFrom = origin.id"
                                  " WHERE img.id=?", [NSNumber numberWithLongLong:imageId.localId]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if ([resultSet next]) {
            NSData *thumbnail;
            TLImageStatusType status;
            
            NSUUID *publicId = [resultSet uuidForColumnIndex:0];
            thumbnail = [resultSet dataForColumnIndex:2];
            if (thumbnail) {
                if ([resultSet columnIndexIsNull:1]) {
                    status = TLImageStatusTypeNeedFetch;
                } else {
                    status = [self toImageStatusType:[resultSet intForColumnIndex:1]];
                }
                result = [[TLImageInfo alloc] initWithData:thumbnail publicId:publicId status:status copiedImageId:nil];
            } else {
                thumbnail = [resultSet dataForColumnIndex:4];
                status = [self toImageStatusType:[resultSet intForColumnIndex:3]];
                result = [[TLImageInfo alloc] initWithData:thumbnail publicId:publicId status:status copiedImageId:[resultSet uuidForColumnIndex:5]];
            }
        }
        [resultSet close];
    }];
    
    return result;
}

- (void)saveRemainUploadSizeWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind remainSize:(int64_t)remainSize {
    DDLogVerbose(@"%@ saveRemainUploadSizeWithImageId: %@ kind: %d remainSize: %lld", LOG_TAG, imageId, kind, remainSize);

    [self inTransaction:^(TLTransaction *transaction) {
        if (kind == TLImageServiceKindNormal) {
            [transaction executeUpdate:@"UPDATE image SET uploadRemain1=? WHERE id=?", [NSNumber numberWithLongLong:remainSize], [NSNumber numberWithLongLong:imageId.localId]];

        } else {
            [transaction executeUpdate:@"UPDATE image SET uploadRemain2=? WHERE id=?", [NSNumber numberWithLongLong:remainSize], [NSNumber numberWithLongLong:imageId.localId]];
        }
        [transaction commit];
    }];
}

- (int64_t)getUploadRemainSizeWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind {
    DDLogVerbose(@"%@ getUploadRemainSizeWithImageId: %@ kind: %d", LOG_TAG, imageId, kind);

    __block long size;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            size = 0;

        } else if (kind == TLImageServiceKindNormal) {
            size = [database longForQuery:@"SELECT uploadRemain1 FROM image WHERE id=?", [NSNumber numberWithLongLong:imageId.localId]];
            
        } else {
            size = [database longForQuery:@"SELECT uploadRemain2 FROM image WHERE id=?", [NSNumber numberWithLongLong:imageId.localId]];
        }
    }];
    
    return size;
}

- (nullable TLImageDeleteInfo *)deleteImageWithImageId:(nonnull TLImageId *)imageId localOnly:(BOOL)localOnly {
    DDLogVerbose(@"%@ deleteImageWithImageId: %@ localOnly: %d", LOG_TAG, imageId, localOnly);

    __block NSUUID *publicId = nil;
    __block long count = 0;
    __block TLImageStatusType status = TLImageStatusTypeNeedFetch;
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *localId = [NSNumber numberWithLongLong:imageId.localId];

        // Get the image UUID, status and count of copiedFrom references the image has
        FMResultSet *resultSet = [transaction executeQuery:@"SELECT img.uuid, img.flags, COUNT(c.id) FROM image AS img"
                                  " LEFT JOIN image AS c ON c.copiedFrom=img.id WHERE img.id=?", localId];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
            return;
        }

        if ([resultSet next]) {
            publicId = [resultSet uuidForColumnIndex:0];
            if ([resultSet columnIndexIsNull:1]) {
                status = TLImageStatusTypeNeedFetch;
            } else {
                status = [self toImageStatusType:[resultSet intForColumnIndex:1]];
            }
            count = [resultSet intForColumnIndex:2];
        }
        [resultSet close];

        if (publicId && (!localOnly || status != TLImageStatusTypeOwner)) {
            if (count == 0) {
                [transaction executeUpdate:@"DELETE FROM image WHERE id=?", localId];
                
            } else {
                [transaction executeUpdate:@"UPDATE image SET flags=? WHERE id=?", [self fromImageStatusType:TLImageStatusTypeDeleted], localId];
            }
        }
        [transaction commit];
    }];
    
    if (!publicId) {
        return nil;
    }

    // Cache files associated with the image can be removed when there is no more reference.
    // PR 3335:
    //  When a user creates a contact with its own profile deleteImage is called on the peerAvatarId
    //   that is indeed the avatarId of the profile
    //   Using TLImageDeleteStatusTypeNone instead of TLImageDeleteStatusTypeRemote solves this problem and does
    //   not generated phantom image in the server
    //
    if (status == TLImageStatusTypeOwner) {
        return [[TLImageDeleteInfo alloc] initWithImageId:publicId status:count == 0 ? TLImageDeleteStatusTypeLocalRemote : TLImageDeleteStatusTypeNone];
    }
    
    // Image was locale or is owned by someone else.
    return [[TLImageDeleteInfo alloc] initWithImageId:publicId status:count == 0 ? TLImageDeleteStatusTypeLocal : TLImageDeleteStatusTypeNone];
}

- (void)deleteImageWithTransaction:(nonnull TLTransaction *)transaction imageId:(nullable TLImageId *)imageId {
    DDLogVerbose(@"%@ deleteImageWithTransaction: %@", LOG_TAG, imageId);

    NSNumber *localId = [NSNumber numberWithLongLong:imageId.localId];
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT uuid FROM image WHERE id=?", localId];
    if (!resultSet) {
        return;
    }
    NSUUID *publicId = nil;
    if ([resultSet next]) {
        publicId = [resultSet uuidForColumnIndex:0];
    }
    [resultSet close];
    [transaction executeUpdate:@"DELETE FROM image WHERE id=? AND (flags=3 OR flags=5)", localId];
    if ([transaction changes] > 0 && publicId) {
        [self.imageService notifyDeletedWithImageId:imageId publicId:publicId];
    }
}

- (nullable NSUUID *)evictImageWithImageId:(nonnull TLImageId *)imageId {
    DDLogVerbose(@"%@ evictImageWithImageId: %@", LOG_TAG, imageId);

    __block NSUUID *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *localId = [NSNumber numberWithLongLong:imageId.localId];
        FMResultSet *resultSet = [transaction executeQuery:@"SELECT uuid FROM image WHERE id=?", localId];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
            return;
        }
        NSUUID *publicId;
        if ([resultSet next]) {
            publicId = [resultSet uuidForColumnIndex:0];
        }
        [resultSet close];
        [transaction executeUpdate:@"DELETE FROM image WHERE id=? AND (flags=3 OR flags=5)", localId];
        if ([transaction changes] <= 0) {
            publicId = nil;
        }
        [transaction commit];
        result = publicId;
    }];

    return result;
}

- (nonnull NSMutableDictionary<TLImageId *, TLImageId *> *)listCopiedImages {
    DDLogVerbose(@"%@ listCopiedImages", LOG_TAG);

    NSMutableDictionary<TLImageId *, TLImageId *> *result = [[NSMutableDictionary alloc] init];

    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT id, copiedFrom FROM image WHERE copiedFrom IS NOT NULL"];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            int64_t imageId = [resultSet longLongIntForColumnIndex:0];
            int64_t copiedFromId = [resultSet longLongIntForColumnIndex:1];
            
            if (imageId > 0 && copiedFromId > 0) {
                [result setObject:[[TLImageId alloc] initWithLocalId:copiedFromId] forKey:[[TLImageId alloc] initWithLocalId:imageId]];
            }
        }
        [resultSet close];
    }];

    return result;
}

- (nullable TLExportedImageId *)imageWithPublicId:(nonnull NSUUID *)publicId {
    DDLogVerbose(@"%@ imageWithPublicId: %@", LOG_TAG, publicId);

    __block TLExportedImageId *result = nil;
    [self.database inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT id FROM image WHERE uuid=?", [publicId toString]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if ([resultSet next]) {
            long localId = [resultSet longForColumnIndex:0];
            if (localId > 0) {
                result = [[TLExportedImageId alloc] initWithPublicId:publicId localId:localId];
            }
        }
        [resultSet close];
    }];
    return result;
}

- (nullable TLUploadInfo *)nextUpload {
    DDLogVerbose(@"%@ nextUpload", LOG_TAG);

    __block TLUploadInfo *result = nil;
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:@"SELECT id, uuid, uploadRemain1, uploadRemain2"
                                      " FROM image WHERE uploadRemain1 > 0 OR uploadRemain2 > 0 LIMIT 1", nil];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if ([resultSet next]) {
            int64_t localId = [resultSet longLongIntForColumnIndex:0];
            NSUUID *publicId = [resultSet uuidForColumnIndex:1];
            if (publicId) {
                long remain1 = [resultSet longForColumnIndex:2];
                long remain2 = [resultSet longForColumnIndex:3];
                
                result = [[TLUploadInfo alloc] initWithImageId:[[TLExportedImageId alloc] initWithPublicId:publicId localId:localId] remainNormalImage:remain1 remainLargeImage:remain2];
            }
        }
        [resultSet close];
    }];
    
    return result;
}

- (nonnull NSNumber *)fromImageStatusType:(TLImageStatusType)type {
    
    switch (type) {
        case TLImageStatusTypeOwner:
            return [NSNumber numberWithInt:0];
        case TLImageStatusTypeLocale:
            return [NSNumber numberWithInt:1];
        case TLImageStatusTypeDeleted:
            return [NSNumber numberWithInt:2];
        case TLImageStatusTypeRemote:
            return [NSNumber numberWithInt:3];
        case TLImageStatusTypeMissing:
            return [NSNumber numberWithInt:4];
        case TLImageStatusTypeNeedFetch:
            return [NSNumber numberWithInt:5];
    }
    return [NSNumber numberWithInt:2];
}

- (TLImageStatusType)toImageStatusType:(long)value {
    switch (value) {
        case 0:
            return TLImageStatusTypeOwner;
        case 1:
            return TLImageStatusTypeLocale;
        case 2:
            return TLImageStatusTypeDeleted;
        case 3:
            return TLImageStatusTypeRemote;
        case 4:
            return TLImageStatusTypeMissing;
        case 5:
            return TLImageStatusTypeNeedFetch;
    }
    return TLImageStatusTypeDeleted;
}

- (void)upgrade20WithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ upgrade20WithTransaction: %@", LOG_TAG, transaction);

    // Step 1: migrate images which are not a copy of one of our image.
    // Do this one by one and remove the image from the old table to free up some space.
    // A thumbnail is stored in several database pages and the deletion allows to re-use
    // a freed page and avoid to grow the database file too much.
    // Copying is necessary due to the primary key that is changed.
    NSMutableDictionary<NSUUID *, NSNumber *> *imageMap = [[NSMutableDictionary alloc] init];
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT id, uuid FROM image"];
    if (resultSet) {
        while ([resultSet next]) {
            long imageId = [resultSet longForColumnIndex:0];
            NSUUID *uuid = [resultSet uuidForColumnIndex:1];
            if (uuid) {
                [imageMap setObject:[NSNumber numberWithLong:imageId] forKey:uuid];
            }
        }
        [resultSet close];
    }
    
    while (YES) {
        resultSet = [transaction executeQuery:@"SELECT id, status, createDate, updateDate, uploadRemain1,"
                                  " uploadRemain2, thumbnail FROM twincodeImage WHERE copiedFrom IS NULL LIMIT 1"];
        if (!resultSet) {
            break;
        }
        BOOL hasImage = [resultSet next];
        if (hasImage) {
            NSString *imgId = [resultSet stringForColumnIndex:0];
            NSUUID *imageId = [[NSUUID alloc] initWithUUIDString:imgId];
            int status = [resultSet intForColumnIndex:1];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:2];
            int64_t updateDate = [resultSet longLongIntForColumnIndex:3];
            int64_t uploadRemain1 = [resultSet longLongIntForColumnIndex:4];
            int64_t uploadRemain2 = [resultSet longLongIntForColumnIndex:5];
            NSData *thumbnail = [resultSet dataForColumnIndex:6];
            [transaction executeUpdate:@"DELETE FROM twincodeImage WHERE id=?", imgId];
            if (imageId) {
                long localId = [transaction allocateIdWithTable:TLDatabaseTableImage];
                NSNumber *newId = [NSNumber numberWithLong:localId];
                    
                [transaction executeUpdate:@"INSERT INTO image (id, uuid, creationDate, modificationDate, flags, uploadRemain1, uploadRemain2, thumbnail) VALUES(?, ?, ?, ?, ?, ?, ?, ?)", newId, [TLDatabaseService toObjectWithUUID:imageId], [NSNumber numberWithLongLong:creationDate], [NSNumber numberWithLongLong:updateDate], [NSNumber numberWithInt:status], [NSNumber numberWithLongLong:uploadRemain1], [NSNumber numberWithLongLong:uploadRemain2], [TLDatabaseService toObjectWithData:thumbnail]];
                [imageMap setObject:newId forKey:imageId];

                // Because images use several pages, commit after each insert+delete.
                [transaction commit];
            }
        }
        [resultSet close];
        if (!hasImage) {
            break;
        }
    }

    // Step 2: migrate images which are a copy of an image (we don't need the thumbnail, uploadRemainX).
    resultSet = [transaction executeQuery:@"SELECT id, copiedFrom, status, createDate, updateDate"
                              " FROM twincodeImage WHERE copiedFrom IS NOT NULL"];
    if (resultSet) {
        while ([resultSet next]) {
            @try {
                NSUUID *imageId = [resultSet uuidForColumnIndex:0];
                NSUUID *copiedFromId = [resultSet uuidForColumnIndex:1];
                int status = [resultSet intForColumnIndex:2];
                int64_t creationDate = [resultSet longLongIntForColumnIndex:3];
                int64_t updateDate = [resultSet longLongIntForColumnIndex:4];
                if (imageId && copiedFromId) {
                    NSNumber *copiedId = imageMap[copiedFromId];
                    if (copiedId != nil) {
                        long localId = [transaction allocateIdWithTable:TLDatabaseTableImage];
                        NSNumber *newId = [NSNumber numberWithLong:localId];
                        
                        [transaction executeUpdate:@"INSERT INTO image (id, uuid, copiedFrom, creationDate, modificationDate, flags) VALUES(?, ?, ?, ?, ?, ?)", newId, [TLDatabaseService toObjectWithUUID:imageId], copiedId, [NSNumber numberWithLongLong:creationDate], [NSNumber numberWithLongLong:updateDate], [NSNumber numberWithInt:status]];
                    }
                }
            } @catch (NSException *exception) {
                DDLogError(@"%@ upgrade20WithTransaction: exception: %@", LOG_TAG, exception);
            }
        }
        [resultSet close];
    }
    [transaction dropTable:@"twincodeImage"];
}

@end

/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDatabaseServiceProvider.h"
#import "TLImageService.h"

@class TLImageService;

typedef enum {
    TLImageStatusTypeLocale,             // Image is locale and not stored on the server (ex: Space settings).
    TLImageStatusTypeOwner,              // Image is created by us.
    TLImageStatusTypeDeleted,            // Image is created by us and was deleted.
    TLImageStatusTypeRemote,             // Image is remote and available.
    TLImageStatusTypeMissing,            // Image is remote but was not found.
    TLImageStatusTypeNeedFetch           // Image must be queried from the server.
} TLImageStatusType;

typedef enum {
    TLImageDeleteStatusTypeNone,         // No action to perform.
    TLImageDeleteStatusTypeRemote,       // Image must be deleted remotely.
    TLImageDeleteStatusTypeLocal,        // Image must be deleted locally.
    TLImageDeleteStatusTypeLocalRemote   // Image must be deleted locally and remotely.
} TLImageDeleteStatusType;

//
// Interface: TLImageInfo
//

@interface TLImageInfo : NSObject

@property (readonly, nullable) NSUUID *publicId;
@property (readonly, nullable) NSData *data;
@property (readonly) TLImageStatusType status;
@property (readonly, nullable) NSUUID *copiedImageId;

- (nonnull instancetype)initWithData:(nullable NSData *)data publicId:(nullable NSUUID *)publicId status:(TLImageStatusType)status copiedImageId:(nullable NSUUID *)copiedImageId;

@end

//
// Interface: TLUploadInfo
//

@interface TLUploadInfo : NSObject

@property (nonnull, readonly) TLExportedImageId *imageId;
@property (readonly) long remainNormalImage;
@property (readonly) long remainLargeImage;

- (nonnull instancetype)initWithImageId:(nullable TLExportedImageId *)imageId remainNormalImage:(long)remainNormalImage remainLargeImage:(long)remainLargeImage;

@end

//
// Interface: TLImageDeleteInfo
//

@interface TLImageDeleteInfo : NSObject

@property (nonnull, readonly) NSUUID *publicId;
@property (readonly) TLImageDeleteStatusType status;

- (nonnull instancetype)initWithImageId:(nonnull NSUUID *)imageId status:(TLImageDeleteStatusType)status;

@end

//
// Interface: TLImageServiceProvider
//

@interface TLImageServiceProvider : TLDatabaseServiceProvider <TLImagesCleaner>

- (nonnull instancetype)initWithService:(nonnull TLImageService *)service database:(nonnull TLDatabaseService *)database;

/// Store in the database a new image with the given imageId and thumbnail data.
- (nullable TLExportedImageId *)createImageWithImageId:(nonnull NSUUID *)imageId locale:(BOOL)locale thumbnail:(nonnull NSData *)thumbnail imageShas:(nonnull NSData *)imageShas remain1Size:(int64_t)remain1Size remain2Size:(int64_t)remain2Size;

- (BOOL)importImageWithImageId:(nonnull TLImageId *)imageId status:(TLImageStatusType)status thumbnail:(nonnull NSData *)thumbnail imageSha:(nonnull NSData *)imageSha;

/// Store in the database a copy of the image after we received the new imageId from the server.
- (nullable TLExportedImageId *)copyImageWithImageId:(nonnull NSUUID *)imageId copiedFromImageId:(nonnull TLImageId *)copiedFromImageId;

/// Load the image information as well as its thumbnail data.
- (nullable TLImageInfo *)loadImageWithImageId:(nonnull TLImageId *)imageId;

/// Save the remain size for the upload so that we can recover a partial upload.
- (void)saveRemainUploadSizeWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind remainSize:(int64_t)remainSize;

/// Get the upload remain size to finish the upload when it was broken.
- (int64_t)getUploadRemainSizeWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind;

/// Delete the image from the database.
- (nullable TLImageDeleteInfo *)deleteImageWithImageId:(nonnull TLImageId *)imageId localOnly:(BOOL)localOnly;

/// Delete the remote image from the database.  Return UUID when the remote image was found and removed.
/// Return nil if the remote imageId was not found, or, this image must not be evicted.
- (nullable NSUUID *)evictImageWithImageId:(nonnull TLImageId *)imageId;

/// Get the information for the next image to be uploaded.
- (nullable TLUploadInfo *)nextUpload;

- (nonnull NSMutableDictionary<TLImageId *, TLImageId *> *)listCopiedImages;

- (nullable TLExportedImageId *)imageWithPublicId:(nonnull NSUUID *)publicId;

@end

/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"
#import "TLImageId.h"

/// Maximum dimension for the normal image, above that we consider this is a large image.
#define TL_NORMAL_IMAGE_WIDTH  1280
#define TL_NORMAL_IMAGE_HEIGHT 1280

#define TL_LARGE_IMAGE_HEIGHT  3000
#define TL_LARGE_IMAGE_WIDTH   3000

#define TL_LOCAL_IMAGE_WIDTH   2048  // Should not exceed 2048 for background usage (Android + migration constraint).
#define TL_LOCAL_IMAGE_HEIGHT  2048

typedef enum {
    TLImageServiceKindThumbnail, // image <= 256x256
    TLImageServiceKindNormal,    // image <= 1280x1280 (optional)
    TLImageServiceKindLarge      // full scale (optional)
} TLImageServiceKind;

//
// Interface: TLImageServiceConfiguration
//

@interface TLImageServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Interface: TLImageService
//

@interface TLImageService : TLBaseService

+ (nonnull NSString *)VERSION;

/// Get the image identified by the imageId when it is present in the local cache.  If it is not in the case, return nil.
/// Use of this method is allowed from the main UI thread as it does not block.
- (nullable UIImage *)getCachedImageIfPresentWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind;

/// Get the image identified by the imageId from the local cache.  If the image is not found
/// locally, it is necessary to call getImage and the image will be loaded asynchronously.
/// This method is not allowed from the main UI thread as it can block due to possible database access.
- (nullable UIImage *)getCachedImageWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind;

/// Get the image identified by the imageId and call the consumer onGet operation with it.
/// When the image was not found, the onGet() receives the ITEM_NOT_FOUND error and a null image.
- (void)getImageWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind) kind withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, UIImage *_Nullable image))block;

/// Create an image identifier associated with the given image and its thumbnail.
/// The image can be retrieved through `getImage`.  Once the image is saved and an identifier
/// allocated, the consumer onGet operation is called with the new image identifier.
- (void)createImageWithImage:(nullable UIImage *)image thumbnail:(nonnull UIImage *)thumbnail withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLExportedImageId *_Nullable imageId))block;

/// Store locally an image that can be retreived with getImage and the given image id.
- (void)createLocalImageWithImage:(nullable UIImage *)image thumbnail:(nonnull UIImage *)thumbnail withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLExportedImageId *_Nullable imageId))block;

/// Create a copy of an existing image.  Once the server has copied the image and allocated
/// a new image identifier, the consumer onGet operation is called with the new identifier.
/// When the image identified was not found, the onGet operation receives the ITEM_NOT_FOUND
/// error and a null identifier.
- (void)copyImageWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLExportedImageId *_Nullable imageId))block;

/// Delete the image identified by the imageId.  The image is first removed from the local
/// cache and if it was created by the current user it is also removed on the server.
/// The onGet operation is called when the image is removed.
- (void)deleteImageWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLImageId *_Nullable imageId))block;

/// Remove the image identified by the imageId from the local cache.
- (void)evictImageWithImageId:(nonnull TLImageId *)imageId;

/// Get a list of image IDs that have been copied by the device from an image we created.
/// The map is keyed with the UUID of the image copied with `copyImage` and indicates the
/// original image Id that was used for the copy.  It can be used to identify images
/// that are identical.  Note: this only works for the images we have created and copied ourselves.
- (nonnull NSMutableDictionary<TLImageId *, TLImageId *> *)listCopiedImages;

/// Get the public image ID associated with the given image.
- (nullable TLExportedImageId *)publicWithImageId:(nonnull TLImageId *)imageId;

- (nullable TLExportedImageId *)imageWithPublicId:(nonnull NSUUID *)publicId;

@end

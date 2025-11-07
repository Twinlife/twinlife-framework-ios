/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLImageId
//

/**
 * The ImageId holds a unique local identifier to reference an image.  When a twincode is received with an
 * "avatarId", it is associated with an ImageId to reference the twincode image.  The "avatarId" is no longer
 * accessible directly from the twincode.  When we want to create an image, an ExternalImageId is provided
 * which indicates both the unique local identifier and the exported UUID which can be used for the "avatarId"
 * twincode attribute.
 */

@interface TLImageId : NSObject <NSCopying>

@property (readonly) int64_t localId;

- (nonnull instancetype)initWithLocalId:(int64_t)localId;

@end

//
// Interface: TLExportedImageId
//

/**
 * Same as the ImageId with the UUID that can be used to export the image id in a twincode attribute.
 */

@interface TLExportedImageId : TLImageId

@property (readonly, nonnull) NSUUID *publicId;

- (nonnull instancetype)initWithPublicId:(nonnull NSUUID *)publicId localId:(int64_t)localId;

@end

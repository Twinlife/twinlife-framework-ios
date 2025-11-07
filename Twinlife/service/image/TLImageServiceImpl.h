/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLImageService.h"
#import "TLBaseServiceImpl.h"
#import "TLJobService.h"
#import "TLAssertion.h"

@class TLPutImageIQ;

//
// Interface: TLImageControlPoint ()
//

@interface TLImageAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)COPY_IMAGE;
+(nonnull TLAssertPoint *)READ_IMAGE;

@end

typedef void (^TLImageConsumer) (TLBaseServiceErrorCode status, UIImage * _Nullable image);

typedef void (^TLImageIdConsumer) (TLBaseServiceErrorCode status, TLImageId * _Nullable imageId);

typedef void (^TLImageExportedIdConsumer) (TLBaseServiceErrorCode status, TLExportedImageId * _Nullable imageId);

//
// Interface: TLImagePendingRequest ()
//

@interface TLImagePendingRequest : NSObject

@end

//
// Interface: TLGetImagePendingRequest ()
//

@interface TLGetImagePendingRequest : TLImagePendingRequest

@property (readonly, nonnull) TLImageId *imageId;
@property (readonly, nonnull) NSUUID *publicId;
@property (readonly) TLImageServiceKind kind;
@property (readonly, nonnull) TLImageConsumer imageConsumer;
@property (readonly, nullable) TLImageIdConsumer imageIdConsumer;
@property (nullable) NSMutableData *imageReceived;
@property (nullable) TLGetImagePendingRequest *nextRequest; // Next request for this same image.

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId publicId:(nonnull NSUUID *)publicId kind:(TLImageServiceKind)kind withBlock:(nonnull TLImageConsumer)block;

- (void)dispatchWithErrorCode:(TLBaseServiceErrorCode)errorCode image:(nullable UIImage *)image;

@end

//
// Interface: TLCreateImagePendingRequest ()
//

@interface TLCreateImagePendingRequest : TLImagePendingRequest

@property (readonly, nullable) TLImageExportedIdConsumer imageIdConsumer;
@property (readonly, nullable) NSString *imagePath;
@property (readonly, nullable) NSString *imageLargePath;
@property (nullable) NSData *imageData;
@property (nullable) NSData *imageShas;
@property (nullable) NSMutableData *imageReceived;
@property (readonly) int64_t total1Length;
@property (readonly) int64_t total2Length;

-(nonnull instancetype)initWithPath:(nullable NSString *)path imageLargePath:(nullable NSString *)imageLargePath imageData:(nonnull NSData *)imageData thumbnailSha:(nullable NSData *)thumbnailSha imageSha:(nullable NSData *)imageSha imageLargeSha:(nullable NSData *)imageLargeSha total1Length:(int64_t)total1Length total2Length:(int64_t)total2Length withBlock:(nonnull TLImageExportedIdConsumer)block;

@end

//
// Interface: TLUploadImagePendingRequest ()
//

@interface TLUploadImagePendingRequest : TLImagePendingRequest

@property (readonly, nonnull) TLImageId *imageId;
@property (readonly) TLImageServiceKind kind;
@property (readonly) int64_t totalLength;
@property (readonly, nonnull) NSMutableArray<TLPutImageIQ *> *queue;
@property int sendCount;

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind totalLength:(int64_t)totalLength;

@end

//
// Interface: TLCopyImagePendingRequest ()
//

@interface TLCopyImagePendingRequest : TLImagePendingRequest

@property (readonly, nonnull) TLImageId *imageId;
@property (readonly, nonnull) TLImageExportedIdConsumer imageIdConsumer;

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull TLImageExportedIdConsumer)block;

@end

//
// Interface: TLDeleteImagePendingRequest ()
//

@interface TLDeleteImagePendingRequest : TLImagePendingRequest

@property (readonly, nonnull) TLImageId *imageId;
@property (readonly, nonnull) NSUUID *publicId;
@property (readonly, nonnull) TLImageIdConsumer imageIdConsumer;

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId publicId:(nonnull NSUUID *)publicId withBlock:(nonnull TLImageIdConsumer)block;

@end

@interface TLImageService ()

- (void)notifyDeletedWithImageId:(nonnull TLImageId *)imageId publicId:(nonnull NSUUID *)publicId;

@end


/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <MobileCoreServices/MobileCoreServices.h>
#include <CommonCrypto/CommonDigest.h>

#import "TLImageServiceImpl.h"
#import "TLImageServiceProvider.h"
#import "TLCreateImageIQ.h"
#import "TLCopyImageIQ.h"
#import "TLGetImageIQ.h"
#import "TLPutImageIQ.h"
#import "TLDeleteImageIQ.h"
#import "TLOnCreateImageIQ.h"
#import "TLOnCopyImageIQ.h"
#import "TLOnDeleteImageIQ.h"
#import "TLOnGetImageIQ.h"
#import "TLOnPutImageIQ.h"
#import "TLBinaryErrorPacketIQ.h"

#define COPY_IMAGE_SCHEMA_ID       @"6c2a932e-3dc6-47f2-b253-6975818d3a3c"
#define CREATE_IMAGE_SCHEMA_ID     @"ea6b4372-3c7d-4ce8-92d8-87a589906a01"
#define DELETE_IMAGE_SCHEMA_ID     @"22a99e04-6485-4808-9f08-4e421e2e5241"
#define GET_IMAGE_SCHEMA_ID        @"3a9ca7c4-6153-426d-b716-d81fd625293c"
#define PUT_IMAGE_SCHEMA_ID        @"6e0db5e2-318a-4a78-8162-ad88c6ae4b07"

#define ON_COPY_IMAGE_SCHEMA_ID    @"9fe6e706-2442-455b-8c7e-384d371560c1"
#define ON_CREATE_IMAGE_SCHEMA_ID  @"dfb67bd7-2e6a-4fd0-b05d-b34b916ea6cf"
#define ON_DELETE_IMAGE_SCHEMA_ID  @"9e2f9bb9-b614-4674-b3a6-0474aefa961f"
#define ON_GET_IMAGE_SCHEMA_ID     @"9ec1280e-a298-4c8b-b0fd-35383f7b5424"
#define ON_PUT_IMAGE_SCHEMA_ID     @"f48fa894-a200-4aa8-a7d4-22ea21cfd008"

#define DEFAULT_CHUNK_SIZE (32768) // Be conservative and use a default < 64K.

#define MAX_IMAGE_SIZE     (4*1024*1024) // 4Mb PNG/JPG file max
#define IMAGE_JPEG_QUALITY 0.9

// Send 2 PutImageIQ and queue the others until we get a response and then proceed with sending more.
// - if the value is too big, this delays the execution of other operations (creation and update of twincode),
// - if the value is too small (min is 1), sending the image will take more time.
// 2 seems to give a good balance between the two.
#define MAX_SEND_IMAGE_IQ  2

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define IMAGE_SERVICE_VERSION @"2.0.3"

static TLBinaryPacketIQSerializer *IQ_COPY_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_CREATE_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_DELETE_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_GET_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_PUT_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_COPY_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_CREATE_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_DELETE_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_GET_IMAGE_SERIALIZER = nil;
static TLBinaryPacketIQSerializer *IQ_ON_PUT_IMAGE_SERIALIZER = nil;

//
// Interface: TLImageJob
//
@interface TLImageJob : NSObject <TLJob>

@property (weak, readonly) TLImageService *service;

- (nonnull instancetype)initWithService:(nonnull TLImageService *)service;

@end

//
// Interface: TLImageService ()
//

@class TLImageServiceProvider;

@interface TLImageService ()

@property (readonly, nonnull) TLImageJob *imageJob;
@property (readonly, nonnull) TLImageServiceProvider *serviceProvider;
@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLImagePendingRequest *> *pendingRequests;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly) int64_t maxImageSize;
@property BOOL checkUpload;
@property (weak, nullable) TLJobId *uploadJob;
@property int64_t uploadChunkSize;
@property (nullable) TLUploadImagePendingRequest *uploadRequest;

/// Cache for the thumbnail and cache for large images.  The NSCache is thread safe.
@property (readonly, nonnull) NSCache<TLImageId *, UIImage *> *thumbnailCache;
@property (readonly, nonnull) NSCache<TLImageId *, UIImage *> *imageCache;

+ (void)initialize;

- (void)backgroundUpload;

@end

//
// Interface: TLImageControlPoint ()
//

@implementation TLImageAssertPoint

TL_CREATE_ASSERT_POINT(COPY_IMAGE, 200)
TL_CREATE_ASSERT_POINT(READ_IMAGE, 201)

@end

//
// Implementation: TLImageJob
//

#undef LOG_TAG
#define LOG_TAG @"TLImageJob"

@implementation TLImageJob

- (nonnull instancetype)initWithService:(nonnull TLImageService *)service {

    self = [super init];
    if (self) {
        _service = service;
    }

    return self;
}

- (void)runJob {
    DDLogVerbose(@"%@ runJob", LOG_TAG);

    [self.service backgroundUpload];
}

@end

//
// Implementation: TLImageId
//

#undef LOG_TAG
#define LOG_TAG @"TLImageId"

@implementation TLImageId

- (nonnull instancetype)initWithLocalId:(int64_t)localId {
    
    self = [super init];
    if (self) {
        _localId = localId;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return YES;
    }
    
    // Accept a TLExportedImageId
    if (![object isKindOfClass:[TLImageId class]]) {
        return NO;
    }
    
    TLImageId *item = (TLImageId *)object;
    
    return self.localId == item.localId;
}

- (NSUInteger)hash {
    
    return (NSUInteger)(self.localId ^ (self.localId >> 32));
}

- (id)copyWithZone:(NSZone *)zone {
    
    return self;
}

- (NSString *)description {
    
    return [NSString stringWithFormat:@"IMG-%lld", self.localId];
}

@end

//
// Implementation: TLExportedImageId
//

#undef LOG_TAG
#define LOG_TAG @"TLExportedImageId"

@implementation TLExportedImageId

- (nonnull instancetype)initWithPublicId:(nonnull NSUUID *)publicId localId:(int64_t)localId {

    self = [super initWithLocalId:localId];
    if (self) {
        _publicId = publicId;
    }
    return self;
}

@end

//
// Implementation: TLImageServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLImageServiceConfiguration"

@implementation TLImageServiceConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdImageService version:[TLImageService VERSION] serviceOn:NO];
}

@end

//
// Implementation: TLImagePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLImagePendingRequest"

@implementation TLImagePendingRequest

@end

//
// Implementation: TLGetImagePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLGetImagePendingRequest"

@implementation TLGetImagePendingRequest

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId publicId:(nonnull NSUUID *)publicId kind:(TLImageServiceKind)kind withBlock:(nonnull TLImageConsumer)block {
    
    self = [super init];
    if (self) {
        _imageId = imageId;
        _publicId = publicId;
        _kind = kind;
        _imageConsumer = block;
        _nextRequest = nil;
    }
    return self;
}

- (void)dispatchWithErrorCode:(TLBaseServiceErrorCode)errorCode image:(nullable UIImage *)image {
    
    TLGetImagePendingRequest *request = self;
    do {
        if (request.imageConsumer) {
            request.imageConsumer(errorCode, image);
        }
        request = request.nextRequest;
    } while (request != nil);
}

@end

//
// Implementation: TLUploadImagePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLUploadImagePendingRequest"

@implementation TLUploadImagePendingRequest

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind totalLength:(int64_t)totalLength {
    
    self = [super init];
    if (self) {
        _imageId = imageId;
        _kind = kind;
        _totalLength = totalLength;
        _sendCount = 0;
        _queue = [[NSMutableArray alloc] initWithCapacity:32];
    }
    return self;
}

@end

//
// Implementation: TLCreateImagePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLCreateImagePendingRequest"

@implementation TLCreateImagePendingRequest

-(nonnull instancetype)initWithPath:(nullable NSString *)path imageLargePath:(nullable NSString *)imageLargePath imageData:(nonnull NSData *)imageData thumbnailSha:(nullable NSData *)thumbnailSha imageSha:(nullable NSData *)imageSha imageLargeSha:(nullable NSData *)imageLargeSha total1Length:(int64_t)total1Length total2Length:(int64_t)total2Length withBlock:(nonnull TLImageExportedIdConsumer)block {
    
    self = [super init];
    if (self) {
        _imagePath = path;
        _imageLargePath = imageLargePath;
        _imageData = imageData;
        _total1Length = total1Length;
        _total2Length = total2Length;
        _imageIdConsumer = block;
        unsigned long length = thumbnailSha.length;
        if (imageSha) {
            length += imageSha.length + (imageLargeSha ? imageLargeSha.length : 0);
        }
        NSMutableData *sha = [[NSMutableData alloc] initWithCapacity:length];
        [sha appendData:thumbnailSha];
        if (imageSha) {
            [sha appendData:imageSha];
            if (imageLargeSha) {
                [sha appendData:imageLargeSha];
            }
        }
        _imageShas = imageSha;
    }
    return self;
}

@end

//
// Implementation: TLCopyImagePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLCopyImagePendingRequest"

@implementation TLCopyImagePendingRequest

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull TLImageExportedIdConsumer)block {
    
    self = [super init];
    if (self) {
        _imageId = imageId;
        _imageIdConsumer = block;
    }
    return self;
}

@end

//
// Implementation: TLDeleteImagePendingRequest
//

#undef LOG_TAG
#define LOG_TAG @"TLDeleteImagePendingRequest"

@implementation TLDeleteImagePendingRequest

-(nonnull instancetype)initWithImageId:(nonnull TLImageId *)imageId publicId:(nonnull NSUUID *)publicId withBlock:(nonnull TLImageIdConsumer)block {
    
    self = [super init];
    if (self) {
        _imageId = imageId;
        _publicId = publicId;
        _imageIdConsumer = block;
    }
    return self;
}

@end

//
// Implementation: TLImageService
//

#undef LOG_TAG
#define LOG_TAG @"TLImageService"

@implementation TLImageService

+ (void)initialize {
    
    IQ_COPY_IMAGE_SERIALIZER = [[TLCopyImageIQSerializer alloc] initWithSchema:COPY_IMAGE_SCHEMA_ID schemaVersion:2];
    IQ_CREATE_IMAGE_SERIALIZER = [[TLCreateImageIQSerializer alloc] initWithSchema:CREATE_IMAGE_SCHEMA_ID schemaVersion:2];
    IQ_DELETE_IMAGE_SERIALIZER = [[TLDeleteImageIQSerializer alloc] initWithSchema:DELETE_IMAGE_SCHEMA_ID schemaVersion:1];
    IQ_GET_IMAGE_SERIALIZER = [[TLGetImageIQSerializer alloc] initWithSchema:GET_IMAGE_SCHEMA_ID schemaVersion:1];
    IQ_PUT_IMAGE_SERIALIZER = [[TLPutImageIQSerializer alloc] initWithSchema:PUT_IMAGE_SCHEMA_ID schemaVersion:1];
    
    IQ_ON_COPY_IMAGE_SERIALIZER = [[TLOnCopyImageIQSerializer alloc] initWithSchema:ON_COPY_IMAGE_SCHEMA_ID schemaVersion:1];
    IQ_ON_CREATE_IMAGE_SERIALIZER = [[TLOnCreateImageIQSerializer alloc] initWithSchema:ON_CREATE_IMAGE_SCHEMA_ID schemaVersion:1];
    IQ_ON_DELETE_IMAGE_SERIALIZER = [[TLOnDeleteImageIQSerializer alloc] initWithSchema:ON_DELETE_IMAGE_SCHEMA_ID schemaVersion:1];
    IQ_ON_GET_IMAGE_SERIALIZER = [[TLOnGetImageIQSerializer alloc] initWithSchema:ON_GET_IMAGE_SCHEMA_ID schemaVersion:1];
    IQ_ON_PUT_IMAGE_SERIALIZER = [[TLOnPutImageIQSerializer alloc] initWithSchema:ON_PUT_IMAGE_SCHEMA_ID schemaVersion:1];
}

+ (nonnull NSString *)VERSION {
    
    return IMAGE_SERVICE_VERSION;
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    _serviceProvider = [[TLImageServiceProvider alloc] initWithService:self database:twinlife.databaseService];
    _pendingRequests = [[NSMutableDictionary alloc] init];
    _thumbnailCache = [[NSCache alloc] init];
    _imageCache = [[NSCache alloc] init];
    _serializerFactory = self.twinlife.serializerFactory;
    _maxImageSize = MAX_IMAGE_SIZE;
    _uploadChunkSize = DEFAULT_CHUNK_SIZE;
    _checkUpload = YES;
    _imageJob = [[TLImageJob alloc] initWithService:self];
    
    // Register the binary IQ handlers for the responses.
    [twinlife addPacketListener:IQ_ON_GET_IMAGE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onGetImageWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_CREATE_IMAGE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onCreateImageWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_COPY_IMAGE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onCopyImageWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_DELETE_IMAGE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onDeleteImageWithIQ:iq];
    }];
    [twinlife addPacketListener:IQ_ON_PUT_IMAGE_SERIALIZER listener:^(TLBinaryPacketIQ * iq) {
        [self onPutImageWithIQ:iq];
    }];
    
    return self;
}

#pragma mark - BaseServiceImpl

- (void)addDelegate:(nonnull id<TLBaseServiceDelegate>)delegate {
    
}

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLImageServiceConfiguration* imageServiceConfiguration = [[TLImageServiceConfiguration alloc] init];
    TLImageServiceConfiguration* serviceConfiguration = (TLImageServiceConfiguration *) baseServiceConfiguration;
    imageServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.serviceConfiguration = imageServiceConfiguration;
    self.serviceOn = imageServiceConfiguration.isServiceOn;
}

- (void)onSignIn {
    DDLogVerbose(@"%@ onSignIn", LOG_TAG);
    
    [super onSignIn];
    
    if (self.checkUpload) {
        @synchronized (self) {
            if (self.uploadJob) {
                [self.uploadJob cancel];
            }
            
            self.uploadJob = [[self.twinlife getJobService] scheduleWithJob:self.imageJob];
        }
    }
}

- (void)onSignOut {
    DDLogVerbose(@"%@ onSignOut", LOG_TAG);
    
    [super onSignOut];

    if (self.uploadJob) {
        [self.uploadJob cancel];
        self.uploadJob = nil;
    }
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);
    
    // We can safely delete objects in the cache.
    @synchronized (self) {
        [self.thumbnailCache removeAllObjects];
        [self.imageCache removeAllObjects];
    }
}

#pragma mark - TLImageService

- (nullable UIImage *)getCachedImageIfPresentWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind {
    DDLogVerbose(@"%@ getCachedImageIfPresentWithImageId: %@ kind: %d", LOG_TAG, imageId, kind);

    if (kind == TLImageServiceKindThumbnail) {
        // Look at the cache first if the image was already loaded.
        return [self.thumbnailCache objectForKey:imageId];

    } else {
        // Look at the cache first if the image was already loaded.
        return [self.imageCache objectForKey:imageId];
    }
}

- (nullable UIImage *)getCachedImageWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind)kind {
    DDLogVerbose(@"%@ getCachedImageWithImageId: %@ kind: %d", LOG_TAG, imageId, kind);
    
    if (kind == TLImageServiceKindThumbnail) {
        // Look at the cache first if the image was already loaded.
        UIImage *image = [self.thumbnailCache objectForKey:imageId];
        if (image) {
            return image;
        }
        
        // Look in the database if the image was already loaded.
        TLImageInfo *info = [self.serviceProvider loadImageWithImageId:imageId];
        if (info && info.data) {
            image = [UIImage imageWithData:info.data];
            if (image) {
                [self.thumbnailCache setObject:image forKey:imageId];
                return image;
            }
        }
        return nil;
        
    } else {
        // Look at the cache first if the image was already loaded.
        UIImage *image = [self.imageCache objectForKey:imageId];
        if (image) {
            return image;
        }
        
        // Look in the database if the image is known.
        TLImageInfo *info = [self.serviceProvider loadImageWithImageId:imageId];
        if (!info || info.status == TLImageStatusTypeMissing) {
            return nil;
        }
        
        NSUUID *uuid = info.copiedImageId ? info.copiedImageId : info.publicId;
        NSString *path = [self getCachedImagePathWithImageId:uuid kind:kind];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:path]) {
            return nil;
        }
        
        image = [UIImage imageWithContentsOfFile:path];
        if (image) {
            [self.imageCache setObject:image forKey:imageId];
        }
        return image;
    }
    return nil;
}

- (void)getImageWithImageId:(nonnull TLImageId *)imageId kind:(TLImageServiceKind) kind withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, UIImage *_Nullable image))block {
    DDLogVerbose(@"%@ getImageWithImageId: %@ kind: %d", LOG_TAG, imageId, kind);
    
    if (kind == TLImageServiceKindThumbnail) {
        // Look at the cache first if the image was already loaded.
        UIImage *image = [self.thumbnailCache objectForKey:imageId];
        if (image) {
            block(TLBaseServiceErrorCodeSuccess, image);
            return;
        }
        
        // Look in the database if the image was already loaded.
        TLImageInfo *info = [self.serviceProvider loadImageWithImageId:imageId];
        if (info && info.data) {
            image = [UIImage imageWithData:info.data];
            if (image) {
                [self.thumbnailCache setObject:image forKey:imageId];
                block(TLBaseServiceErrorCodeSuccess, image);
                return;
            }
            block(TLBaseServiceErrorCodeNoStorageSpace, image);
            return;
        }
        if (!info) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }
        
        // Get the thumbnail from the server.
        int64_t requestId = [TLTwinlife newRequestId];
        TLGetImageIQ *iq = [[TLGetImageIQ alloc] initWithSerializer:IQ_GET_IMAGE_SERIALIZER requestId:requestId imageId:info.publicId kind:kind];
        
        TLGetImagePendingRequest *pendingRequest = [[TLGetImagePendingRequest alloc] initWithImageId:imageId publicId:info.publicId kind:kind withBlock:block];
        @synchronized (self) {
            // Look for the pending requests and if we are already asking for this same image
            // don't make a new request to the server but keep it in the chain.
            for (NSNumber* key in self.pendingRequests) {
                TLImagePendingRequest *request = self.pendingRequests[key];
                if ([request isKindOfClass:[TLGetImagePendingRequest class]]) {
                    TLGetImagePendingRequest *imageRequest = (TLGetImagePendingRequest *)request;
                    if (imageRequest.kind == kind && [imageRequest.imageId isEqual:imageId]) {
                        pendingRequest.nextRequest = imageRequest.nextRequest;
                        imageRequest.nextRequest = pendingRequest;
                        return;
                    }
                }
            }
            self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
        }
        [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
        
    } else {
        // Look at the cache first if the image was already loaded.
        UIImage *image = [self.imageCache objectForKey:imageId];
        if (image) {
            block(TLBaseServiceErrorCodeSuccess, image);
            return;
        }
        
        // Look in the database if the image is known or we known it is missing.
        TLImageInfo *info = [self.serviceProvider loadImageWithImageId:imageId];
        if (!info || info.status == TLImageStatusTypeMissing) {
            block(TLBaseServiceErrorCodeItemNotFound, nil);
            return;
        }

        NSString *path;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSUUID *uuid = info.copiedImageId ? info.copiedImageId : info.publicId;
        if (info.status == TLImageStatusTypeLocale) {
            path = [self getLocalImagePathWithImageId:uuid];
            if (![fileManager fileExistsAtPath:path]) {
                // Old versions were saving local images in the Cache, check if the local image
                // was present in the cache and move it to the new location.
                NSString *oldPath = [self getCachedImagePathWithImageId:info.publicId kind:TLImageServiceKindNormal];
                if (![fileManager fileExistsAtPath:oldPath]) {
                    block(TLBaseServiceErrorCodeItemNotFound, nil);
                    return;
                }

                NSError *error;
                NSString *dirPath = [path stringByDeletingLastPathComponent];
                if (![fileManager fileExistsAtPath:dirPath]) {
                    [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
                }
                [fileManager moveItemAtPath:oldPath toPath:path error:&error];
                if (error) {
                    block(TLBaseServiceErrorCodeItemNotFound, nil);
                    return;
                }
            }
            image = [UIImage imageWithContentsOfFile:path];
            if (image) {
                [self.imageCache setObject:image forKey:imageId];
                block(TLBaseServiceErrorCodeSuccess, image);
                return;
            }
            block(TLBaseServiceErrorCodeItemNotFound, image);
            return;
        }
        path = [self getCachedImagePathWithImageId:uuid kind:kind];
        // If the large image does not exist, try to look for the normal image size.
        if (kind == TLImageServiceKindLarge && ![fileManager fileExistsAtPath:path]) {
            path = [self getCachedImagePathWithImageId:uuid kind:TLImageServiceKindNormal];
        }
        if ([fileManager fileExistsAtPath:path]) {
            image = [UIImage imageWithContentsOfFile:path];
            if (image) {
                [self.imageCache setObject:image forKey:imageId];
                block(TLBaseServiceErrorCodeSuccess, image);
                return;
            }
        }
        
        // Get the image from the server.
        int64_t requestId = [TLTwinlife newRequestId];
        TLGetImageIQ *iq = [[TLGetImageIQ alloc] initWithSerializer:IQ_GET_IMAGE_SERIALIZER requestId:requestId imageId:info.publicId kind:kind];
        
        TLGetImagePendingRequest *pendingRequest = [[TLGetImagePendingRequest alloc] initWithImageId:imageId publicId:info.publicId kind:kind withBlock:block];
        @synchronized (self) {
            // Look for the pending requests and if we are already asking for this same image
            // don't make a new request to the server but keep it in the chain.
            for (NSNumber* key in self.pendingRequests) {
                TLImagePendingRequest *request = self.pendingRequests[key];
                if ([request isKindOfClass:[TLGetImagePendingRequest class]]) {
                    TLGetImagePendingRequest *imageRequest = (TLGetImagePendingRequest *)request;
                    if (imageRequest.kind == kind && [imageRequest.imageId isEqual:imageId]) {
                        pendingRequest.nextRequest = imageRequest.nextRequest;
                        imageRequest.nextRequest = pendingRequest;
                        return;
                    }
                }
            }
            self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
        }
        [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    }
}

- (void)createImageWithImage:(nullable UIImage *)image thumbnail:(nonnull UIImage *)thumbnail withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLExportedImageId *_Nullable imageId))block {
    DDLogVerbose(@"%@ createImageWithImage: %@ thumbnail: %@", LOG_TAG, image, thumbnail);
    
    NSData *imageSha = nil;
    NSData *imageLargeSha = nil;
    NSString *normalFile = nil;
    NSString *largeFile = nil;
    int64_t total1Length = 0;
    int64_t total2Length = 0;
    
    if (image) {
        // Save the original image to a file with a reduction to 1280x1280 if necessary.
        normalFile = [self getCachedImagePathWithImageId:[NSUUID UUID] kind:TLImageServiceKindNormal];
        if ([self copyImageWithImage:image destinationPath:normalFile maxWidth:TL_NORMAL_IMAGE_WIDTH maxHeight:TL_NORMAL_IMAGE_HEIGHT sha256:&imageSha length:&total1Length]) {
            
            // Image is larger, save the original to another file.
            largeFile = [self getCachedImagePathWithImageId:[NSUUID UUID] kind:TLImageServiceKindLarge];
            [self copyImageWithImage:image destinationPath:largeFile maxWidth:TL_LARGE_IMAGE_WIDTH maxHeight:TL_LARGE_IMAGE_HEIGHT sha256:&imageLargeSha length:&total2Length];
        }
    }
    
    // Get the image thumbnail content.
    NSData *thumbnailData = [self getImageDataWithImage:thumbnail];
    if (!thumbnailData) {
        block(TLBaseServiceErrorCodeNoStorageSpace, nil);
        return;
    }
    
    NSData *thumbnailSha = [self computeSHA256:thumbnailData];
    
    // Create the image on the server.
    int64_t requestId = [TLTwinlife newRequestId];
    TLCreateImageIQ *iq = [[TLCreateImageIQ alloc] initWithSerializer:IQ_CREATE_IMAGE_SERIALIZER requestId:requestId thumbnailSha:thumbnailSha imageSha:imageSha imageLargeSha:imageLargeSha thumbnail:thumbnailData];
    
    TLImagePendingRequest *pendingRequest = [[TLCreateImagePendingRequest alloc] initWithPath:normalFile imageLargePath:largeFile imageData:thumbnailData thumbnailSha:thumbnailSha imageSha:imageSha imageLargeSha:imageLargeSha total1Length:total1Length total2Length:total2Length withBlock:block];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)createLocalImageWithImage:(nullable UIImage *)image thumbnail:(nonnull UIImage *)thumbnail withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLExportedImageId *_Nullable imageId))block {
    DDLogVerbose(@"%@ createLocalImageWithImage: %@ thumbnail: %@", LOG_TAG, image, thumbnail);
    
    NSData *imageData = [self getImageDataWithImage:thumbnail];
    NSData *imageSha = [NSData data];
    TLExportedImageId *imageId = [self.serviceProvider createImageWithImageId:[NSUUID UUID] locale:YES thumbnail:imageData imageShas:imageSha remain1Size:0 remain2Size:0];
    if (!imageId) {
        block(TLBaseServiceErrorCodeNoStorageSpace, nil);
    } else {
        if (image) {
            int64_t length;
            NSString *path = [self getLocalImagePathWithImageId:imageId.publicId];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *dirPath = [path stringByDeletingLastPathComponent];
            if (![fileManager fileExistsAtPath:dirPath]) {
                [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
            }
            [self copyImageWithImage:image destinationPath:path maxWidth:TL_LOCAL_IMAGE_WIDTH maxHeight:TL_LOCAL_IMAGE_HEIGHT sha256:&imageSha length:&length];
        }
        block(TLBaseServiceErrorCodeSuccess, imageId);
    }
}

- (void)copyImageWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLExportedImageId *_Nullable imageId))block {
    DDLogVerbose(@"%@ copyImageWithImageId: %@", LOG_TAG, imageId);
    
    // We must know the original image Id (it can be different than imageId).
    TLImageInfo *info = [self.serviceProvider loadImageWithImageId:imageId];
    if (!info) {
        block(TLBaseServiceErrorCodeItemNotFound, nil);
        return;
    }

    // This is a local image and the server does not know it, create an image with the bitmap.
    if (info.status == TLImageStatusTypeLocale) {
        NSData *thumbnailSha = [self computeSHA256:info.data];
        int64_t requestId = [TLTwinlife newRequestId];
            
        TLCreateImageIQ *iq = [[TLCreateImageIQ alloc] initWithSerializer:IQ_CREATE_IMAGE_SERIALIZER requestId:requestId thumbnailSha:thumbnailSha imageSha:nil imageLargeSha:nil thumbnail:info.data];
            
        TLImagePendingRequest *pendingRequest = [[TLCreateImagePendingRequest alloc] initWithPath:nil imageLargePath:nil imageData:info.data thumbnailSha:thumbnailSha imageSha:nil imageLargeSha:nil total1Length:0 total2Length:0 withBlock:block];
        @synchronized (self) {
            self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
        }
        [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
        return;
    }
    
    // Now we can ask the server to copy the specified image Id.
    int64_t requestId = [TLTwinlife newRequestId];
    TLCopyImageIQ *iq = [[TLCopyImageIQ alloc] initWithSerializer:IQ_COPY_IMAGE_SERIALIZER requestId:requestId imageId:info.publicId];
    
    TLImagePendingRequest *pendingRequest = [[TLCopyImagePendingRequest alloc] initWithImageId:imageId withBlock:block];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)deleteImageWithImageId:(nonnull TLImageId *)imageId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLImageId *_Nullable imageId))block {
    DDLogVerbose(@"%@ deleteImageWithImageId: %@", LOG_TAG, imageId);
    
    // Remove local images from the database.
    TLImageDeleteInfo *info = [self.serviceProvider deleteImageWithImageId:imageId localOnly:YES];
    if (!info) {
        block(TLBaseServiceErrorCodeItemNotFound, nil);
        return;
    }

    if (info.status == TLImageDeleteStatusTypeNone) {
        // We must keep the image data because a copy exist.
        [self.thumbnailCache removeObjectForKey:imageId];
        [self.imageCache removeObjectForKey:imageId];
        
        block(TLBaseServiceErrorCodeSuccess, imageId);
        return;
    }
    
    if (info.status == TLImageDeleteStatusTypeLocal) {
        // No copy exist, we can remove the image.
        [self removeCachedImagePathWithImageId:info.publicId];
        
        [self.thumbnailCache removeObjectForKey:imageId];
        [self.imageCache removeObjectForKey:imageId];
        
        block(TLBaseServiceErrorCodeSuccess, imageId);
        return;
    }
    
    // Invalidate the image on the server.
    int64_t requestId = [TLTwinlife newRequestId];
    TLDeleteImageIQ *iq = [[TLDeleteImageIQ alloc] initWithSerializer:IQ_DELETE_IMAGE_SERIALIZER requestId:requestId imageId:info.publicId];
    
    TLImagePendingRequest *pendingRequest = [[TLDeleteImagePendingRequest alloc] initWithImageId:imageId publicId:info.publicId withBlock:block];
    @synchronized (self) {
        self.pendingRequests[[NSNumber numberWithLongLong:requestId]] = pendingRequest;
    }
    [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
}

- (void)evictImageWithImageId:(nonnull TLImageId *)imageId {
    DDLogVerbose(@"%@ evictImageWithImageId: %@", LOG_TAG, imageId);
    
    // Remove local images from the database.
    NSUUID *publicId = [self.serviceProvider evictImageWithImageId:imageId];
    if (publicId) {
        [self removeCachedImagePathWithImageId:publicId];
    }

    [self.thumbnailCache removeObjectForKey:imageId];
    [self.imageCache removeObjectForKey:imageId];
}

- (nonnull NSMutableDictionary<TLImageId *, TLImageId *> *)listCopiedImages {
    DDLogVerbose(@"%@ listCopiedImages", LOG_TAG);

    return [self.serviceProvider listCopiedImages];
}

- (nullable TLExportedImageId *)publicWithImageId:(nonnull TLImageId *)imageId {
    DDLogVerbose(@"%@ publicWithImageId: %@", LOG_TAG, imageId);

    return [self.serviceProvider publicWithImageId:imageId];
}

- (nullable TLExportedImageId *)imageWithPublicId:(nonnull NSUUID *)publicId {
    DDLogVerbose(@"%@ imageWithPublicId: %@", LOG_TAG, publicId);

    return [self.serviceProvider imageWithPublicId:publicId];
}

#pragma mark - TLImageService upcalls

- (void)notifyDeletedWithImageId:(nonnull TLImageId *)imageId publicId:(nonnull NSUUID *)publicId {
    DDLogVerbose(@"%@ notifyDeletedWithImageId: %@ publicId: %@", LOG_TAG, imageId, publicId);

    dispatch_async([self.twinlife twinlifeQueue], ^{
        [self removeCachedImagePathWithImageId:publicId];

        // Cleanup the cache.
        [self.thumbnailCache removeObjectForKey:imageId];
        [self.imageCache removeObjectForKey:imageId];
    });
}

#pragma mark - TLImageService upload

- (void)moveFileWithPath:(nonnull NSString *)path sourcePath:(nonnull NSString *)sourcePath {
    DDLogVerbose(@"%@ moveFileWithPath: %@ sourcePath: %@", LOG_TAG, path, sourcePath);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    if (![fileManager fileExistsAtPath:sourcePath]) {
        return;
    }
    
    if (![fileManager moveItemAtPath:sourcePath toPath:path error:&error]) {
        DDLogError(@"%@ uploadImageWithImageId: cannot move image: %@", LOG_TAG, error);
        [fileManager removeItemAtPath:path error:&error];
        return;
    }
}

- (void)uploadImageWithInfo:(nonnull TLUploadInfo *)uploadInfo path:(nonnull NSString *)path kind:(TLImageServiceKind)kind serverChunkSize:(int64_t)serverChunkSize {
    DDLogVerbose(@"%@ uploadImageWithInfo: %@ path: %@ kind: %d chunkSize: %lld", LOG_TAG, uploadInfo, path, kind, serverChunkSize);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    int64_t length = [[[fileManager attributesOfItemAtPath:path error:nil] objectForKey:NSFileSize] longLongValue];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fileHandle) {
        [self.serviceProvider saveRemainUploadSizeWithImageId:uploadInfo.imageId kind:kind remainSize:0];
        return;
    }
    
    int64_t remainSize = [self.serviceProvider getUploadRemainSizeWithImageId:uploadInfo.imageId kind:kind];
    
    // Upload the image on the server.
    int64_t requestId = [TLTwinlife newRequestId];
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    
    TLUploadImagePendingRequest *uploadRequest = [[TLUploadImagePendingRequest alloc] initWithImageId:uploadInfo.imageId kind:kind totalLength:length];
    @synchronized (self) {
        if (self.uploadRequest) {
            return;
        }
        self.pendingRequests[lRequestId] = uploadRequest;
        self.uploadRequest = uploadRequest;
    }
    
    // Send the image in chunks, we don't wait for server to acknowledge the upload.
    int64_t chunkSize = [self computeChunkSize:length serverChunkSize:serverChunkSize];
    int64_t offset = 0;
    if (remainSize >= length) {
        offset = 0;
    } else {
        offset = length - remainSize;
    }
    if (offset > 0) {
        [fileHandle seekToFileOffset:(int)offset];
    }
    while (offset < length) {
        int64_t size = length - offset;
        if (size > chunkSize) {
            size = chunkSize;
        }
        
        NSData *data = [fileHandle readDataOfLength:(int)size];
        TLPutImageIQ *iq = [[TLPutImageIQ alloc] initWithSerializer:IQ_PUT_IMAGE_SERIALIZER requestId:requestId imageId:uploadInfo.imageId.publicId kind:kind offset:offset totalSize:length imageData:data];
        BOOL queued;
        @synchronized (self) {
            if (uploadRequest.sendCount >= MAX_SEND_IMAGE_IQ) {
                [uploadRequest.queue addObject:iq];
                queued = YES;
            } else {
                uploadRequest.sendCount++;
                queued = NO;
            }
        }
        if (!queued) {
            [self sendBinaryIQ:iq factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
        }
        offset += size;
    }
    [fileHandle closeFile];
}

#pragma mark - TLImageService

- (void)onGetImageWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onGetImageWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnGetImageIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    TLOnGetImageIQ *onGetImageIQ = (TLOnGetImageIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLGetImagePendingRequest *request;
    @synchronized (self) {
        request = (TLGetImagePendingRequest *)self.pendingRequests[lRequestId];
        if (onGetImageIQ.imageSha) {
            [self.pendingRequests removeObjectForKey:lRequestId];
        }
    }
    if (!request) {
        return;
    }

    // Don't accept an image that is too big for us.
    if (onGetImageIQ.totalSize > self.maxImageSize) {
        [request dispatchWithErrorCode:TLBaseServiceErrorCodeNoStorageSpace image:nil];
        return;
    }
    
    // We can receive the image in several chunks, the last one contains the image signature.
    NSData *imageData;
    if (!request.imageReceived && onGetImageIQ.imageSha) {
        // Only one chunk.
        imageData = onGetImageIQ.imageData;
        NSData *sha256 = [self computeSHA256:imageData];
        if (![onGetImageIQ.imageSha isEqualToData:sha256]) {
            [request dispatchWithErrorCode:TLBaseServiceErrorCodeNoStorageSpace image:nil];
            return;
        }
    } else {

        // We received the first chunk, allocate the data buffer.
        if (!request.imageReceived) {
            request.imageReceived = [[NSMutableData alloc] initWithCapacity:(int)onGetImageIQ.totalSize];
            [request.imageReceived appendData:onGetImageIQ.imageData];

            // Restart timer for next chunk.
            [self packetTimeout:iq.requestId timeout:DEFAULT_REQUEST_TIMEOUT isBinary:YES];
            return;
        }
        
        // Append until we get the last chunk.
        [request.imageReceived appendData:onGetImageIQ.imageData];
        if (!onGetImageIQ.imageSha) {
            // Restart timer for next chunk.
            [self packetTimeout:iq.requestId timeout:DEFAULT_REQUEST_TIMEOUT isBinary:YES];
            return;
        }
        
        NSData *sha256 = [self computeSHA256:request.imageReceived];
        if (![onGetImageIQ.imageSha isEqualToData:sha256]) {
            [request dispatchWithErrorCode:TLBaseServiceErrorCodeNoStorageSpace image:nil];
            return;
        }
        imageData = request.imageReceived;
    }
    
    // Save the image either in the database or in the cache directory.
    if (request.kind == TLImageServiceKindThumbnail) {
        [self.serviceProvider importImageWithImageId:request.imageId status:TLImageStatusTypeRemote thumbnail:imageData imageSha:onGetImageIQ.imageSha];
    } else {
        NSError *error;
        NSString *path = [self getCachedImagePathWithImageId:request.publicId kind:request.kind];
        NSURL *url = [NSURL fileURLWithPath:path];
        
        // Use atomic writing because getImageWithImageId() may try to access the file.
        // Use NSDataWritingFileProtectionComplete to protect the file and allow its access only
        // when the user has unlocked the device.  It can't be accessed if we run in background!
        if (![imageData writeToURL:url options:NSDataWritingAtomic+NSDataWritingFileProtectionComplete error:&error]) {
            [request dispatchWithErrorCode:TLBaseServiceErrorCodeNoStorageSpace image:nil];
            return;
        }
    }
    
    // Create the image with the data.
    UIImage *image = [UIImage imageWithData:imageData];
    if (!image) {
        [request dispatchWithErrorCode:TLBaseServiceErrorCodeNoStorageSpace image:nil];
        return;
    }
    if (request.kind == TLImageServiceKindThumbnail) {
        [self.thumbnailCache setObject:image forKey:request.imageId];
    } else {
        [self.imageCache setObject:image forKey:request.imageId];
    }

    [request dispatchWithErrorCode:TLBaseServiceErrorCodeSuccess image:image];
}

- (void)onCreateImageWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCreateImageWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnCreateImageIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    // Get the pending request or terminate.
    TLOnCreateImageIQ *onCreateImageIQ = (TLOnCreateImageIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLCreateImagePendingRequest *pendingRequest;
    @synchronized (self) {
        pendingRequest = (TLCreateImagePendingRequest *)self.pendingRequests[lRequestId];
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    if (!pendingRequest) {
        return;
    }
    
    TLExportedImageId *imageId = [self.serviceProvider createImageWithImageId:onCreateImageIQ.imageId locale:NO thumbnail:pendingRequest.imageData imageShas:pendingRequest.imageShas remain1Size:pendingRequest.total1Length remain2Size:pendingRequest.total2Length];
    
    BOOL needUpload = NO;
    
    // Save the normal image to the cache.
    if (pendingRequest.imagePath) {
        NSString *targetPath = [self getCachedImagePathWithImageId:onCreateImageIQ.imageId kind:TLImageServiceKindNormal];
        [self moveFileWithPath:targetPath sourcePath:pendingRequest.imagePath];
        needUpload = YES;
    }
    
    // Save the large image to the cache.
    if (pendingRequest.imageLargePath) {
        NSString *targetPath = [self getCachedImagePathWithImageId:onCreateImageIQ.imageId kind:TLImageServiceKindLarge];
        [self moveFileWithPath:targetPath sourcePath:pendingRequest.imageLargePath];
        needUpload = YES;
    }
    
    if (needUpload) {
        @synchronized (self) {
            self.uploadChunkSize = onCreateImageIQ.chunkSize;
        }
        [self backgroundUpload];
    }
    pendingRequest.imageIdConsumer(TLBaseServiceErrorCodeSuccess, imageId);
}

- (void)onCopyImageWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onCopyImageWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnCopyImageIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    // Get the pending request or terminate.
    TLOnCopyImageIQ *onCopyImageIQ = (TLOnCopyImageIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLCopyImagePendingRequest *pendingRequest;
    @synchronized (self) {
        pendingRequest = (TLCopyImagePendingRequest *)self.pendingRequests[lRequestId];
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    if (!pendingRequest) {
        return;
    }
    
    TLExportedImageId *imageId = [self.serviceProvider copyImageWithImageId:onCopyImageIQ.imageId copiedFromImageId:pendingRequest.imageId];
    pendingRequest.imageIdConsumer(imageId ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeNoStorageSpace, imageId);
}

- (void)onDeleteImageWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onDeleteImageWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnDeleteImageIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    // Get the pending request or terminate.
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLDeleteImagePendingRequest *pendingRequest;
    @synchronized (self) {
        pendingRequest = (TLDeleteImagePendingRequest *)self.pendingRequests[lRequestId];
        [self.pendingRequests removeObjectForKey:lRequestId];
    }
    if (!pendingRequest) {
        return;
    }
    
    // Remove from the database.
    TLImageDeleteInfo *info = [self.serviceProvider deleteImageWithImageId:pendingRequest.imageId localOnly:NO];
    if (info && info.status == TLImageDeleteStatusTypeLocalRemote) {
        [self removeCachedImagePathWithImageId:pendingRequest.publicId];
    }
    
    // Cleanup the cache.
    [self.thumbnailCache removeObjectForKey:pendingRequest.imageId];
    [self.imageCache removeObjectForKey:pendingRequest.imageId];
    
    pendingRequest.imageIdConsumer(TLBaseServiceErrorCodeSuccess, pendingRequest.imageId);
}

- (void)onPutImageWithIQ:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ onPutImageWithIQ: %@", LOG_TAG, iq);
    
    if (![iq isKindOfClass:[TLOnPutImageIQ class]]) {
        return;
    }
    
    [self receivedBinaryIQ:iq];
    
    // Get the pending request or terminate.
    TLOnPutImageIQ *onPutImageIQ = (TLOnPutImageIQ *)iq;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:iq.requestId];
    TLUploadImagePendingRequest *uploadRequest;
    TLPutImageIQ *nextIQ = nil;
    @synchronized (self) {
        if (onPutImageIQ.status != TLPutImageStatusTypeIncomplete) {
            [self.pendingRequests removeObjectForKey:lRequestId];
            self.uploadRequest = nil;
        } else {
            uploadRequest = self.uploadRequest;
            if (uploadRequest) {
                if (uploadRequest.queue.count > 0 && uploadRequest.sendCount <= MAX_SEND_IMAGE_IQ) {
                    nextIQ = uploadRequest.queue.firstObject;
                    [uploadRequest.queue removeObjectAtIndex:0];
                } else {
                    uploadRequest.sendCount--;
                }
            }
        }
    }
    if (!uploadRequest) {
        return;
    }
    
    // Record what remains for the upload so that we can recover a partial upload.
    if (onPutImageIQ.status == TLPutImageStatusTypeError) {
        [self.serviceProvider saveRemainUploadSizeWithImageId:uploadRequest.imageId kind:uploadRequest.kind remainSize:uploadRequest.totalLength];
    } else {
        [self.serviceProvider saveRemainUploadSizeWithImageId:uploadRequest.imageId kind:uploadRequest.kind remainSize:uploadRequest.totalLength - onPutImageIQ.offset];
    }
    if (nextIQ) {
        [self sendBinaryIQ:nextIQ factory:self.serializerFactory timeout:DEFAULT_REQUEST_TIMEOUT];
    } else if (onPutImageIQ.status != TLPutImageStatusTypeIncomplete) {
        [self backgroundUpload];
    }
}

- (void)onErrorWithErrorPacket:(nonnull TLBinaryErrorPacketIQ *)errorPacketIQ {
    DDLogVerbose(@"%@ onErrorWithErrorPacket: %@", LOG_TAG, errorPacketIQ);

    int64_t requestId = errorPacketIQ.requestId;
    TLBaseServiceErrorCode errorCode = errorPacketIQ.errorCode;
    NSNumber *lRequestId = [NSNumber numberWithLongLong:requestId];
    TLImagePendingRequest *request;

    [self receivedBinaryIQ:errorPacketIQ];
    @synchronized (self) {
        request = self.pendingRequests[lRequestId];
        if (!request) {
            return;
        }

        [self.pendingRequests removeObjectForKey:lRequestId];
        if (request == self.uploadRequest) {
            self.uploadRequest = nil;
        }
    }
    if ([request isKindOfClass:[TLGetImagePendingRequest class]]) {
        TLGetImagePendingRequest *imagePendingRequest = (TLGetImagePendingRequest *)request;
        [imagePendingRequest dispatchWithErrorCode:errorCode image:nil];

    } else if ([request isKindOfClass:[TLCopyImagePendingRequest class]]) {
        ((TLCopyImagePendingRequest *) request).imageIdConsumer(errorCode, nil);
            
    } else if ([request isKindOfClass:[TLDeleteImagePendingRequest class]]) {
        ((TLDeleteImagePendingRequest *) request).imageIdConsumer(errorCode, nil);
            
    } else if ([request isKindOfClass:[TLCreateImagePendingRequest class]]) {
        ((TLCreateImagePendingRequest *) request).imageIdConsumer(errorCode, nil);
    }
}

- (void)backgroundUpload {
    DDLogVerbose(@"%@ backgroundUpload", LOG_TAG);
    
    TLUploadInfo *uploadInfo = [self.serviceProvider nextUpload];
    @synchronized (self) {
        self.uploadJob = nil;
        self.checkUpload = uploadInfo != nil;
        if (!uploadInfo || self.uploadRequest) {
            return;
        }
    }
    
    if (uploadInfo.remainNormalImage) {
        NSString *targetPath = [self getCachedImagePathWithImageId:uploadInfo.imageId.publicId kind:TLImageServiceKindNormal];
        [self uploadImageWithInfo:uploadInfo path:targetPath kind:TLImageServiceKindNormal serverChunkSize:self.uploadChunkSize];
    }
    
    if (uploadInfo.remainLargeImage) {
        NSString *targetPath = [self getCachedImagePathWithImageId:uploadInfo.imageId.publicId kind:TLImageServiceKindLarge];
        [self uploadImageWithInfo:uploadInfo path:targetPath kind:TLImageServiceKindLarge serverChunkSize:self.uploadChunkSize];
    }
}

- (NSData *)computeSHA256:(NSData *)data {
    
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    
    if (CC_SHA256([data bytes], (int) [data length], hash)) {
        NSData *sha256 = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
        return sha256;
    }
    
    return nil;
}

- (nullable NSData *)computeSHA256WithPath:(nonnull NSString *)path {
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fileHandle) {
        return nil;
    }
    
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    while (YES) {
        NSData *data = [fileHandle readDataOfLength:DEFAULT_CHUNK_SIZE];
        if (!data || [data length] == 0) {
            break;
        }
        CC_SHA256_Update(&ctx, [data bytes], (int)[data length]);
    }
    
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash, &ctx);
    [fileHandle closeFile];
    
    NSData *sha256 = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
    return sha256;
}

- (int64_t)computeChunkSize:(int64_t)total serverChunkSize:(int64_t)serverChunkSize {
    
    // Todo: look at the session to choose a specific chunk for this device/network connection.
    if (serverChunkSize <= 0) {
        serverChunkSize = DEFAULT_CHUNK_SIZE;
    }
    
    int64_t defaultChunkCount = (total + serverChunkSize - 1) / serverChunkSize;
    
    // Make each chunk the same size but aligned on 4 bytes upper boundary.
    int64_t chunkSize = 1 + total / (4 * defaultChunkCount);
    return 4 * chunkSize;
}

- (nonnull NSString *)getCachedImagePathWithImageId:(nonnull NSUUID *)imageId kind:(TLImageServiceKind)kind {
    DDLogVerbose(@"%@ getCachedImagePathWithImageId: %@ kind: %d", LOG_TAG, imageId, kind);
    
    NSArray *list = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    
    NSString *cacheDirectory = [list objectAtIndex:0];
    NSString *basename;
    switch (kind) {
        case TLImageServiceKindNormal:
            basename = [NSString stringWithFormat:@"%@-normal.png", imageId.UUIDString];
            break;
            
        case TLImageServiceKindThumbnail:
            basename = [NSString stringWithFormat:@"%@-thumb.png", imageId.UUIDString];
            break;
            
        case TLImageServiceKindLarge:
            basename = [NSString stringWithFormat:@"%@-large.png", imageId.UUIDString];
            break;
    }
    
    return [cacheDirectory stringByAppendingPathComponent:basename];
}

- (nonnull NSString *)getLocalImagePathWithImageId:(nonnull NSUUID *)imageId {
    DDLogVerbose(@"%@ getLocalImagePathWithImageId: %@", LOG_TAG, imageId);
    
    // Note: we must use the same format as on Android: UUID in lower case with .img extension.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *dirPath = [TLTwinlife getAppGroupPath:fileManager path:@"Pictures"];
    return [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.img", [imageId toString]]];
}

- (void)removeCachedImagePathWithImageId:(nonnull NSUUID *)imageId {
    DDLogVerbose(@"%@ removeCachedImagePathWithImageId: %@", LOG_TAG, imageId);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSString *path;
    
    path = [self getCachedImagePathWithImageId:imageId kind:TLImageServiceKindNormal];
    [fileManager removeItemAtPath:path error:&error];
    
    path = [self getCachedImagePathWithImageId:imageId kind:TLImageServiceKindLarge];
    [fileManager removeItemAtPath:path error:&error];
}

- (nullable NSData *)getImageDataWithImage:(nonnull UIImage *)image {
    DDLogVerbose(@"%@ getImageDataWithImage: %@", LOG_TAG, image);
    
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image.CGImage);
    if (alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaLast || alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast) {
        NSData *data = UIImagePNGRepresentation(image);
        if (data && data.length < self.maxImageSize) {
            // Return the PNG image if it meets the size constraint.
            return data;
        }
        
        // Fallback to JPEG (dropping the transparency).
    }
    return UIImageJPEGRepresentation(image, IMAGE_JPEG_QUALITY);
}

- (BOOL)copyImageWithImage:(nonnull UIImage *)image destinationPath:(nonnull NSString *)destinationPath maxWidth:(int)maxWidth maxHeight:(int)maxHeight sha256:(NSData **)sha256 length:(int64_t *)length {
    
    int width = image.size.width;
    int height = image.size.height;
    BOOL scaled = (width > maxWidth || height > maxHeight);
    NSData *data;
    
    if (scaled) {
        CGSize size = [image size];
        CGSize targetSize = CGSizeMake(maxWidth, maxHeight);
        CGFloat targetWidth = targetSize.width;
        CGFloat targetHeight = targetSize.height;
        CGFloat scaledWidth = targetWidth;
        CGFloat scaledHeight = targetHeight;
        CGPoint thumbnailPoint = CGPointMake(0., 0.);
        
        if (!CGSizeEqualToSize(size, targetSize)) {
            CGFloat width = image.size.width;
            CGFloat height = image.size.height;
            CGFloat widthFactor = targetWidth / width;
            CGFloat heightFactor = targetHeight / height;
            CGFloat scaleFactor = MAX(widthFactor, heightFactor);
            scaledWidth = width * scaleFactor;
            scaledHeight = height * scaleFactor;
            if (widthFactor > heightFactor) {
                thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
            } else {
                if (widthFactor < heightFactor) {
                    thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
                }
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.); // crop
        
        CGRect thumbnailRect = CGRectZero;
        thumbnailRect.origin = thumbnailPoint;
        thumbnailRect.size.width  = scaledWidth;
        thumbnailRect.size.height = scaledHeight;
        
        [image drawInRect:thumbnailRect];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        
        // Force JPEG because for some reason, the image uses kCGImageAlphaPremultipliedFirst.
        data = UIImageJPEGRepresentation(image, IMAGE_JPEG_QUALITY);
        if (!image) {
            [self.twinlife assertionWithAssertPoint:[TLImageAssertPoint READ_IMAGE], [TLAssertValue initWithLength:data.length], nil];
        }
    } else {
        data = [self getImageDataWithImage:image];
    }
    
    // Verify there is some image data.
    if (!data) {
        [self.twinlife assertionWithAssertPoint:[TLImageAssertPoint COPY_IMAGE], [TLAssertValue initWithLength:data.length], nil];

        *sha256 = nil;
        *length = 0;
        return NO;
    }
    
    // Verify it does not exceed the maximum.
    if (data.length > self.maxImageSize) {
        [self.twinlife assertionWithAssertPoint:[TLImageAssertPoint COPY_IMAGE], [TLAssertValue initWithLength:data.length], nil];
        
        *sha256 = nil;
        *length = 0;
        return NO;
    }
    
    NSURL *url = [NSURL fileURLWithPath:destinationPath];
    NSError *error;
    
    // Save the image
    if (![data writeToURL:url options:NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:&error])  {
        
        DDLogError(@"%@: Cannot save image: %@", LOG_TAG, error);
        
        *sha256 = nil;
        return NO;
    }
    *sha256 = [self computeSHA256:data];
    *length = data.length;
    return scaled;
}

@end

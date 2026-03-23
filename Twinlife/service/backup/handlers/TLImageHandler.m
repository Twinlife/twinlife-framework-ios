/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLImageHandler.h"
#import "TLTwinlifeImpl.h"
#import "TLImageServiceImpl.h"
#import "TLImageServiceProvider.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define RESTORE_DIR @"restore"

@interface TLImageHandler ()

+ (TLImageStatusType)codeToStatusWithCode:(int)code;
+ (int)statusToCodeWithStatus:(TLImageStatusType)status;

@property (nonnull, readonly) TLTwinlife *twinlife;

@end

@interface TLImageRestorerV1 : TLRestorer<TLImageInfo *>

@property (nonnull, readonly) TLTwinlife *twinlife;

- (nonnull instancetype) initWithTwinlife:(nonnull TLTwinlife *)twinlife;

@end

#undef LOG_TAG
#define LOG_TAG @"TLImageRestorerV1"

@implementation TLImageRestorerV1

+ (nonnull NSNumber *) VERSION {
    return @1;
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    self = [super init];
    
    if (self) {
        _twinlife = twinlife;
    
    }
    
    return self;
}

- (nullable TLImageInfo *) restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");

    NSUUID *imageId = [decoder readUUID];
    TLImageStatusType type = [TLImageHandler codeToStatusWithCode:[decoder readInt]];
    NSData *thumbnailData = [decoder readOptionalData];
    NSData *normalImageData = [decoder readOptionalData];
    
    TLExportedImageId *exportedImageId;
    
    if (inPlace) {
        exportedImageId = [self.twinlife.imageService imageWithPublicId:imageId];
        
        if (exportedImageId) {
            DDLogVerbose(@"%@ In place restore: image already exists: %@", LOG_TAG, imageId.UUIDString);
            return [self.twinlife.imageService getImageInfoWithImageId:exportedImageId];
        }
    }
    
    UIImage *thumbnail = nil;
    
    if (thumbnailData) {
        thumbnail = [[UIImage alloc] initWithData:thumbnailData];
    }
    
    UIImage *normalImage = nil;
    
    if (normalImageData) {
        normalImage = [[UIImage alloc] initWithData:normalImageData];
    }
    
    exportedImageId = [self.twinlife.imageService restoreLocalImageWithImageId:imageId locale:(type == TLImageStatusTypeLocale) image:normalImage thumbnail:thumbnail];
    
    if (!exportedImageId) {
        DDLogError(@"%@ could not restore local image %@", LOG_TAG, imageId.UUIDString);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    TLImageInfo *imageInfo = [self.twinlife.imageService getImageInfoWithImageId:[[TLImageId alloc] initWithLocalId:exportedImageId.localId]];
    
    if (!imageInfo) {
        DDLogError(@"%@ no ImageInfo found in DB for image %@", LOG_TAG, imageId.UUIDString);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    DDLogVerbose(@"%@ Restored image %@", LOG_TAG, imageId.UUIDString);
    
    return imageInfo;
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);
    
    NSUUID *imageId = [decoder readUUID];
    TLImageStatusType type = [TLImageHandler codeToStatusWithCode:[decoder readInt]];
    NSData *thumbnailData = [decoder readOptionalData];
    [decoder readOptionalData]; //normalImageData

    TLExportedImageId *exportedImageId;
    
    exportedImageId = [self.twinlife.imageService imageWithPublicId:imageId];

    if (exportedImageId) {
        TLImageInfo *imageInfo = [self.twinlife.imageService getImageInfoWithImageId:exportedImageId];
        if (imageInfo) {
            BOOL modified = imageInfo.status != type || ![imageInfo.data isEqualToData:thumbnailData];
            
            return [[TLBackupVerifyResultPresent alloc] initWithObject:imageInfo modified:modified];
        }
    }
    
    return [[TLBackupVerifyResultAbsent alloc] initWithIdentifier:imageId schemaId:nil type:TLImageInfo.class];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLImageHandler"

@implementation TLImageHandler


- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    
    self = [super initWithRestorers:@{
        TLImageRestorerV1.VERSION : [[TLImageRestorerV1 alloc] initWithTwinlife:twinlife]
    }];
    
    if (self) {
        _twinlife = twinlife;
    }
    
    return self;
}

- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogVerbose(@"%@ backupWithBinaryEncoder: %@", LOG_TAG, encoder);

    TLImageService *imageService = self.twinlife.getImageService;
    
    for (TLImageId *imageId in [imageService listLocalImages]) {
        TLImageInfo *imageInfo = [imageService getImageInfoWithImageId:imageId];
        
        if (!imageInfo || !imageInfo.publicId) {
            DDLogWarn(@"%@ Invalid imageInfo for imageId %@", LOG_TAG, imageId);
            continue;
        }
        
        NSData *imageData = [imageService getLocalImageDataWithImageId:imageId];
        
        [encoder writeUUID:TL_IMAGE_BACKUP_SCHEMA_ID];
        [encoder writeInt:TL_IMAGE_BACKUP_SCHEMA_VERSION];
        [encoder writeUUID:imageInfo.publicId];
        [encoder writeInt:[TLImageHandler statusToCodeWithStatus:imageInfo.status]];
        [encoder writeOptionalData:imageInfo.data];
        [encoder writeOptionalData:imageData];
        
        DDLogVerbose(@"%@ Backed up image %@", LOG_TAG, imageInfo.publicId.UUIDString);
    }
}

+ (TLImageStatusType)codeToStatusWithCode:(int)code {
    switch (code) {
        case 0: return TLImageStatusTypeLocale;
        case 1: return TLImageStatusTypeOwner;
        case 2: return TLImageStatusTypeDeleted;
        case 3: return TLImageStatusTypeRemote;
        case 4: return TLImageStatusTypeMissing;
        case 5: return TLImageStatusTypeNeedFetch;
        default:
            return TLImageStatusTypeInvalid;
    }
}

+ (int)statusToCodeWithStatus:(TLImageStatusType)status {
    switch (status) {
        case TLImageStatusTypeLocale:    return 0;
        case TLImageStatusTypeOwner:     return 1;
        case TLImageStatusTypeDeleted:   return 2;
        case TLImageStatusTypeRemote:    return 3;
        case TLImageStatusTypeMissing:   return 4;
        case TLImageStatusTypeNeedFetch: return 5;
        default:
            return -1;
    }
}



@end

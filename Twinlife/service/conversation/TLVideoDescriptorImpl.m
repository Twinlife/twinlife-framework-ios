/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>

#import <CocoaLumberjack.h>

#import "TLVideoDescriptorImpl.h"
#import "TLTwinlifeImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"

/**
 * <pre>
 *
 * Schema version 3
 *
 * {
 *  "schemaId":"4fe07aed-f318-46e3-99d0-bb2953cef9ba",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"VideoDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.4"
 *  "fields":
 *  [
 *   {"name":"width", "type":"int"}
 *   {"name":"height", "type":"int"}
 *   {"name":"duration", "type":"long"}
 *  ]
 * }
 *
 * Schema version 2
 *
 * {
 *  "schemaId":"4fe07aed-f318-46e3-99d0-bb2953cef9ba",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"VideoDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor"
 *  "fields":
 *  [
 *   {"name":"width", "type":"int"}
 *   {"name":"height", "type":"int"}
 *   {"name":"duration", "type":"long"}
 *  ]
 * }
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"4fe07aed-f318-46e3-99d0-bb2953cef9ba",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"VideoDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.2"
 *  "fields":
 *  [
 *   {"name":"width", "type":"int"}
 *   {"name":"height", "type":"int"}
 *   {"name":"duration", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLVideoDescriptorSerializer_2
//

static NSUUID *VIDEO_DESCRIPTOR_SCHEMA_ID = nil;
static const int VIDEO_DESCRIPTOR_SCHEMA_VERSION_3 = 3;
static const int VIDEO_DESCRIPTOR_SCHEMA_VERSION_2 = 2;
static const int VIDEO_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLVideoDescriptorSerializer_3 *VIDEO_DESCRIPTOR_SERIALIZER_3 = nil;
static TLSerializer *VIDEO_DESCRIPTOR_SERIALIZER_2 = nil;
static TLSerializer *VIDEO_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLVideoDescriptorSerializer_3"

@implementation TLVideoDescriptorSerializer_3

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLVideoDescriptor.SCHEMA_ID schemaVersion:TLVideoDescriptor.SCHEMA_VERSION_3 class:[TLVideoDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLVideoDescriptor *videoDescriptor = (TLVideoDescriptor *)object;
    [encoder writeInt:videoDescriptor.width];
    [encoder writeInt:videoDescriptor.height];
    [encoder writeLong:videoDescriptor.duration];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    // Not used (see below).
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];

    int width = [decoder readInt];
    int height = [decoder readInt];
    int64_t duration = [decoder readLong];
    return [[TLVideoDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height duration:duration];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLVideoDescriptorSerializer_2"

@implementation TLVideoDescriptorSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLVideoDescriptor.SCHEMA_ID schemaVersion:TLVideoDescriptor.SCHEMA_VERSION_2 class:[TLVideoDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLVideoDescriptor *videoDescriptor = (TLVideoDescriptor *)object;
    [encoder writeInt:videoDescriptor.width];
    [encoder writeInt:videoDescriptor.height];
    [encoder writeLong:videoDescriptor.duration];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int width = [decoder readInt];
    int height = [decoder readInt];
    int64_t duration = [decoder readLong];
    return [[TLVideoDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height duration:duration];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLVideoDescriptorSerializer_1"

@implementation TLVideoDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLVideoDescriptor.SCHEMA_ID schemaVersion:TLVideoDescriptor.SCHEMA_VERSION_1 class:[TLVideoDescriptor class]];
    
    return self;
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int width = [decoder readInt];
    int height = [decoder readInt];
    int64_t duration = [decoder readLong];
    return [[TLVideoDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height duration:duration];
}

@end

//
// Implementation: TLVideoDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLVideoDescriptor"

@implementation TLVideoDescriptor

+ (void)initialize {
    
    VIDEO_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"4fe07aed-f318-46e3-99d0-bb2953cef9ba"];
    VIDEO_DESCRIPTOR_SERIALIZER_3 = [[TLVideoDescriptorSerializer_3 alloc] init];
    VIDEO_DESCRIPTOR_SERIALIZER_2 = [[TLVideoDescriptorSerializer_2 alloc] init];
    VIDEO_DESCRIPTOR_SERIALIZER_1 = [[TLVideoDescriptorSerializer_1 alloc] init];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return VIDEO_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_3 {
    
    return VIDEO_DESCRIPTOR_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return VIDEO_DESCRIPTOR_SCHEMA_VERSION_2;
}

+ (int)SCHEMA_VERSION_1 {
    
    return VIDEO_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (nonnull TLVideoDescriptorSerializer_3 *)SERIALIZER_3 {
    
    return VIDEO_DESCRIPTOR_SERIALIZER_3;
}

+ (nonnull TLSerializer *)SERIALIZER_2 {
    
    return VIDEO_DESCRIPTOR_SERIALIZER_2;
}

+ (nonnull TLSerializer *)SERIALIZER_1 {
    
    return VIDEO_DESCRIPTOR_SERIALIZER_1;
}

- (UIImage *)getThumbnailWithMaxSize:(CGSize)maxSize {
    DDLogVerbose(@"%@ getThumbnailWithMaxSize: w=%f h=%f", LOG_TAG, maxSize.width, maxSize.height);

    UIImage *image = [super getThumbnailWithMaxSize:maxSize.width];
    if (image) {
        return image;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath = [self getPathWithFileManager:fileManager];

    NSURL *url = [NSURL fileURLWithPath:absolutePath];
    AVAsset *assetVideo = [AVAsset assetWithURL:url];
    CMTime durationVideo = [assetVideo duration];
    durationVideo.value = 0;
    AVAssetImageGenerator *thumbnailGenerator = [[AVAssetImageGenerator alloc]initWithAsset:assetVideo];
    thumbnailGenerator.appliesPreferredTrackTransform = YES;
    thumbnailGenerator.maximumSize = maxSize;
    CGImageRef thumbnail = [thumbnailGenerator copyCGImageAtTime:durationVideo actualTime:NULL error:NULL];
    if (thumbnail) {
        UIImage *image = [UIImage imageWithCGImage:thumbnail];
        CGImageRelease(thumbnail);
        return image;
    }
    return nil;
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeVideoDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLVideoDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" width:  %d\n", self.width];
    [string appendFormat:@" height: %d\n", self.height];
    [string appendFormat:@" duration: %lld\n", self.duration];
}

#pragma mark - TLFileDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo descriptor:(nonnull TLVideoDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ descriptor: %@ copyAllowed: %d expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, descriptor, copyAllowed, expireTimeout);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo descriptor:descriptor copyAllowed:copyAllowed expireTimeout:expireTimeout];
    
    if (self) {
        _width = descriptor.width;
        _height = descriptor.height;
        _duration = descriptor.duration;
    }
    return self;
}

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLVideoDescriptor *)videoDescriptor masked:(BOOL)masked {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ masked: %@", LOG_TAG, videoDescriptor, masked ? @"YES" : @"NO");
    
    self = [super initWithFileDescriptor:videoDescriptor masked:masked];
    
    if (self) {
        _width = videoDescriptor.width;
        _height = videoDescriptor.height;
        _duration = videoDescriptor.duration;
    }
    return self;
}

#pragma mark - TLVideoDescriptor ()

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nonnull NSString *)extension length:(int64_t)length end:(int64_t)end width:(int)width height:(int)height duration:(int64_t)duration copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ initWithDescriptor: %@ extension: %@ length: %lld end: %lld width: %d height: %d duration: %lld copyAllowed: %d", LOG_TAG, descriptor, extension, length ,end, width, height, duration, copyAllowed);
    
    self = [super initWithDescriptor:descriptor extension:extension length:length end:end copyAllowed:copyAllowed];
    
    if (self) {
        _width = width;
        _height = height;
        _duration = duration;
    }
    return self;
}

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor width:(int)width height:(int)height duration:(int64_t)duration {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ width: %d heigth: %d duration: %lld", LOG_TAG, fileDescriptor, width, height, duration);
    
    self = [super initWithFileDescriptor:fileDescriptor masked:NO];
    
    if (self) {
        _width = width;
        _height = height;
        _duration = duration;
    }
    return self;
}

#define IMAGE_JPEG_QUALITY 0.85

- (nullable instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor url:(nonnull NSURL *)url extension:(nonnull NSString *)extension length:(int64_t)length copyAllowed:(BOOL)copyAllowed  {
    DDLogVerbose(@"%@ initWithDescriptor: %@ url: %@ extension: %@ length: %lld copyAllowed: %d", LOG_TAG, descriptor, url, extension, length, copyAllowed);
    
    self = [super initWithDescriptor:descriptor extension:extension length:length end:0 copyAllowed:copyAllowed];
    
    if (self) {
        AVAsset *assetVideo = [AVAsset assetWithURL:url];
        CMTime durationVideo = [assetVideo duration];
        _duration = ceil(durationVideo.value/durationVideo.timescale);
        AVAssetImageGenerator *thumbnailGenerator = [[AVAssetImageGenerator alloc]initWithAsset:assetVideo];
        thumbnailGenerator.appliesPreferredTrackTransform = YES;
        durationVideo.value = 0;

        // Get the video width and height original sizes.
        CGImageRef thumbnailRef = [thumbnailGenerator copyCGImageAtTime:durationVideo actualTime:NULL error:NULL];
        CGFloat width = CGImageGetWidth(thumbnailRef);
        CGFloat height = CGImageGetHeight(thumbnailRef);

        if (width <= 0 || height <= 0) {
            CGImageRelease(thumbnailRef);
            return nil;
        }
        _width = width;
        _height = height;
        self.end = length;

        // Create a reduced thumbnail or use the original preview.
        if (width > 640 || height > 640) {
            CGSize maxSize;
            CGImageRelease(thumbnailRef);
            maxSize.width = 640;
            maxSize.height = 640;
            thumbnailGenerator.maximumSize = maxSize;
            thumbnailRef = [thumbnailGenerator copyCGImageAtTime:durationVideo actualTime:NULL error:NULL];
        }
        if (thumbnailRef) {
            UIImage *image = [UIImage imageWithCGImage:thumbnailRef];
            NSData *thumbnailData = UIImageJPEGRepresentation(image, IMAGE_JPEG_QUALITY);
            CGImageRelease(thumbnailRef);
            self.hasThumbnail = YES;

            NSString *thumbPath = [self thumbnailPath];
            if (thumbPath) {
                NSFileManager *fileManager = [NSFileManager defaultManager];

                if (![fileManager createFileAtPath:thumbPath contents:thumbnailData attributes:nil]) {

                    return nil;
                }
            }
        } else {
            self.hasThumbnail = NO;
        }
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content length:(int64_t)length {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@ length: %lld", LOG_TAG, descriptorId, conversationId, creationDate, flags, content, length);
    
    NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];
    int64_t end = [TLDescriptor extractLongWithArgs:args position:3 defaultValue:0];
    NSString *extension = [TLDescriptor extractStringWithArgs:args position:4 defaultValue:nil];
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags length:length end:end extension:extension];
    if (self) {
        _width = (int) [TLDescriptor extractLongWithArgs:args position:0 defaultValue:0];
        _height = (int) [TLDescriptor extractLongWithArgs:args position:1 defaultValue:0];
        _duration = [TLDescriptor extractLongWithArgs:args position:2 defaultValue:0];
    }
    return self;
}

/// Used to forward a descriptor (see createForwardWithDescriptorId).
- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo descriptor:(nonnull TLVideoDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ descriptor: %@ copyAllowed: %d", LOG_TAG, descriptorId, conversationId, sendTo, descriptor, copyAllowed);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil descriptor:descriptor copyAllowed:copyAllowed expireTimeout:expireTimeout];
    
    if (self) {
        _width = descriptor.width;
        _height = descriptor.height;
        _duration = descriptor.duration;
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    return [NSString stringWithFormat:@"%d\n%d\n%lld\n%@", self.width, self.height, self.duration, [super serialize]];
}

- (TLPermissionType)permission {
    
    return TLPermissionTypeSendVideo;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {

    return [[TLVideoDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo descriptor:self copyAllowed:copyAllowed expireTimeout:expireTimeout];
}

@end

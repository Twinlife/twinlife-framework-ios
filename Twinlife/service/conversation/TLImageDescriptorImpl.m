/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <ImageIO/ImageIO.h>

#import <CocoaLumberjack.h>

#import "TLImageDescriptorImpl.h"
#import "TLTwinlifeImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"

/**
 * <pre>
 * Schema version 4
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"9b9490f0-5620-4a38-8022-d215e45797ec",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"ImageDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.4"
 *  "fields":
 *  [
 *   {"name":"width", "type":"int"}
 *   {"name":"height", "type":"int"}
 *  ]
 * }
 *
 * Schema version 3
 *
 * {
 *  "schemaId":"9b9490f0-5620-4a38-8022-d215e45797ec",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"ImageDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor"
 *  "fields":
 *  [
 *   {"name":"width", "type":"int"}
 *   {"name":"height", "type":"int"}
 *  ]
 * }
 *
 * Schema version 2
 *
 * {
 *  "schemaId":"9b9490f0-5620-4a38-8022-d215e45797ec",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"ImageDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.FileDescriptor.2"
 *  "fields":
 *  [
 *   {"name":"width", "type":"int"}
 *   {"name":"height", "type":"int"}
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
// Implementation: TLImageDescriptorSerializer
//

static NSUUID *IMAGE_DESCRIPTOR_SCHEMA_ID = nil;
static const int IMAGE_DESCRIPTOR_SCHEMA_VERSION_4 = 4;
static const int IMAGE_DESCRIPTOR_SCHEMA_VERSION_3 = 3;
static const int IMAGE_DESCRIPTOR_SCHEMA_VERSION_2 = 2;
static TLImageDescriptorSerializer_4 *IMAGE_DESCRIPTOR_SERIALIZER_4 = nil;
static TLSerializer *IMAGE_DESCRIPTOR_SERIALIZER_3 = nil;
static TLSerializer *IMAGE_DESCRIPTOR_SERIALIZER_2 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLImageDescriptorSerializer_4"

@implementation TLImageDescriptorSerializer_4

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLImageDescriptor.SCHEMA_ID schemaVersion:TLImageDescriptor.SCHEMA_VERSION_4 class:[TLImageDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLImageDescriptor *imageDescriptor = (TLImageDescriptor *)object;
    [encoder writeInt:imageDescriptor.width];
    [encoder writeInt:imageDescriptor.height];
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
    return [[TLImageDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLImageDescriptorSerializer_3"

@implementation TLImageDescriptorSerializer_3

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLImageDescriptor.SCHEMA_ID schemaVersion:TLImageDescriptor.SCHEMA_VERSION_3 class:[TLImageDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLImageDescriptor *imageDescriptor = (TLImageDescriptor *)object;
    [encoder writeInt:imageDescriptor.width];
    [encoder writeInt:imageDescriptor.height];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int width = [decoder readInt];
    int height = [decoder readInt];
    return [[TLImageDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLImageDescriptorSerializer_2"

@implementation TLImageDescriptorSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLImageDescriptor.SCHEMA_ID schemaVersion:TLImageDescriptor.SCHEMA_VERSION_2 class:[TLImageDescriptor class]];
    
    return self;
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int width = [decoder readInt];
    int height = [decoder readInt];
    return [[TLImageDescriptor alloc] initWithFileDescriptor:fileDescriptor width:width height:height];
}

@end

//
// Implementation: TLImageDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLImageDescriptor"

@implementation TLImageDescriptor

+ (void)initialize {
    
    IMAGE_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"9b9490f0-5620-4a38-8022-d215e45797ec"];
    IMAGE_DESCRIPTOR_SERIALIZER_4 = [[TLImageDescriptorSerializer_4 alloc] init];
    IMAGE_DESCRIPTOR_SERIALIZER_3 = [[TLImageDescriptorSerializer_3 alloc] init];
    IMAGE_DESCRIPTOR_SERIALIZER_2 = [[TLImageDescriptorSerializer_2 alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return IMAGE_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_4 {
    
    return IMAGE_DESCRIPTOR_SCHEMA_VERSION_4;
}

+ (int)SCHEMA_VERSION_3 {
    
    return IMAGE_DESCRIPTOR_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return IMAGE_DESCRIPTOR_SCHEMA_VERSION_2;
}

+ (TLImageDescriptorSerializer_4 *)SERIALIZER_4 {
    
    return IMAGE_DESCRIPTOR_SERIALIZER_4;
}

+ (TLSerializer *)SERIALIZER_3 {
    
    return IMAGE_DESCRIPTOR_SERIALIZER_3;
}

+ (TLSerializer *)SERIALIZER_2 {
    
    return IMAGE_DESCRIPTOR_SERIALIZER_2;
}

- (UIImage *)getThumbnailWithMaxSize:(CGFloat)maxSize {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *absolutePath = nil;
    if (maxSize > 0 && maxSize < 640) {
        absolutePath = [self thumbnailPath];
    }
    
    if (!absolutePath) {
        absolutePath = [self getPathWithFileManager:fileManager];
    }
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef) [NSURL fileURLWithPath:absolutePath], NULL);
    if (!imageSource) {
        return nil;
    }
    
    CFStringRef keys[3];
    CFTypeRef values[3];
    CFNumberRef thumbnailSize = CFNumberCreate(NULL, kCFNumberCGFloatType, &maxSize);
    keys[0] = kCGImageSourceCreateThumbnailWithTransform;
    values[0] = (CFTypeRef)kCFBooleanTrue;
    keys[1] = kCGImageSourceCreateThumbnailFromImageAlways;
    values[1] = (CFTypeRef)kCFBooleanTrue;
    CFIndex numValues = 2;
    if (maxSize > 0) {
        numValues = 3;
        keys[2] = kCGImageSourceThumbnailMaxPixelSize;
        values[2] = (CFTypeRef)thumbnailSize;
    }
    CFDictionaryRef options = CFDictionaryCreate(NULL, (const void **)keys, (const void **)values, numValues, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options);
    CFRelease(imageSource);
    CFRelease(options);
    CFRelease(thumbnailSize);
    UIImage *image = [UIImage imageWithCGImage:thumbnail];
    CGImageRelease(thumbnail);
    return image;
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeImageDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLImageDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" width:  %d\n", self.width];
    [string appendFormat:@" height: %d\n", self.height];
}

#pragma mark - TLFileDescriptor ()

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLImageDescriptor *)imageDescriptor masked:(BOOL)masked {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ masked: %@", LOG_TAG, imageDescriptor, masked ? @"YES" : @"NO");
    
    self = [super initWithFileDescriptor:imageDescriptor masked:masked];
    
    if (self) {
        _width = imageDescriptor.width;
        _height = imageDescriptor.height;
    }
    return self;
}

#pragma mark - TLImageDescriptor ()

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nonnull NSString *)extension length:(int64_t)length end:(int64_t)end width:(int)width height:(int)height copyAllowed:(BOOL)copyAllowed  {
    DDLogVerbose(@"%@ initWithDescriptor: %@ extension: %@ length: %lld end: %lld width: %d height: %d copyAllowed: %d", LOG_TAG, descriptor, extension, length ,end, width, height, copyAllowed);
    
    self = [super initWithDescriptor:descriptor extension:extension length:length end:end copyAllowed:copyAllowed];
    
    if (self) {
        _width = width;
        _height = height;
    }
    return self;
}

#define IMAGE_JPEG_QUALITY 0.75

- (nullable instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor url:(nonnull NSURL *)url extension:(nonnull NSString *)extension length:(int64_t)length copyAllowed:(BOOL)copyAllowed  {
    DDLogVerbose(@"%@ initWithDescriptor: %@ url: %@ extension: %@ length: %lld copyAllowed: %d", LOG_TAG, descriptor, url, extension, length, copyAllowed);
    
    self = [super initWithDescriptor:descriptor extension:extension length:length end:0 copyAllowed:copyAllowed];
    
    if (self) {
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)url, nil);
        if (!imageSource) {
            return nil;
        }
        
        CGFloat width = 0;
        CGFloat height = 0;
        CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
        if (!imageProperties) {
            CFRelease(imageSource);
            return nil;
        }
        int orientation = 1;
        
        CFNumberRef lWidth = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
        if (lWidth != nil) {
            CFNumberGetValue(lWidth, kCFNumberCGFloatType, &width);
        }
        CFNumberRef lHeight = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
        if (lHeight != nil) {
            CFNumberGetValue(lHeight, kCFNumberCGFloatType, &height);
        }
        CFNumberRef lOrientation = CFDictionaryGetValue(imageProperties, kCGImagePropertyOrientation);
        if (lOrientation != nil) {
            CFNumberGetValue(lOrientation, kCFNumberIntType, &orientation);
        }
        CFRelease(imageProperties);
        if (width <= 0 || height <= 0) {
            CFRelease(imageSource);
            return nil;
        }
        if (orientation == 6 || orientation == 8) {
            _width = height;
            _height = width;
        } else {
            _width = width;
            _height = height;
        }
        self.end = length;
        
        CGFloat maxSize = 640;
        if (length > THUMBNAIL_MIN_LENGTH) {
            CFStringRef keys[3];
            CFTypeRef values[3];
            CFNumberRef thumbnailSize = CFNumberCreate(NULL, kCFNumberCGFloatType, &maxSize);
            keys[0] = kCGImageSourceCreateThumbnailWithTransform;
            values[0] = (CFTypeRef)kCFBooleanTrue;
            keys[1] = kCGImageSourceCreateThumbnailFromImageAlways;
            values[1] = (CFTypeRef)kCFBooleanTrue;
            CFIndex numValues = 2;
            if (maxSize > 0) {
                numValues = 3;
                keys[2] = kCGImageSourceThumbnailMaxPixelSize;
                values[2] = (CFTypeRef)thumbnailSize;
            }
            CFDictionaryRef options = CFDictionaryCreate(NULL, (const void **)keys, (const void **)values, numValues, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options);
            CFRelease(imageSource);
            CFRelease(options);
            CFRelease(thumbnailSize);
            UIImage *image = [UIImage imageWithCGImage:thumbnail];
            NSData *thumbnailData = UIImageJPEGRepresentation(image, IMAGE_JPEG_QUALITY);
            CGImageRelease(thumbnail);
            
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
            CFRelease(imageSource);
        }
    }
    return self;
}

- (instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor width:(int)width height:(int)height {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ width: %d heigth: %d", LOG_TAG, fileDescriptor, width, height);
    
    self = [super initWithFileDescriptor:fileDescriptor masked:NO];
    
    if (self) {
        _width = width;
        _height = height;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content length:(int64_t)length {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@ length: %lld", LOG_TAG, descriptorId, conversationId, creationDate, flags, content, length);
    
    NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];
    int64_t end = [TLDescriptor extractLongWithArgs:args position:2 defaultValue:0];
    NSString *extension = [TLDescriptor extractStringWithArgs:args position:3 defaultValue:nil];
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags length:length end:end extension:extension];
    if (self) {
        _width = (int) [TLDescriptor extractLongWithArgs:args position:0 defaultValue:0];
        _height = (int) [TLDescriptor extractLongWithArgs:args position:1 defaultValue:0];
    }
    return self;
}

/// Used to forward a descriptor (see createForwardWithDescriptorId).
- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo descriptor:(nonnull TLImageDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ descriptor: %@ copyAllowed: %d", LOG_TAG, descriptorId, conversationId, sendTo, descriptor, copyAllowed);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:nil descriptor:descriptor copyAllowed:copyAllowed expireTimeout:expireTimeout];
    
    if (self) {
        _width = descriptor.width;
        _height = descriptor.height;
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    return [NSString stringWithFormat:@"%d\n%d\n%@", self.width, self.height, [super serialize]];
}

- (TLPermissionType)permission {
    
    return TLPermissionTypeSendImage;
}

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed {

    return [[TLImageDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo descriptor:self copyAllowed:copyAllowed expireTimeout:expireTimeout];
}

@end

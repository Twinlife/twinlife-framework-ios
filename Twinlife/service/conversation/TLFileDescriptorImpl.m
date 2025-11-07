/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLFileDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLTwinlifeImpl.h"

/**
 * <pre>
 *
 * Schema version 4
 *  Date: 2021/04/07
 *
 * {
 *  "schemaId":"e9341f60-0594-4877-b375-39bb3a836de4",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"FileDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor.4"
 *  "fields":
 *  [
 *   {"name":"path", "type": ["null", "string"]},
 *   {"name":"extension", "type": ["null", "string"]},
 *   {"name":"length", "type":"long"},
 *   {"name":"end", "type":"long"}
 *   {"name":"copyAllowed", "type":"boolean"}
 *   {"name":"hasThumbnail", "type":"boolean"}
 *  ]
 * }
 *
 * Schema version 3
 *  Date: 2019/03/19
 *
 * {
 *  "schemaId":"e9341f60-0594-4877-b375-39bb3a836de4",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"FileDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor.3"
 *  "fields":
 *  [
 *   {"name":"path", "type": ["null", "string"]},
 *   {"name":"extension", "type": ["null", "string"]},
 *   {"name":"length", "type":"long"},
 *   {"name":"end", "type":"long"}
 *   {"name":"copyAllowed", "type":"boolean"}
 *  ]
 * }
 *
 * Schema version 2
 *  Date: 2016/12/29
 *
 * {
 *  "schemaId":"e9341f60-0594-4877-b375-39bb3a836de4",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"FileDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"path", "type": ["null", "string"]},
 *   {"name":"extension", "type": ["null", "string"]},
 *   {"name":"length", "type":"long"},
 *   {"name":"end", "type":"long"}
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
// Implementation: TLFileDescriptorSerializer
//

static NSUUID *FILE_DESCRIPTOR_SCHEMA_ID = nil;
static const int FILE_DESCRIPTOR_SCHEMA_VERSION_4 = 4;
static const int FILE_DESCRIPTOR_SCHEMA_VERSION_3 = 3;
static const int FILE_DESCRIPTOR_SCHEMA_VERSION_2 = 2;
static TLFileDescriptorSerializer_4 *FILE_DESCRIPTOR_SERIALIZER_4 = nil;
static TLSerializer *FILE_DESCRIPTOR_SERIALIZER_3 = nil;
static TLSerializer *FILE_DESCRIPTOR_SERIALIZER_2 = nil;
static const BOOL FILE_DESCRIPTOR_DEFAULT_COPY_ALLOWED = false;

#undef LOG_TAG
#define LOG_TAG @"TLFileDescriptorSerializer_4"

@implementation TLFileDescriptorSerializer_4

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLFileDescriptor.SCHEMA_ID schemaVersion:TLFileDescriptor.SCHEMA_VERSION_4 class:[TLFileDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)object;
    [encoder writeOptionalString:nil]; // path is now always computed from twincode and sequence Id.
    [encoder writeOptionalString:fileDescriptor.extension];
    [encoder writeLong:fileDescriptor.length];
    [encoder writeLong:fileDescriptor.end];
    [encoder writeBoolean:fileDescriptor.copyAllowed];
    [encoder writeBoolean:fileDescriptor.hasThumbnail];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);

    // Not used (see below).
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    int64_t expireTimeout = [decoder readLong];
    NSUUID *sendTo = [decoder readOptionalUUID];
    TLDescriptorId *replyTo = [TLDescriptorSerializer_4 readOptionalDescriptorIdWithDecoder:decoder];

    NSString *path = [decoder readOptionalString];
    NSString *extension = [decoder readOptionalString];
    int64_t length = [decoder readLong];
    int64_t end = [decoder readLong];
    BOOL copyAllowed = [decoder readBoolean];
    BOOL hasThumbnail = [decoder readBoolean];
    return [[TLFileDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo path:path extension:extension length:length end:end copyAllowed:copyAllowed hasThumbnail:hasThumbnail expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:0];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLFileDescriptorSerializer_3"

@implementation TLFileDescriptorSerializer_3

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLFileDescriptor.SCHEMA_ID schemaVersion:TLFileDescriptor.SCHEMA_VERSION_3 class:[TLFileDescriptor class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)object;
    [encoder writeOptionalString:nil]; // path is now always computed from twincode and sequence Id.
    [encoder writeOptionalString:fileDescriptor.extension];
    [encoder writeLong:fileDescriptor.length];
    [encoder writeLong:fileDescriptor.end];
    [encoder writeBoolean:fileDescriptor.copyAllowed];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    /* NSString *path = (not used but must still deserialize) */ [decoder readOptionalString];
    NSString *extension = [decoder readOptionalString];
    int64_t length = [decoder readLong];
    int64_t end = [decoder readLong];
    BOOL copyAllowed = [decoder readBoolean];
    return [[TLFileDescriptor alloc] initWithDescriptor:descriptor extension:extension length:length end:end copyAllowed:copyAllowed];
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLFileDescriptorSerializer_2"

@implementation TLFileDescriptorSerializer_2

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLFileDescriptor.SCHEMA_ID schemaVersion:TLFileDescriptor.SCHEMA_VERSION_2 class:[TLFileDescriptor class]];
    
    return self;
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    /* NSString *path = (not used but must still deserialize) */ [decoder readOptionalString];
    NSString *extension = [decoder readOptionalString];
    int64_t length = [decoder readLong];
    int64_t end = [decoder readLong];
    return [[TLFileDescriptor alloc] initWithDescriptor:descriptor extension:extension length:length end:end copyAllowed:TLFileDescriptor.DEFAULT_COPY_ALLOWED];
}

@end

//
// Implementation: TLFileDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLFileDescriptor"

@implementation TLFileDescriptor

+ (void)initialize {
    
    FILE_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"e9341f60-0594-4877-b375-39bb3a836de4"];
    FILE_DESCRIPTOR_SERIALIZER_4 = [[TLFileDescriptorSerializer_4 alloc] init];
    FILE_DESCRIPTOR_SERIALIZER_3 = [[TLFileDescriptorSerializer_3 alloc] init];
    FILE_DESCRIPTOR_SERIALIZER_2 = [[TLFileDescriptorSerializer_2 alloc] init];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return FILE_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_4 {
    
    return FILE_DESCRIPTOR_SCHEMA_VERSION_4;
}

+ (int)SCHEMA_VERSION_3 {
    
    return FILE_DESCRIPTOR_SCHEMA_VERSION_3;
}

+ (int)SCHEMA_VERSION_2 {
    
    return FILE_DESCRIPTOR_SCHEMA_VERSION_2;
}

+ (nonnull TLFileDescriptorSerializer_4 *)SERIALIZER_4 {
    
    return FILE_DESCRIPTOR_SERIALIZER_4;
}

+ (nonnull TLSerializer *)SERIALIZER_3 {
    
    return FILE_DESCRIPTOR_SERIALIZER_3;
}

+ (nonnull TLSerializer *)SERIALIZER_2 {
    
    return FILE_DESCRIPTOR_SERIALIZER_2;
}

+ (BOOL)DEFAULT_COPY_ALLOWED {
    
    return FILE_DESCRIPTOR_DEFAULT_COPY_ALLOWED;
}

- (BOOL)isAvailable {
    
    return self.length <= self.end;
}

- (nullable NSURL *)getURL {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *groupURL = [TLTwinlife getAppGroupURL:fileManager];
    
    NSString *path;
    if (self.extension) {
        path = [NSString stringWithFormat:@"Conversations/%@/%lld.%@", [self.descriptorId.twincodeOutboundId UUIDString], self.descriptorId.sequenceId, self.extension];
    } else {
        path = [NSString stringWithFormat:@"Conversations/%@/%lld", [self.descriptorId.twincodeOutboundId UUIDString], self.descriptorId.sequenceId];
    }

    return [groupURL URLByAppendingPathComponent:path];
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeFileDescriptor;
}

- (nonnull NSString *)getPathWithFileManager:(nonnull NSFileManager *)fileManager {
    DDLogVerbose(@"%@ getPathWithFileManager: %@", LOG_TAG, fileManager);
    
    NSString *path;
    if (self.extension) {
        path = [NSString stringWithFormat:@"Conversations/%@/%lld.%@", [self.descriptorId.twincodeOutboundId UUIDString], self.descriptorId.sequenceId, self.extension];
    } else {
        path = [NSString stringWithFormat:@"Conversations/%@/%lld", [self.descriptorId.twincodeOutboundId UUIDString], self.descriptorId.sequenceId];
    }

    return [TLTwinlife getAppGroupPath:fileManager path:path];
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLFileDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" extension: %@\n", self.extension];
    [string appendFormat:@" length:    %lld\n", self.length];
    [string appendFormat:@" available: %@\n", [self isAvailable] ? @"YES" : @"NO"];
    [string appendFormat:@" copyAllow: %@\n", self.copyAllowed ? @"YES" : @"NO"];
}

#pragma mark - TLFileDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(NSString *)path extension:(NSString *)extension length:(int64_t)length end:(int64_t)end copyAllowed:(BOOL)copyAllowed hasThumbnail:(BOOL)hasThumbnail expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ path: %@ extension: %@ length: %lld end: %lld copyAllowed: %d hasThumbnail: %d expireTimeout: %lld", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, path, extension, length ,end, copyAllowed, hasThumbnail, expireTimeout);

    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout];
    
    if (self) {
        _extension = extension;
        _length = length;
        _end = end;
        _copyAllowed = copyAllowed;
        _hasThumbnail = hasThumbnail;
    }
    return self;
}

- (nonnull instancetype)initWithTwincodeOutboundId:(NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(NSString *)path extension:(NSString *)extension length:(int64_t)length end:(int64_t)end copyAllowed:(BOOL)copyAllowed hasThumbnail:(BOOL)hasThumbnail expireTimeout:(int64_t)expireTimeout createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp {
    DDLogVerbose(@"%@ initWithTwincodeOutboundId: %@ sequenceId: %lld sendTo: %@ replyTo: %@ path: %@ extension: %@ length: %lld end: %lld copyAllowed: %d hasThumbnail: %d expireTimeout: %lld createdTimestamp: %lld sentTimestamp: %lld", LOG_TAG, twincodeOutboundId, sequenceId, sendTo, replyTo, path, extension, length ,end, copyAllowed, hasThumbnail, expireTimeout, createdTimestamp, sentTimestamp);
    
    self = [super initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    
    if (self) {
        _extension = extension;
        _length = length;
        _end = end;
        _copyAllowed = copyAllowed;
        _hasThumbnail = hasThumbnail;
    }
    return self;
}
- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo descriptor:(nonnull TLFileDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld sendTo: %@ replyTo: %@ descriptor: %@ copyAllowed: %d", LOG_TAG, descriptorId, conversationId, sendTo, replyTo, descriptor, copyAllowed);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout];
    
    if (self) {
        _extension = descriptor.extension;
        _length = descriptor.length;
        _end = descriptor.end;
        _copyAllowed = copyAllowed;
        _hasThumbnail = descriptor.hasThumbnail;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nullable NSString *)extension length:(int64_t)length end:(int64_t)end copyAllowed:(BOOL)copyAllowed {
    DDLogVerbose(@"%@ initWithDescriptor: %@ extension: %@ length: %lld end: %lld copyAllowed: %d", LOG_TAG, descriptor, extension, length ,end, copyAllowed);
    
    self = [super initWithDescriptor:descriptor];
    
    if (self) {
        _extension = extension;
        _length = length;
        _end = end;
        _copyAllowed = copyAllowed;
        _hasThumbnail = NO;
    }
    return self;
}

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor masked:(BOOL)masked {
    DDLogVerbose(@"%@ initWithFileDescriptor: %@ masked: %@", LOG_TAG, fileDescriptor, masked ? @"YES" : @"NO");
    
    self = [super initWithDescriptor:fileDescriptor];
    
    if(self) {
        _extension = fileDescriptor.extension;
        _length = fileDescriptor.length;
        if (masked) {
            _end = 0L;
        } else {
            _end = fileDescriptor.end;
        }
        _copyAllowed = fileDescriptor.copyAllowed;
        _hasThumbnail = fileDescriptor.hasThumbnail;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags length:(int64_t)length end:(int64_t)end extension:(nullable NSString *)extension {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d length: %lld end: %lld extension: %@", LOG_TAG, descriptorId, conversationId, creationDate, flags, length, end, extension);

    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    if(self) {
        _length = length;
        _end = end;
        _extension = extension;
        _copyAllowed = (flags & DESCRIPTOR_FLAG_COPY_ALLOWED) != 0;
        _hasThumbnail = (flags & DESCRIPTOR_FLAG_HAS_THUMBNAIL) != 0;
    }
    return self;
}

- (nullable NSString *)thumbnailPath {
    DDLogVerbose(@"%@ thumbnailPath", LOG_TAG);

    if (!self.hasThumbnail) {
        
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"Conversations/%@/%lld-thumbnail.jpg", [self.descriptorId.twincodeOutboundId UUIDString], self.descriptorId.sequenceId];

    return [TLTwinlife getAppGroupPath:fileManager path:path];
}

- (nullable NSData *)loadThumbnailData {
    DDLogVerbose(@"%@ loadThumbnailData", LOG_TAG);

    NSString *thumbnailPath = [self thumbnailPath];
    if (!thumbnailPath) {
        return nil;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:thumbnailPath];
    if (!fileHandle) {
        return nil;
    }

    NSData *data = [fileHandle readDataToEndOfFile];
    [fileHandle closeFile];

    return data;
}

- (nullable UIImage *)getThumbnailWithMaxSize:(CGFloat)maxSize {

    NSString *absolutePath = [self thumbnailPath];
    if (!absolutePath) {
        return nil;
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

- (void)deleteDescriptor {
    DDLogVerbose(@"%@ deleteDescriptor", LOG_TAG);

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [self getPathWithFileManager:fileManager];
    [fileManager removeItemAtPath:path error:nil];

    if (self.hasThumbnail) {
        path = [self thumbnailPath];
        if (path) {
            [fileManager removeItemAtPath:path error:nil];
        }
    }
}

- (void)invalidateFile {
    DDLogVerbose(@"%@ invalidateFile", LOG_TAG);

    _end = 0;
    _length = 0;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    return [NSString stringWithFormat:@"%lld\n%@", self.end, (self.extension ? self.extension : @"")];
}

- (int)flags {
    
    int result = (self.copyAllowed ? DESCRIPTOR_FLAG_COPY_ALLOWED : 0);
    if (self.hasThumbnail) {
        result |= DESCRIPTOR_FLAG_HAS_THUMBNAIL;
    }
    return result;
}

- (int64_t)value {
    
    return self.length;
}

- (BOOL)updateWithCopyAllowed:(nullable NSNumber *)copyAllowed {
    
    if (copyAllowed == nil || copyAllowed.boolValue == self.copyAllowed) {
        return NO;
    }
    _copyAllowed = copyAllowed.boolValue;
    return YES;
}

@end

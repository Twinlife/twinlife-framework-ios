/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDescriptorImpl.h"

@class NSFileManager;

//
// Interface: TLFileDescriptorSerializer_4
//

@interface TLFileDescriptorSerializer_4 : TLDescriptorSerializer_4

/// Deserialize for the database.
- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp;

@end

//
// Interface: TLFileDescriptorSerializer_3
//

@interface TLFileDescriptorSerializer_3 : TLDescriptorSerializer_3

@end

//
// Interface: TLFileDescriptorSerializer_2
//

@interface TLFileDescriptorSerializer_2 : TLDescriptorSerializer_3

@end

//
// Interface: TLFileDescriptor ()
//

@interface TLFileDescriptor ()

@property int64_t end;
@property BOOL hasThumbnail;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_4;

+ (int)SCHEMA_VERSION_3;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLFileDescriptorSerializer_4 *)SERIALIZER_4;

+ (nonnull TLSerializer *)SERIALIZER_3;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId  sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(nonnull NSString *)path extension:(nonnull NSString *)extension length:(int64_t)length end:(int64_t)end copyAllowed:(BOOL)copyAllowed hasThumbnail:(BOOL)hasThumbnail expireTimeout:(int64_t)expireTimeout;

+ (nonnull TLSerializer *)SERIALIZER_2;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo path:(nullable NSString *)path extension:(nullable NSString *)extension length:(int64_t)length end:(int64_t)end copyAllowed:(BOOL)copyAllowed hasThumbnail:(BOOL)hasThumbnail expireTimeout:(int64_t)expireTimeout createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo descriptor:(nonnull TLFileDescriptor *)descriptor copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nullable NSString *)extension length:(int64_t)length end:(int64_t)end copyAllowed:(BOOL)copyAllowed ;

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor masked:(BOOL)masked;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags length:(int64_t)length end:(int64_t)end extension:(nullable NSString *)extension;

- (nullable NSData *)loadThumbnailData;

/// Get the optional thumbnail associated with the file.
- (nullable UIImage *)getThumbnailWithMaxSize:(CGFloat)maxSize;

- (nonnull NSString *)getPathWithFileManager:(nonnull NSFileManager *)fileManager;

/// Invalidate the file when the TLConversationClearMedia is used and has removed the file but kept the thumbnail.
- (void)invalidateFile;

- (BOOL)updateWithCopyAllowed:(nullable NSNumber *)copyAllowed;

@end

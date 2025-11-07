/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLFileDescriptorImpl.h"

#define THUMBNAIL_MIN_LENGTH (100 * 1024) // 100K

//
// Interface: TLImageDescriptorSerializer_4
//

@interface TLImageDescriptorSerializer_4 : TLFileDescriptorSerializer_4

/// Deserialize for the database.
- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp;

@end

//
// Interface: TLImageDescriptorSerializer_3
//

@interface TLImageDescriptorSerializer_3 : TLFileDescriptorSerializer_3

@end

//
// Interface: TLImageDescriptorSerializer_2
//

@interface TLImageDescriptorSerializer_2 : TLFileDescriptorSerializer_2

@end

//
// Interface: TLImageDescriptor ()
//

@interface TLImageDescriptor ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_4;

+ (int)SCHEMA_VERSION_3;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLImageDescriptorSerializer_4 *)SERIALIZER_4;

+ (nonnull TLSerializer *)SERIALIZER_3;

+ (nonnull TLSerializer *)SERIALIZER_2;

- (nullable instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor url:(nonnull NSURL *)url extension:(nonnull NSString *)extension length:(int64_t)length copyAllowed:(BOOL)copyAllowed;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nonnull NSString *)extension length:(int64_t)length end:(int64_t)end width:(int)width height:(int)height copyAllowed:(BOOL)copyAllowed;

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor width:(int)width height:(int)height;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content length:(int64_t)length;

@end

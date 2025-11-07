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

//
// Interface: TLAudioDescriptorSerializer_3
//

@interface TLAudioDescriptorSerializer_3 : TLFileDescriptorSerializer_4

/// Deserialize for the database.
- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp;

@end

//
// Interface: TLAudioDescriptorSerializer_2
//

@interface TLAudioDescriptorSerializer_2 : TLFileDescriptorSerializer_3

@end

//
// Interface: TLAudioDescriptorSerializer_1
//

@interface TLAudioDescriptorSerializer_1 : TLFileDescriptorSerializer_2

@end

//
// Interface: TLAudioDescriptor ()
//

@interface TLAudioDescriptor ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_3;

+ (int)SCHEMA_VERSION_2;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLAudioDescriptorSerializer_3 *)SERIALIZER_3;

+ (nonnull TLSerializer *)SERIALIZER_2;

+ (nonnull TLSerializer *)SERIALIZER_1;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor extension:(nonnull NSString *)extension length:(int64_t)length end:(int64_t)end duration:(int64_t)duration copyAllowed:(BOOL)copyAllowed;

- (nonnull instancetype)initWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor duration:(int64_t)duration;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content length:(int64_t)length;

@end

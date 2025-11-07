/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDescriptorImpl.h"

//
// Interface: TLObjectDescriptorSerializer_3
//

@interface TLObjectDescriptorSerializer_3 : TLDescriptorSerializer_3

@end

//
// Interface: TLObjectDescriptorSerializer_4
//

@interface TLObjectDescriptorSerializer_4 : TLDescriptorSerializer_3

@end

//
// Interface: TLObjectDescriptorSerializer_5
//

@interface TLObjectDescriptorSerializer_5 : TLDescriptorSerializer_4

/// Deserialize for the database.
- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp;

@end

//
// Interface: TLObjectDescriptor ()
//

@interface TLObjectDescriptor ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_5;

+ (int)SCHEMA_VERSION_4;

+ (int)SCHEMA_VERSION_3;

+ (nonnull TLObjectDescriptorSerializer_5 *)SERIALIZER_5;

+ (nonnull TLSerializer *)SERIALIZER_4;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

+ (nonnull TLSerializer *)SERIALIZER_3;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor message:(nonnull NSString *)message copyAllowed:(BOOL)copyAllowed;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content;

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder;

- (BOOL)updateWithMessage:(nullable NSString *)message;

- (BOOL)updateWithCopyAllowed:(nullable NSNumber *)copyAllowed;

- (void)markEdited;

@end

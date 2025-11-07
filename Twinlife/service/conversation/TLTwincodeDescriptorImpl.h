/*
 *  Copyright (c) 2019-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDescriptorImpl.h"

//
// Interface: TLTwincodeDescriptorSerializer_2
//

@interface TLTwincodeDescriptorSerializer_2 : TLDescriptorSerializer_4

/// Deserialize for the database.
- (nonnull NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp;

@end

//
// Interface: TLTwincodeDescriptorSerializer_1
//

@interface TLTwincodeDescriptorSerializer_1 : TLDescriptorSerializer_3

@end

//
// Interface: TLTwincodeDescriptor ()
//

@interface TLTwincodeDescriptor ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLTwincodeDescriptorSerializer_2 *)SERIALIZER_2;

+ (nonnull TLSerializer *)SERIALIZER_1;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo twincodeId:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId publicKey:(nullable NSString *)publicKey  copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo twincodeId:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId publicKey:(nullable NSString *)publicKey copyAllowed:(BOOL)copyAllowed expireTimeout:(int64_t)expireTimeout createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor twincodeId:(nonnull NSUUID *)twincodeId schemaId:(nonnull NSUUID *)schemaId copyAllowed:(BOOL)copyAllowed;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content;

@end

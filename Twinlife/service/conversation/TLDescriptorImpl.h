/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationService.h"
#import "TLSerializer.h"

#define DESCRIPTOR_FLAG_COPY_ALLOWED    0x01
#define DESCRIPTOR_FLAG_HAS_THUMBNAIL   0x02
#define DESCRIPTOR_FLAG_UPDATED         0x04

// Flags used by the CallDescriptor
#define DESCRIPTOR_FLAG_VIDEO           0x10
#define DESCRIPTOR_FLAG_INCOMING_CALL   0x20
#define DESCRIPTOR_FLAG_ACCEPTED_CALL   0x40

#define DESCRIPTOR_FIELD_SEPARATOR      @"\n"

//
// Interface: TLDescriptorSerializer_4
//

@interface TLDescriptorSerializer_4 : TLSerializer

+ (nullable TLDescriptorId *)readOptionalDescriptorIdWithDecoder:(nonnull id<TLDecoder>)decoder;

@end

//
// Interface: TLDescriptorSerializer_3
//

@interface TLDescriptorSerializer_3 : TLSerializer

@end

//
// Interface: TLDescriptorAnnotation ()
//

@interface TLDescriptorAnnotation ()

- (nonnull instancetype)initWithType:(TLDescriptorAnnotationType)type value:(int)value count:(int)count;

@end

//
// Interface: TLDescriptor ()
//

@interface TLDescriptor ()

@property int64_t createdTimestamp;
@property (nullable) NSMutableArray<TLDescriptorAnnotation *> *annotations;
@property int64_t conversationId;

/// Extract the string content into an array of arguments that can be queried by extractWithArgs
+ (nullable NSArray<NSString *> *)extractWithContent:(nullable NSString *)content;

+ (int64_t)extractLongWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(int64_t)defaultValue;

+ (nullable NSString *)extractStringWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(nullable NSString *)defaultValue;

+ (double)extractDoubleWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(double)defaultValue;

+ (nonnull NSUUID *)extractUUIDWithArgs:(nullable NSArray<NSString *> *)args position:(int)position defaultValue:(nonnull NSUUID *)defaultValue;

+ (nullable TLDescriptor *)extractDescriptorWithContent:(nullable NSData *)content serializerFactory:(nonnull TLSerializerFactory *)serializerFactory timestamps:(nullable NSData *)timestamps twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId createdTimestamp:(int64_t)createdTimestamp updatedTimestamp:(int64_t)updatedTimestamp sentTimestamp:(int64_t)sentTimestamp receivedTimestamp:(int64_t)receivedTimestamp readTimestamp:(int64_t)readTimestamp deletedTimestamp:(int64_t)deletedTimestamp peerDeletedTimestamp:(int64_t)peerDeletedTimestamp;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo expireTimeout:(int64_t)expireTimeout;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo expireTimeout:(int64_t)expireTimeout  createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout;

- (void)setUpdatedTimestamp:(int64_t)updatedTimestamp;

- (void)setSentTimestamp:(int64_t)sentTimestamp;

- (void)setReceivedTimestamp:(int64_t)receivedTimestamp;

- (void)setDeletedTimestamp:(int64_t)deletedTimestamp;

- (void)setPeerDeletedTimestamp:(int64_t)peerDeletedTimestamp;

- (void)setReadTimestamp:(int64_t)readTimestamp;

- (void)deserializeTimestamps:(nonnull NSData *)data;

- (nonnull NSData *)serializeTimestamps;

/// Apply an offset time correction on the creation and sent time and make sure the creation time is not in the future.
- (void)adjustCreatedAndSentTimestamps:(int64_t)offset;

- (BOOL)hasTimestamps;

- (void)deleteDescriptor;

- (void)appendTo:(nonnull NSMutableString*)string;

- (nullable NSString *)serialize;

- (int)flags;

- (int64_t)value;

- (TLPermissionType)permission;

- (nullable TLDescriptor *)createForwardWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo copyAllowed:(BOOL)copyAllowed;

- (void)updateWithConversationId:(int64_t)conversationId descriptorId:(int64_t)descriptorId;

- (BOOL)updateWithExpireTimeout:(nullable NSNumber *)expireTimeout;

@end

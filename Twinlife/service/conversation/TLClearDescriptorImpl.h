/*
 *  Copyright (c) 2022-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDescriptorImpl.h"

//
// Interface: TLClearDescriptorSerializer_1
//

@interface TLClearDescriptorSerializer_1 : TLDescriptorSerializer_3

@end

//
// Interface: TLClearDescriptor ()
//

@interface TLClearDescriptor ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLSerializer *)SERIALIZER_1;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId clearTimestamp:(int64_t)clearTimestamp;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp clearTimestamp:(int64_t)clearTimestamp;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout clearDate:(int64_t)clearDate;

@end

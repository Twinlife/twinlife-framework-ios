/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLDescriptorImpl.h"


//
// Interface: TLContactShareDescriptor ()
//

@interface TLContactShareDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout name:(nonnull NSString *)name contactId:(nonnull NSUUID *)contactId;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp name:(nonnull NSString *)name status:(TLInvitationDescriptorStatusType)status;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content value:(int64_t)value;

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder;

- (nullable NSData *)loadAvatarData;

- (void)saveAvatarWithData:(nullable NSData *)data;
@end

/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLDescriptorImpl.h"


//
// Interface: TLPollDescriptor ()
//

@interface TLPollDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout multipleChoicesAllowed:(BOOL)multipleChoicesAllowed question:(nonnull NSString *)question choices:(nonnull NSArray<TLChoice *> *)choices copyAllowed:(BOOL)copyAllowed;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp multipleChoicesAllowed:(BOOL)multipleChoicesAllowed question:(nonnull NSString *)question choices:(nonnull NSArray<TLChoice *> *)choices copyAllowed:(BOOL)copyAllowed;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content;

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder;

- (BOOL)updateWithMessage:(nullable NSString *)message;

- (BOOL)updateWithCopyAllowed:(nullable NSNumber *)copyAllowed;

- (void)markEdited;

@end

/*
 *  Copyright (c) 2020-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDescriptorImpl.h"

//
// Interface: TLCallDescriptorSerializer_1
//

@interface TLCallDescriptorSerializer_1 : TLDescriptorSerializer_3

@end

//
// Interface: TLCallDescriptor ()
//

@interface TLCallDescriptor ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLSerializer *)SERIALIZER_1;

+ (TLPeerConnectionServiceTerminateReason)toTerminateReason:(int)value;

+ (int)fromTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId video:(BOOL)video incomingCall:(BOOL)incomingCall;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content duration:(int64_t)duration;

- (void) setAccepted;

- (void) setTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

@end

/*
 *  Copyright (c) 2018-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDescriptorImpl.h"

//
// Interface: TLInvitationDescriptorSerializer_1
//

@interface TLInvitationDescriptorSerializer_1 : TLDescriptorSerializer_3

@end

//
// Interface: TLInvitationDescriptor ()
//

@interface TLInvitationDescriptor ()

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLSerializer *)SERIALIZER_1;

+ (int)fromInvitationStatus:(TLInvitationDescriptorStatusType)status;

+ (TLInvitationDescriptorStatusType)toInvitationStatus:(int)value;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId groupTwincodeId:(nonnull NSUUID *)groupTwincodeId inviterTwincodeId:(nonnull NSUUID *)inviterTwincodeId name:(nonnull NSString *)name publicKey:(nullable NSString *)publicKey;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)invitationDescriptor groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId inviterTwincodeId:(nonnull NSUUID *)inviterTwincodeId name:(nonnull NSString *)name status:(TLInvitationDescriptorStatusType)status;

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content status:(int64_t)status;

// Create the invitation descriptor received by the TLInviteGroupIQ
- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId groupTwincodeId:(nonnull NSUUID *)groupTwincodeId inviterTwincodeId:(nullable NSUUID *)inviterTwincodeId name:(nonnull NSString *)name publicKey:(nullable NSString *)publicKey creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate expireTimeout:(int64_t)expireTimeout;

@end

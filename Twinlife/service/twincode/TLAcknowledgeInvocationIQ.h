/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLAcknowledgeInvocationIQSerializer
//

@interface TLAcknowledgeInvocationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLAcknowledgeInvocationIQ
//

@interface TLAcknowledgeInvocationIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *invocationId;
@property (readonly) TLBaseServiceErrorCode errorCode;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId invocationId:(nonnull NSUUID *)invocationId errorCode:(TLBaseServiceErrorCode)errorCode;

@end

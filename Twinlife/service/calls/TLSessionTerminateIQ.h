/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"
#import "TLPeerConnectionService.h"

//
// Interface: TLSessionTerminateIQSerializer
//

@interface TLSessionTerminateIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSessionTerminateIQ
//

@interface TLSessionTerminateIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *to;
@property (readonly, nonnull) NSUUID *sessionId;
@property (readonly) TLPeerConnectionServiceTerminateReason reason;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId reason:(TLPeerConnectionServiceTerminateReason)reason;

@end

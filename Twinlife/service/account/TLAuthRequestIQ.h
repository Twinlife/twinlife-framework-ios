/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLAuthRequestIQSerializer
//

@interface TLAuthRequestIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLAuthRequestIQ
//

@interface TLAuthRequestIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *accountIdentifier;
@property (readonly, nonnull) NSString *resourceIdentifier;
@property (readonly, nonnull) NSData *deviceNonce;
@property (readonly, nonnull) NSData *deviceProof;
@property (readonly) int deviceState;
@property (readonly) int deviceLatency;
@property (readonly) int64_t deviceTimestamp;
@property (readonly) int64_t serverTimestamp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  accountIdentifier:(nonnull NSString *)accountIdentifier resourceIdentifier:(nonnull NSString *)resourceIdentifier deviceNonce:(nonnull NSData *)deviceNonce deviceProof:(nonnull NSData *)deviceProof deviceState:(int)deviceState deviceLatency:(int)deviceLatency deviceTimestamp:(int64_t)deviceTimestamp serverTimestamp:(int64_t)serverTimestamp;

@end

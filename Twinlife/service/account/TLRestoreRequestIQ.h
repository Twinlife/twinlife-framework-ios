/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLRestoreRequestIQSerializer
//

@interface TLRestoreRequestIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLRestoreRequestIQ
//

@interface TLRestoreRequestIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *accountIdentifier;
@property (readonly, nonnull) NSString *resourceIdentifier;
@property (readonly, nonnull) NSData *deviceNonce;
@property (readonly, nonnull) NSData *deviceProof;
@property (readonly) int deviceState;
@property (readonly) int deviceLatency;
@property (readonly) int64_t deviceTimestamp;
@property (readonly) int64_t serverTimestamp;
@property (readonly, nonnull) NSUUID *backupId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId accountIdentifier:(nonnull NSString *)accountIdentifier resourceIdentifier:(nonnull NSString *)resourceIdentifier deviceNonce:(nonnull NSData *)deviceNonce deviceProof:(nonnull NSData *)deviceProof backupId:(nonnull NSUUID *)backupId;

@end

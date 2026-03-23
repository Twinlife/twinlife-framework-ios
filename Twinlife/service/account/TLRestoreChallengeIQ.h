/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLRestoreChallengeIQ
//

@interface TLRestoreChallengeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLRestoreChallengeIQ
//

@interface TLRestoreChallengeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *backupId;
@property (readonly, nonnull) NSString *accountIdentifier;
@property (readonly, nonnull) NSData *nonce;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId backupId:(nonnull NSUUID *)backupId accountIdentifier:(nonnull NSString *)accountIdentifier nonce:(nonnull NSData *)nonce;

- (nonnull NSString *)clientFirstMessageBare;

@end

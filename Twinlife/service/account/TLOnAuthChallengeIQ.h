/*
 *  Copyright (c) 2021-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnAuthChallengeIQSerializer
//

@interface TLOnAuthChallengeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnAuthChallengeIQ
//

@interface TLOnAuthChallengeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSData *salt;
@property (readonly) int iterations;
@property (readonly, nonnull) NSData *serverNonce;
@property (readonly) int64_t serverTimestamp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq salt:(nonnull NSData *)salt iterations:(int)iterations serverNonce:(nonnull NSData *)serverNonce serverTimestamp:(int64_t)serverTimestamp;

- (nonnull NSString *)serverFirstMessageBare;

@end

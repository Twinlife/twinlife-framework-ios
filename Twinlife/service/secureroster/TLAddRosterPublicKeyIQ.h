/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSecureRosterIQ.h"

//
// Interface: TLAddRosterPublicKeyIQSerializer
//

@interface TLAddRosterPublicKeyIQSerializer : TLSecureRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLAddRosterPublicKeyIQ
//

@interface TLAddRosterPublicKeyIQ : TLSecureRosterIQ

@property (readonly, nonnull) NSUUID *signingKeyId;
@property (readonly, nonnull) NSUUID *keyId;
@property (readonly, nonnull) NSData *publicKey;
@property (readonly, nonnull) NSData *signature;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId signingKeyId:(nonnull NSUUID *)signingKeyId newKeyId:(nonnull NSUUID *)newKeyId newPublicKey:(nonnull NSData *)newPublicKey signature:(nonnull NSData *)signature;

@end

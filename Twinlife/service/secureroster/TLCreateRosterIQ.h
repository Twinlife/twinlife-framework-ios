/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLCreateRosterIQSerializer
//

@interface TLCreateRosterIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateRosterIQ
//

@interface TLCreateRosterIQ : TLBinaryPacketIQ

@property (readonly) int createOptions;
@property (readonly, nonnull) NSUUID *rosterSchemaId;
@property (readonly, nonnull) NSUUID *publicKeyId;
@property (readonly, nonnull) NSData *publicKey;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId createOptions:(int)createOptions rosterSchemaId:(nonnull NSUUID *)rosterSchemaId publicKeyId:(nonnull NSUUID *)publicKeyId publicKey:(nonnull NSData *)publicKey;

@end

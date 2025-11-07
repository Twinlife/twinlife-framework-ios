/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLDeleteAccountIQSerializer
//

@interface TLDeleteAccountIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLDeleteAccountIQ
//

@interface TLDeleteAccountIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *accountIdentifier;
@property (readonly, nonnull) NSString *accountPassword;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  accountIdentifier:(nonnull NSString *)accountIdentifier accountPassword:(nonnull NSString *)accountPassword;

@end

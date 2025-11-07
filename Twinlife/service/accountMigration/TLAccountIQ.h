/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLSwapAccountIQSerializer
//

@interface TLSwapAccountIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLAccountIQ
//

@interface TLAccountIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSData *securedConfiguration;
@property (readonly, nonnull) NSData *accountConfiguration;
@property (readonly) BOOL hasPeerAccount;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId securedConfiguration:(nonnull NSData *)securedConfiguration accountConfiguration:(nonnull NSData *)accountConfiguration hasPeerAccount:(BOOL)hasPeerAccount;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq securedConfiguration:(nonnull NSData *)securedConfiguration accountConfiguration:(nonnull NSData *)accountConfiguration hasPeerAccount:(BOOL)hasPeerAccount;

@end

/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLCreateInvitationCodeIQSerializer
//

@interface TLCreateInvitationCodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateInvitationCodeIQ
//

@interface TLCreateInvitationCodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly) int validityPeriod;
@property (readonly, nullable) NSString *publicKey;


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId validityPeriod:(int)validityPeriod publicKey:(nullable NSString *)publicKey;

@end

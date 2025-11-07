/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLGetInvitationCodeIQSerializer
//

@interface TLGetInvitationCodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLGetInvitationCodeIQ
//

@interface TLGetInvitationCodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *code;


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId code:(nonnull NSString *)code;

@end

/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnCreateInvitationCodeIQSerializer
//

@interface TLOnCreateInvitationCodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateInvitationCodeIQ
//

@interface TLOnCreateInvitationCodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *codeId;
@property (readonly) int64_t creationDate;
@property (readonly) int validityPeriod;
@property (readonly, nonnull) NSString *code;
@property (readonly, nonnull) NSUUID *twincodeId;


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId codeId:(nonnull NSUUID *)codeId creationDate:(int64_t)creationDate validityPeriod:(int)validityPeriod code:(nullable NSString *)code twincodeId:(nonnull NSUUID *)twincodeId;

@end


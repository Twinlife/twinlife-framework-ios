/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface: TLInvitationCode
//

@interface TLInvitationCode : NSObject

@property (readonly, nonnull) NSString *code;
@property (readonly) int64_t creationDate;
@property (readonly) int validityPeriod;
@property (readonly, nullable) NSString *publicKey;

- (nonnull instancetype)initWithCreationDate:(int64_t)creationDate validityPeriod:(int)validityPeriod code:(nonnull NSString *)code publicKey:(nullable NSString *)publicKey;

@end

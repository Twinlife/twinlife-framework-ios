/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnGetTwincodeIQ.h"

//
// Interface: TLOnGetnvitationCodeIQSerializer
//

@interface TLOnGetInvitationCodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnGetInvitationCodeIQ
//

@interface TLOnGetInvitationCodeIQ : TLOnGetTwincodeIQ

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nullable) NSString *publicKey;


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq twincodeId:(nonnull NSUUID *)twincodeId modificationDate:(int64_t)modificationDate attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nullable NSData *)signature publicKey:(nullable NSString *)publicKey;

@end



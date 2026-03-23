/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnTerminateAccountRestoreIQ
//

@interface TLOnTerminateAccountRestoreIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnTerminateAccountRestoreIQ
//

@interface TLOnTerminateAccountRestoreIQ : TLBinaryPacketIQ

@property (readonly) TLBaseServiceErrorCode errorCode;
@property (readonly) int restoreCount;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq errorCode:(TLBaseServiceErrorCode)errorCode restoreCount:(int)restoreCount;

@end

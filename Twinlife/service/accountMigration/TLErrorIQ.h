/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"
#import "TLAccountMigrationService.h"

//
// Interface: TLMigrationErrorIQSerializer
//

@interface TLMigrationErrorIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLMigrationErrorIQ
//

@interface TLMigrationErrorIQ : TLBinaryPacketIQ

@property (readonly) TLAccountMigrationErrorCode errorCode;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLAccountMigrationErrorCode)errorCode;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq errorCode:(TLAccountMigrationErrorCode)errorCode;

@end

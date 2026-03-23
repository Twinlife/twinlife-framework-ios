/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"
#import "TLAccountService.h"

//
// Interface: TLTerminateAccountRestoreIQSerializer
//

@interface TLTerminateAccountRestoreIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLTerminateAccountRestoreIQ
//

@interface TLTerminateAccountRestoreIQ : TLBinaryPacketIQ

@property (readonly) BOOL commit;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId  commit:(BOOL)commit;

@end

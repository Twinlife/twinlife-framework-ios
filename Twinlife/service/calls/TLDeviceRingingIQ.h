/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */
#import "TLBinaryPacketIQ.h"

//
// Interface: TLDeviceRingingIQSerializer
//

@interface TLDeviceRingingIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLDeviceRingingIQ
//

@interface TLDeviceRingingIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *to;
@property (readonly, nonnull) NSUUID *sessionId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId;

@end

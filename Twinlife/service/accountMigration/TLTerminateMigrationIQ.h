/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLTerminateMigrationIQSerializer
//

@interface TLTerminateMigrationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLTerminateMigrationIQ
//

@interface TLTerminateMigrationIQ : TLBinaryPacketIQ

@property (readonly) BOOL commit;
@property (readonly) BOOL done;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId commit:(BOOL)commit done:(BOOL)done;

@end

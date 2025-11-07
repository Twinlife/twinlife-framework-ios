/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLAssertPoint;
@class TLAssertValue;
@class TLVersion;

//
// Interface: TLAssertionIQSerializer
//

@interface TLAssertionIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLAssertionIQ
//

@interface TLAssertionIQ : TLBinaryPacketIQ

@property (nonnull) NSUUID *applicationId;
@property (nonnull) TLVersion *applicationVersion;
@property (readonly, nonnull) TLAssertPoint *assertPoint;
@property (readonly, nullable) NSArray<TLAssertValue *> *values;
@property (readonly, nullable) NSException *exception;
@property (readonly) int64_t timestamp;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId applicationId:(nonnull NSUUID *)applicationId applicationVersion:(nonnull TLVersion *)applicationVersion assertPoint:(nonnull TLAssertPoint *)assertPoint values:(nullable NSArray<TLAssertValue *> *)values exception:(nullable NSException *)exception timestamp:(int64_t)timestamp;

@end

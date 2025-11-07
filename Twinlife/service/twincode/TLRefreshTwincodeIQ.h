/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLRefreshTwincodeIQSerializer
//

@interface TLRefreshTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLRefreshTwincodeIQ
//

@interface TLRefreshTwincodeIQ : TLBinaryPacketIQ

@property (readonly) int64_t timestamp;
@property (readonly, nonnull) NSDictionary<NSUUID *, NSNumber *> *twincodeList;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId timestamp:(int64_t)timestamp twincodeList:(nonnull NSDictionary<NSUUID *, NSNumber *> *)twincodeList;

@end

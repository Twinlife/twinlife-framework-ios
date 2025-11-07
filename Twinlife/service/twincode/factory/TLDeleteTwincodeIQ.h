/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLDeleteTwincodeIQSerializer
//

@interface TLDeleteTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLDeleteTwincodeIQ
//

@interface TLDeleteTwincodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly) int deleteOptions;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId deleteOptions:(int)deleteOptions;

@end

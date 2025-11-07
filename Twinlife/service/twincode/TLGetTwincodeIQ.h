/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLGetTwincodeIQSerializer
//

@interface TLGetTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLGetTwincodeIQ
//

@interface TLGetTwincodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *twincodeId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId;

@end

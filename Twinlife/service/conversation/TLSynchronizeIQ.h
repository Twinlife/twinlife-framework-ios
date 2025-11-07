/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLSynchronizeIQSerializer
//

@interface TLSynchronizeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSynchronizeIQ
//

@interface TLSynchronizeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *twincodeOutboundId;
@property (readonly, nonnull) NSUUID *resourceId;
@property (readonly) int64_t timestamp;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId resourceId:(nonnull NSUUID *)resourceId timestamp:(int64_t)timestamp;

@end

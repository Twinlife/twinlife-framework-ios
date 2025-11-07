/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLOnCreateTwincodeIQSerializer
//

@interface TLOnCreateTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnCreateTwincodeIQ
//

@interface TLOnCreateTwincodeIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *factoryTwincodeId;
@property (readonly, nonnull) NSUUID *inboundTwincodeId;
@property (readonly, nonnull) NSUUID *outboundTwincodeId;
@property (readonly, nonnull) NSUUID *switchTwincodeId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId factoryTwincodeId:(nonnull NSUUID *)factoryTwincodeId inboundTwincodeId:(nonnull NSUUID *)inboundTwincodeId outboundTwincodeId:(nonnull NSUUID *)outboundTwincodeId switchTwincodeId:(nonnull NSUUID *)switchTwincodeId;

@end

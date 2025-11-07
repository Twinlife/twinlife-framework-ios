/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

#define BIND_INBOUND_OPTION 0x01 // Bind the inbound twincode to the device.

//
// Interface: TLCreateTwincodeIQSerializer
//

@interface TLCreateTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateTwincodeIQ
//

@interface TLCreateTwincodeIQ : TLBinaryPacketIQ

@property (readonly) int createOptions;
@property (readonly, nonnull) NSArray<TLAttributeNameValue *> *factoryAttributes;
@property (readonly, nullable) NSArray<TLAttributeNameValue *> *inboundAttributes;
@property (readonly, nullable) NSArray<TLAttributeNameValue *> *outboundAttributes;
@property (readonly, nullable) NSArray<TLAttributeNameValue *> *switchAttributes;
@property (readonly, nullable) NSUUID *twincodeSchemaId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId createOptions:(int)createOptions factoryAttributes:(nonnull NSArray<TLAttributeNameValue *> *)factoryAttributes inboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)inboundAttributes outboundAttributes:(nullable NSArray<TLAttributeNameValue *> *)outboundAttributes switchAttributes:(nullable NSArray<TLAttributeNameValue *> *)switchAttributes twincodeSchemaId:(nullable NSUUID *)twincodeSchemaId;

@end

/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBaseService.h"
#import "TLSerializer.h"

@class TLAttributeNameValue;
@protocol TLEncoder;
@protocol TLDecoder;

//
// Interface: TLBinaryPacketIQSerializer
//

@interface TLBinaryPacketIQSerializer : TLSerializer

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(int)schemaVersion class:(nonnull Class) clazz;

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion class:(nonnull Class) clazz;

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes;

- (nullable NSMutableArray<TLAttributeNameValue *> *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder;

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Interface: TLBinaryPacketIQ
//

/// Base class of binary packets.
@interface TLBinaryPacketIQ : NSObject

@property (readonly) int64_t requestId;
@property (readonly, nonnull) TLSerializer *serializer;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq;

- (nonnull NSMutableData *)serializeCompactWithSerializerFactory:(nonnull TLSerializerFactory *)factory;

- (nonnull NSMutableData *)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)factory;

- (nonnull NSMutableData *)serializePaddingWithSerializerFactory:(nonnull TLSerializerFactory *)factory withLeadingPadding:(BOOL)withLeadingPadding;

- (long)bufferSize;

- (void)appendTo:(nonnull NSMutableString*)string;

@end

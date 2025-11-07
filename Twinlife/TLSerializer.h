/*
 *  Copyright (c) 2015-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLSerializerKey
//

@interface TLSerializerKey : NSObject <NSCopying>

@property (readonly, nonnull) NSUUID *schemaId;
@property (readonly) long schemaVersion;

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(long)schemaVersion;

- (BOOL)isEqual:(nullable id)object;

- (NSUInteger)hash;

@end

//
// Interface: TLSerializer
//

@class TLSerializerFactory;
@protocol TLEncoder;
@protocol TLDecoder;

@interface TLSerializer : NSObject

@property (readonly, nonnull) NSUUID *schemaId;
@property (readonly) int schemaVersion;
@property (readonly, nonnull) Class clazz;

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(int)schemaVersion class:(nonnull Class) clazz;

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(nonnull NSObject *)object;

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder;

- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion;

@end

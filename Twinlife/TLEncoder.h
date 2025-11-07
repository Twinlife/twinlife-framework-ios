/*
 *  Copyright (c) 2015-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLAttributeNameValue;

//
// Protocol: TLEncoder
//

@protocol TLEncoder

- (void)writeBoolean:(BOOL)value;

- (void)writeZero;

- (void)writeInt:(int32_t)value;

- (void)writeLong:(int64_t)value;

- (void)writeUUID:(nonnull NSUUID *)value;

- (void)writeOptionalUUID:(nullable NSUUID *)value;

- (void)writeFloat:(float)value;

- (void)writeDouble:(double)value;

- (void)writeEnum:(int32_t)value;

- (void)writeString:(nonnull NSString *)value;

- (void)writeOptionalString:(nullable NSString *)value;

- (void)writeData:(nonnull NSData *)data;

- (void)writeOptionalData:(nullable NSData *)data;

- (void)writeDataWithData:(nonnull NSData *)data start:(int32_t)start length:(int32_t)length;

- (void)writeFixedWithData:(nonnull NSData *)data start:(int32_t)start length:(int32_t)length;

- (void)writeAttributes:(nullable NSArray<TLAttributeNameValue *> *)attributes;

@end

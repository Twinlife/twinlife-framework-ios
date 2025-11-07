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
// Protocol: TLDecoder
//

@protocol TLDecoder <NSObject>

- (BOOL)readBoolean;

- (int32_t)readInt;

- (int64_t)readLong;

- (nonnull NSUUID *)readUUID;

- (nullable NSUUID *)readOptionalUUID;

- (float)readFloat;

- (double)readDouble;

- (int32_t)readEnum;

- (nonnull NSString *)readString;

- (nullable NSString *)readOptionalString;

- (nonnull NSData *)readData;

- (nullable NSData *)readOptionalData;

- (void)readFixedWithData:(nonnull NSData *)data start:(int)start length:(int)length;

- (nullable NSMutableArray<TLAttributeNameValue *> *)readAttributes;

@end

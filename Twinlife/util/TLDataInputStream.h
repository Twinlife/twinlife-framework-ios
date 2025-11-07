/*
 *  Copyright (c) 2015-2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLDataInputStream
//

@class TLAttributeNameValue;

@interface TLDataInputStream : NSObject

+ (BOOL)isNullUUID:(NSUUID *)uuid;

- (instancetype)initWithData:(NSData *)data;

- (int8_t)readInt8;

- (uint8_t)readUInt8;

- (int16_t)readInt16;

- (uint16_t)readUInt16;

- (int32_t)readInt32;

- (uint32_t)readUInt32;

- (int64_t)readInt64;

- (uint64_t)readUInt64;

- (int)readInt;

- (NSInteger)readInteger;

- (NSUInteger)readUInteger;

- (double)readDouble;

- (BOOL)readBoolean;

- (NSUUID *)readUUID;

- (NSString *)readString;

- (NSData *)readData;

- (BOOL)isCompleted;

@end

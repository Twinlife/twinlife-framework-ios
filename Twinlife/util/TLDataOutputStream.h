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
// Interface: TLDataOutputStream
//

@class TLAttributeNameValue;

@interface TLDataOutputStream : NSObject

- (void)writeInt8:(int8_t)value;

- (void)writeUInt8:(uint8_t)value;

- (void)writeInt16:(int16_t)value;

- (void)writeUInt16:(uint16_t)value;

- (void)writeInt32:(int32_t)value;

- (void)writeUInt32:(uint32_t)value;

- (void)writeInt64:(int64_t)value;

- (void)writeUInt64:(uint64_t)value;

- (void)writeInt:(int)value;

- (void)writeInteger:(NSInteger)value;

- (void)writeUInteger:(NSUInteger)value;

- (void)writeDouble:(double)value;

- (void)writeBoolean:(BOOL)value;

- (void)writeUUID:(nonnull NSUUID *)value;

- (void)writeString:(nonnull NSString *)value;

- (void)writeData:(nonnull NSData *)value;

- (nonnull NSData *)getData;

@end

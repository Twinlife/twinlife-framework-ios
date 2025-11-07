/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLBinaryEncoder.h"
#import "TLAttributeNameValue.h"
#import "TLImageService.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLBinaryEncoder ()
//

@interface TLBinaryEncoder () {
    
    uint8_t _buffer[12];
}

+ (int)encodeWithInt:(int32_t)value buffer:(uint8_t[])buffer;

+ (int)encodeWithLong:(int64_t)value buffer:(uint8_t[])buffer;

@end

//
// Implementation: TLBinaryEncoder
//

#undef LOG_TAG
#define LOG_TAG @"TLBinaryEncoder"

@implementation TLBinaryEncoder

+ (int)encodeWithInt:(int32_t)value buffer:(uint8_t[])buffer {
    
    uint32_t lValue = (value << 1) ^ (value >> 31);
    int position = 0;
    if ((lValue & ~0x7F) != 0) {
        buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
        lValue >>= 7;
        if (lValue > 0x7F) {
            buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
            lValue >>= 7;
            if (lValue > 0x7F) {
                buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                lValue >>= 7;
                if (lValue > 0x7F) {
                    buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                    lValue >>= 7;
                }
            }
        }
    }
    buffer[position++] = (uint8_t)lValue;
    return position;
}

+ (int)encodeWithLong:(int64_t)value buffer:(uint8_t[])buffer {
    
    uint64_t lValue = (value << 1) ^ (value >> 63);
    int position = 0;
    if ((lValue & ~0x7FL) != 0) {
        buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
        lValue >>= 7;
        if (lValue > 0x7F) {
            buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
            lValue >>= 7;
            if (lValue > 0x7F) {
                buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                lValue >>= 7;
                if (lValue > 0x7F) {
                    buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                    lValue >>= 7;
                    if (lValue > 0x7F) {
                        buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                        lValue >>= 7;
                        if (lValue > 0x7F) {
                            buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                            lValue >>= 7;
                            if (lValue > 0x7F) {
                                buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                                lValue >>= 7;
                                if (lValue > 0x7F) {
                                    buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                                    lValue >>= 7;
                                    if (lValue > 0x7F) {
                                        buffer[position++] = (uint8_t)((lValue | 0x80) & 0xFF);
                                        lValue >>= 7;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    buffer[position++] = (uint8_t) lValue;
    return position;
}

- (instancetype)initWithData:(nonnull NSMutableData *)data {
    DDLogVerbose(@"%@ initWithData: %@", LOG_TAG, data);
    
    self = [super init];
    
    if (self) {
        _data = data;
    }
    return self;
}

- (void)writeBoolean:(BOOL)value {
    DDLogVerbose(@"%@ writeBoolean: %@", LOG_TAG, value ? @"YES" : @"NO");
    
    uint8_t lValue = value ? 1 : 0;
    [self.data appendBytes:&lValue length:sizeof(uint8_t)];
}

- (void)writeZero {
    DDLogVerbose(@"%@ writeZero", LOG_TAG);
    
    uint8_t value = 0;
    [self.data appendBytes:&value length:sizeof(uint8_t)];
}

- (void)writeInt:(int32_t)value {
    DDLogVerbose(@"%@ writeInt: %d", LOG_TAG, value);
    
    int length = [TLBinaryEncoder encodeWithInt:value buffer:_buffer];
    [self.data appendBytes:_buffer length:length];
}

- (void)writeLong:(int64_t)value {
    DDLogVerbose(@"%@ writeLong: %lld", LOG_TAG, value);
    
    int length = [TLBinaryEncoder encodeWithLong:value buffer:_buffer];
    [self.data appendBytes:_buffer length:length];
}

- (void)writeUUID:(nonnull NSUUID *)value {
    DDLogVerbose(@"%@ writeUUID: %@", LOG_TAG, value);
    
    int64_t leastSignificantBits = 0L;
    int64_t mostSignificantBits = 0L;
    uuid_t bytes;
    [value getUUIDBytes:bytes];
    int shift = 56;
    for (int i = 0; i < 8; i++) {
        int64_t lValue = bytes[i];
        mostSignificantBits |= (lValue & 0xFF) << shift;
        shift -= 8;
    }
    shift = 56;
    for (int i = 8; i < 16; i++) {
        int64_t lValue = bytes[i];
        leastSignificantBits |= (lValue & 0xFF) << shift;
        shift -= 8;
    }
    [self writeLong:leastSignificantBits];
    [self writeLong:mostSignificantBits];
}

- (void)writeOptionalUUID:(nullable NSUUID *)value {
    DDLogVerbose(@"%@ writeOptionalUUID: %@", LOG_TAG, value);

    if (value) {
        [self writeInt:1];
        [self writeUUID:value];
    } else {
        [self writeInt:0];
    }
}

- (void)writeFloat:(float)value {
    DDLogVerbose(@"%@ writeFloat: %f", LOG_TAG, value);

    union {
        int32_t u_int;
        float u_float;
    } v;
    
    // Convertion to take into account endianness.
    v.u_float = value;
    int8_t buffer[4];
    buffer[0] = v.u_int & 0x0FF;
    buffer[1] = (v.u_int >> 8) & 0x0FF;
    buffer[2] = (v.u_int >> 16) & 0x0FF;
    buffer[3] = (v.u_int >> 24) & 0x0FF;
    [self.data appendBytes:buffer length: sizeof(buffer)];
}

- (void)writeDouble:(double)value {
    DDLogVerbose(@"%@ writeDouble: %f", LOG_TAG, value);

    union {
        int64_t u_long;
        double u_double;
    } v;

    // Convertion to take into account endianness.
    v.u_double = value;
    int8_t buffer[8];
    int32_t first = (int32_t) v.u_long;
    int32_t second = (int32_t) (v.u_long >> 32);
    buffer[0] = first & 0x0FF;
    buffer[1] = (first >> 8) & 0x0FF;
    buffer[2] = (first >> 16) & 0x0FF;
    buffer[3] = (first >> 24) & 0x0FF;
    buffer[4] = second & 0x0FF;
    buffer[5] = (second >> 8) & 0x0FF;
    buffer[6] = (second >> 16) & 0x0FF;
    buffer[7] = (second >> 24) & 0x0FF;
    [self.data appendBytes:buffer length: sizeof(buffer)];
}

- (void)writeEnum:(int32_t)value {
    DDLogVerbose(@"%@ writeEnum: %d", LOG_TAG, value);
    
    [self writeInt:value];
}

- (void)writeString:(nonnull NSString *)value {
    DDLogVerbose(@"%@ writeString: %@", LOG_TAG, value);
    
    if (value.length == 0) {
        [self writeZero];
        return;
    }
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    int length = (int)data.length;
    [self writeInt:length];
    [self writeFixedWithData:data start:0 length:length];
}

- (void)writeOptionalString:(nullable NSString *)value {
    DDLogVerbose(@"%@ writeString: %@", LOG_TAG, value);

    if (value) {
        [self writeInt:1];
        [self writeString:value];
    } else {
        [self writeInt:0];
    }
}

- (void)writeData:(nonnull NSData *)data {
    DDLogVerbose(@"%@ writeData: %@", LOG_TAG, data);
    
    int length = (int)data.length;
    [self writeDataWithData:data start:0 length:length];
}

- (void)writeOptionalData:(nullable NSData *)data {
    DDLogVerbose(@"%@ writeOptionalData: %@", LOG_TAG, data);
    
    if (data) {
        [self writeInt:1];
        int length = (int)data.length;
        [self writeDataWithData:data start:0 length:length];
    } else {
        [self writeInt:0];
    }
}

- (void)writeDataWithData:(nonnull NSData *)data start:(int32_t)start length:(int32_t)length {
    DDLogVerbose(@"%@ writeDataWithData: %@ start: %d length: %d", LOG_TAG, data, start, length);
    
    if (length == 0) {
        [self writeZero];
        return;
    }
    [self writeInt:length];
    [self writeFixedWithData:data start:start length:length];
}

- (void)writeFixedWithData:(nonnull NSData *)data start:(int32_t)start length:(int32_t)length {
    DDLogVerbose(@"%@ writeFixedWithData: %@ start: %d length: %d", LOG_TAG, data, start, length);
    
    [self.data appendData:[data subdataWithRange:NSMakeRange(start, length)]];
}

- (void)writeAttribute:(nonnull TLAttributeNameValue *)attribute {
    DDLogVerbose(@"%@ writeAttribute: %@", LOG_TAG, attribute);

    [self writeString:attribute.name];
    if ([attribute isKindOfClass:[TLAttributeNameVoidValue class]]) {
        [self writeEnum:0];
    } else if ([attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
        [self writeEnum:1];
        [self writeBoolean:[(NSNumber *)attribute.value boolValue]];
    } else if ([attribute isKindOfClass:[TLAttributeNameLongValue class]]) {
        [self writeEnum:2];
        [self writeLong:[(NSNumber *)attribute.value longValue]];
    } else if ([attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
        [self writeEnum:3];
        [self writeString:(NSString *)attribute.value];
    } else if ([attribute isKindOfClass:[TLAttributeNameUUIDValue class]]) {
        [self writeEnum:4];
        [self writeUUID:(NSUUID *)attribute.value];
    } else if ([attribute isKindOfClass:[TLAttributeNameImageIdValue class]]) {
        [self writeEnum:4];
        [self writeUUID:((TLExportedImageId *)attribute.value).publicId];
    } else if ([attribute isKindOfClass:[TLAttributeNameListValue class]]) {
        [self writeEnum:5];
        [self writeAttributes:(NSArray<TLAttributeNameValue *> *)attribute.value];
    } else {
        @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
}

- (void)writeAttributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@ writeAttributes: %@", LOG_TAG, attributes);
    
    if (!attributes) {
        [self writeZero];
        return;
    }

    [self writeInt:(int)attributes.count];
    for (TLAttributeNameValue *attribute in attributes) {
        [self writeString:attribute.name];
        if ([attribute isKindOfClass:[TLAttributeNameVoidValue class]]) {
            [self writeEnum:0];
        } else  if ([attribute isKindOfClass:[TLAttributeNameBooleanValue class]]) {
            [self writeEnum:1];
            [self writeBoolean:[(NSNumber *)attribute.value boolValue]];
        } else  if ([attribute isKindOfClass:[TLAttributeNameLongValue class]]) {
            [self writeEnum:2];
            [self writeLong:[(NSNumber *)attribute.value longValue]];
        } else  if ([attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
            [self writeEnum:3];
            [self writeString:(NSString *)attribute.value];
        } else if ([attribute isKindOfClass:[TLAttributeNameUUIDValue class]]) {
            [self writeEnum:4];
            [self writeUUID:(NSUUID *)attribute.value];
        } else if ([attribute isKindOfClass:[TLAttributeNameImageIdValue class]]) {
            [self writeEnum:4];
            [self writeUUID:((TLExportedImageId *)attribute.value).publicId];
        } else if ([attribute isKindOfClass:[TLAttributeNameListValue class]]) {
            [self writeEnum:5];
            [self writeAttributes:(NSArray<TLAttributeNameValue *> *)attribute.value];
        } else {
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
        }
    }
}

@end

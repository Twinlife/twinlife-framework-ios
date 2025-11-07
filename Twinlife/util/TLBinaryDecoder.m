/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLBinaryDecoder.h"
#import "TLAttributeNameValue.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLBinaryDecoder
//

#undef LOG_TAG
#define LOG_TAG @"TLBinaryDecoder"

@implementation TLBinaryDecoder

- (nonnull instancetype)initWithData:(nonnull NSData *)data {
    DDLogVerbose(@"%@ initWithData: %@", LOG_TAG, data);
    
    self = [super init];
    
    if (self) {
        _data = data;
        _length = _data.length;
        _read = 0;
    }
    return self;
}

- (nullable NSString *)readIPv4 {
    
    long ipv4 = [self readLong];
    return [NSString stringWithFormat:@"%d.%d.%d.%d", (int) (ipv4 >> 24) & 0x0FF, (int) (ipv4 >> 16) & 0x0FF, (int) (ipv4 >> 8) & 0x0FF, (int) (ipv4) & 0x0FF];
}

- (nullable NSString *)readIPv6Part {

    long v = [self readLong];
    return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x", (int) (v >> 56) & 0x0FF, (int) (v >> 48) & 0x0FF, (int) (v >> 40) & 0x0FF, (int) (v >> 32) & 0x0FF, (int) (v >> 24) & 0x0FF, (int) (v >> 16) & 0x0FF, (int) (v >> 8) & 0x0FF, (int) (v) & 0x0FF];
}

- (nullable NSString *)readIPv6 {
    
    NSString *high = [self readIPv6Part];
    NSString *low = [self readIPv6Part];
    return [NSString stringWithFormat:@"%@:%@", high, low];
}

- (nullable NSString *)readIP {
    
    int kind = [self readInt];
    if ((kind & 0x01) == 0) {
        return [self readIPv4];
    } else {
        return [self readIPv6];
    }
}

- (BOOL)readBoolean {
    DDLogVerbose(@"%@ readBoolean", LOG_TAG);
    
    NSUInteger read = self.read + sizeof(uint8_t);
    if (read > self.length) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    uint8_t value = 0;
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(uint8_t))];
    self.read = read;
    return value == 1;
}

- (int32_t)readInt {
    DDLogVerbose(@"%@ readInt", LOG_TAG);
    
    int32_t value = 0;
    int shift = 0;
    do {
        NSUInteger read = self.read + sizeof(uint8_t);
        if (read > self.length) {
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
        }
        int8_t b = 0;
        [self.data getBytes:&b range:NSMakeRange(self.read, sizeof(int8_t))];
        self.read = read;
        value |= (((uint32_t)b) & 0x7F) << shift;
        if ((b & 0x80) == 0) {
            return (((uint32_t)value) >> 1) ^ -(value & 1);
        }
        shift += 7;
    } while (shift < 32);
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (int64_t)readLong {
    DDLogVerbose(@"%@ readLong", LOG_TAG);
    
    int64_t value = 0;
    int shift = 0;
    do {
        NSUInteger read = self.read + sizeof(uint8_t);
        if (read > self.length) {
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
        }
        int8_t b = 0;
        [self.data getBytes:&b range:NSMakeRange(self.read, sizeof(int8_t))];
        self.read = read;
        value |= (((uint64_t)b) & 0x7F) << shift;
        if ((b & 0x80) == 0) {
            return (((uint64_t)value) >> 1) ^ -(value & 1);
        }
        shift += 7;
    } while (shift < 64);
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

- (nonnull NSUUID *)readUUID {
    DDLogVerbose(@"%@ readUUID", LOG_TAG);
    
    int64_t leastSignificantBits = [self readLong];
    int64_t mostSignificantBits = [self readLong];
    uuid_t bytes;
    int shift = 56;
    for (int i = 0; i < 8; i++) {
        bytes[i] = (mostSignificantBits >> shift) & 0xFF;
        shift -= 8;
    }
    shift = 56;
    for (int i = 8; i < 16; i++) {
        bytes[i] = (leastSignificantBits >> shift) & 0xFF;
        shift -= 8;
    }
    return [[NSUUID alloc] initWithUUIDBytes:bytes];
}

- (nullable NSUUID *)readOptionalUUID {
    DDLogVerbose(@"%@ readOptionalUUID", LOG_TAG);

    if ([self readInt] == 1) {
        return [self readUUID];
    } else {
        return nil;
    }
}

- (float)readFloat {
    DDLogVerbose(@"%@ readFloat", LOG_TAG);
    
    union {
        int32_t u_long;
        float u_float;
    } v;
    int8_t buffer[sizeof(v)];
    
    NSUInteger read = self.read + sizeof(buffer);
    if (read > self.length || sizeof(buffer) != 4) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    [self.data getBytes:buffer range:NSMakeRange(self.read, sizeof(buffer))];
    self.read = read;
    
    v.u_long = (((int32_t) buffer[0]) & 0xff) | ((((int32_t) buffer[1]) & 0xff) << 8) |
    ((((int32_t) buffer[2]) & 0xff) << 16) | ((((int32_t) buffer[3]) & 0xff) << 24);
    
    return v.u_float;
}

- (double)readDouble {
    DDLogVerbose(@"%@ readDouble", LOG_TAG);

    union {
        int64_t u_long;
        double u_double;
    } v;
    int8_t buffer[sizeof(v)];

    NSUInteger read = self.read + sizeof(buffer);
    if (read > self.length || sizeof(buffer) != 8) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    [self.data getBytes:buffer range:NSMakeRange(self.read, sizeof(buffer))];
    self.read = read;

    v.u_long = (((int64_t) buffer[0]) & 0xff) | ((((int64_t) buffer[1]) & 0xff) << 8) |
    ((((int64_t) buffer[2]) & 0xff) << 16) | ((((int64_t) buffer[3]) & 0xff) << 24) |
    ((((int64_t) buffer[4]) & 0xff) << 32) | ((((int64_t) buffer[5]) & 0xff) << 40) |
    ((((int64_t) buffer[6]) & 0xff) << 48) | ((((int64_t) buffer[7]) & 0xff) << 56);

    return v.u_double;
}

- (int32_t)readEnum {
    DDLogVerbose(@"%@ readEnum", LOG_TAG);
    
    return [self readInt];
}

- (nonnull NSString *)readString {
    DDLogVerbose(@"%@ readString", LOG_TAG);
    
    int length = [self readInt];
    NSUInteger read = self.read + length;
    if (read > self.length) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    NSData *data = [self.data subdataWithRange:NSMakeRange(self.read, length)];
    NSString* value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.read = read;
    return value;
}

- (nullable NSString *)readOptionalString {
    DDLogVerbose(@"%@ readOptionalString", LOG_TAG);

    if ([self readInt] == 1) {
        return [self readString];
    } else {
        return nil;
    }
}

- (nonnull NSData *)readData {
    DDLogVerbose(@"%@ readData", LOG_TAG);
    
    int length = [self readInt];
    NSUInteger read = self.read + length;
    if (read > self.length) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    NSData * result = [self.data subdataWithRange:NSMakeRange(self.read, length)];
    self.read = read;
    return result;
}

- (nullable NSData *)readOptionalData {
    DDLogVerbose(@"%@ readOptionalData", LOG_TAG);

    if ([self readInt] == 1) {
        return [self readData];
    } else {
        return nil;
    }
}

- (void)readFixedWithData:(nonnull NSData *)data start:(int)start length:(int)length {
    DDLogVerbose(@"%@ readFixedWithData: %@ start: %d length: %d", LOG_TAG, data, start, length);
    
    // TBD
}

- (nullable NSMutableArray<TLAttributeNameValue *> *)readAttributes {
    DDLogVerbose(@"%@ TLAttributeNameValue", LOG_TAG);

    int count = [self readInt];
    if (count == 0) {
        return nil;
    }
    
    NSMutableArray<TLAttributeNameValue *> *result = [[NSMutableArray alloc] initWithCapacity:count];
    while (count > 0) {
        NSString *name = [self readString];
        TLAttributeNameValue *attribute;
        switch ([self readEnum]) {
            case 0:
                attribute = [[TLAttributeNameVoidValue alloc] initWithName:name];
                break;

            case 1:
                attribute = [[TLAttributeNameBooleanValue alloc] initWithName:name boolValue:[self readBoolean]];
                break;

            case 2:
                attribute = [[TLAttributeNameLongValue alloc] initWithName:name longValue:[self readLong]];
                break;

            case 3:
                attribute = [[TLAttributeNameStringValue alloc] initWithName:name stringValue:[self readString]];
                break;

            case 4:
                attribute = [[TLAttributeNameUUIDValue alloc] initWithName:name uuidValue:[self readUUID]];
                break;

            case 5:
                attribute = [[TLAttributeNameListValue alloc] initWithName:name listValue:[self readAttributes]];
                break;

            default:
                @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
        }

        [result addObject:attribute];
        count--;
    }
    return result;
}

@end

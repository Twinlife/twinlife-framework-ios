/*
 *  Copyright (c) 2015-2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDataInputStream.h"

static NSUUID *nullUUID;

//
// Interface(): TLDataInputStream
//

@interface TLDataInputStream()

@property NSData *data;
@property NSUInteger length;
@property NSUInteger read;
@property BOOL valid;

@end

//
// Implementation: TLDataInputStream
//

@implementation TLDataInputStream

+ (void)initialize {
    
    nullUUID = [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}

+ (BOOL)isNullUUID:(NSUUID *)uuid {
    
    if (!uuid) {
        return true;
    }
    return [nullUUID isEqual:uuid];
}

- (instancetype)initWithData:(NSData *)data {
    
    self = [super init];
    if (self) {
        _data = data;
        _length = _data.length;
        _read = 0;
        _valid = true;
    }
    return self;
}

- (int8_t)readInt8 {
    
    int8_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(int8_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(int8_t))];
    self.read = read;
    return value;
}

- (uint8_t)readUInt8 {
    
    uint8_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(uint8_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(uint8_t))];
    self.read = read;
    return value;
}

- (int16_t)readInt16 {
    
    int16_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(int16_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(int16_t))];
    self.read = read;
    return value;
}

- (uint16_t)readUInt16 {
    
    uint16_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(uint16_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(uint16_t))];
    self.read = read;
    return value;
}

- (int32_t)readInt32 {
    
    int32_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(int32_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(int32_t))];
    self.read = read;
    return value;
}

- (uint32_t)readUInt32 {
    
    uint32_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(uint32_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(uint32_t))];
    self.read = read;
    return value;
}

- (int64_t)readInt64 {
    
    int64_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(int64_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(int64_t))];
    self.read = read;
    return value;
}

- (uint64_t)readUInt64 {
    
    uint64_t value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(uint64_t);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(uint64_t))];
    self.read = read;
    return value;
}

- (int)readInt {
    
    int value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(int);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(int))];
    self.read = read;
    return value;
}

- (NSInteger)readInteger {
    
    NSInteger value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(NSInteger);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(NSInteger))];
    self.read = read;
    return value;
}

- (NSUInteger)readUInteger {
    
    NSUInteger value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(NSUInteger);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(NSUInteger))];
    self.read = read;
    return value;
}

- (double)readDouble {
    
    double value = 0;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(double);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(double))];
    self.read = read;
    return value;
}

- (BOOL)readBoolean {
    
    BOOL value = false;
    if (!self.valid) {
        return value;
    }
    NSUInteger read = self.read + sizeof(BOOL);
    if (read > self.length) {
        self.valid = false;
        return value;
    }
    [self.data getBytes:&value range:NSMakeRange(self.read, sizeof(BOOL))];
    self.read = read;
    return value;
}

- (NSUUID *)readUUID {
    
    uuid_t uuidBytes;
    memset(&uuidBytes, 0, sizeof(uuid_t));
    if (!self.valid) {
        return [[NSUUID alloc] initWithUUIDBytes:uuidBytes];
    }
    NSUInteger read = self.read + sizeof(uuid_t);
    if (read > self.length) {
        self.valid = false;
        return [[NSUUID alloc] initWithUUIDBytes:uuidBytes];
    }
    [self.data getBytes:&uuidBytes range:NSMakeRange(self.read, sizeof(uuid_t))];
    self.read = read;
    return [[NSUUID alloc] initWithUUIDBytes:uuidBytes];
}

- (NSString *)readString {
    
    if (!self.valid) {
        return @"";
    }
    NSUInteger length = [self readUInteger];
    NSUInteger read = self.read + length;
    if (!self.valid || read > self.length) {
        self.valid = false;
        return @"";
    }
    NSData *data = [self.data subdataWithRange:NSMakeRange(self.read, length)];
    NSString* value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.read = read;
    return value;
}

- (NSData *)readData {
    
    if (!self.valid) {
        return [NSData data];
    }
    NSUInteger length = [self readUInteger];
    NSUInteger read = self.read + length;
    if (!self.valid || read > self.length) {
        self.valid = false;
        return [NSData data];
    }
    NSData *value = [self.data subdataWithRange:NSMakeRange(self.read, length)];
    self.read = read;
    return value;
}

- (BOOL)isCompleted {
    
    return self.valid && self.read == self.length;
}

@end

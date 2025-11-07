/*
 *  Copyright (c) 2015-2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDataOutputStream.h"

//
// Interface(): TLDataOutputStream
//

@interface TLDataOutputStream()

@property (nonnull) NSMutableData *data;

@end

//
// Implementation: TLDataOutputStream
//

@implementation TLDataOutputStream

- (instancetype)init {
    
    self = [super init];
    
    _data = [[NSMutableData alloc] init];
    return self;
}

- (void)writeInt8:(int8_t)value {
    
    [self.data appendBytes:&value length:sizeof(int8_t)];
}

- (void)writeUInt8:(uint8_t)value {
    
    [self.data appendBytes:&value length:sizeof(uint8_t)];
}

- (void)writeInt16:(int16_t)value {
    
    [self.data appendBytes:&value length:sizeof(int16_t)];
}

- (void)writeUInt16:(uint16_t)value {
    
    [self.data appendBytes:&value length:sizeof(uint16_t)];
}

- (void)writeInt32:(int32_t)value {
    
    [self.data appendBytes:&value length:sizeof(int32_t)];
}

- (void)writeUInt32:(uint32_t)value {
    
    [self.data appendBytes:&value length:sizeof(uint32_t)];
}

- (void)writeInt64:(int64_t)value {
    
    [self.data appendBytes:&value length:sizeof(int64_t)];
}

- (void)writeUInt64:(uint64_t)value {
    
    [self.data appendBytes:&value length:sizeof(uint64_t)];
}

- (void)writeInt:(int)value {
    
    [self.data appendBytes:&value length:sizeof(int)];
}

- (void)writeInteger:(NSInteger)value {
    
    [self.data appendBytes:&value length:sizeof(NSInteger)];
}

- (void)writeUInteger:(NSUInteger)value {
    
    [self.data appendBytes:&value length:sizeof(NSUInteger)];
}

- (void)writeDouble:(double)value {

    [self.data appendBytes:&value length:sizeof(double)];
}

- (void)writeBoolean:(BOOL)value {
    
    [self.data appendBytes:&value length:sizeof(BOOL)];
}

- (void)writeUUID:(nonnull NSUUID *)value {
    
    uuid_t uuidBytes;
    memset(&uuidBytes, 0, sizeof(uuid_t));
    if (value) {
        [value getUUIDBytes:uuidBytes];
    }
    [self.data appendBytes:&uuidBytes length:sizeof(uuid_t)];
}

- (void)writeString:(nonnull NSString *)value {
    
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger length = data.length;
    [self writeUInteger:length];
    [self.data appendBytes:data.bytes length:length];
}

- (void)writeData:(nonnull NSData *)value {
    
    NSUInteger length = value.length;
    [self writeUInteger:length];
    [self.data appendBytes:value.bytes length:length];
}

- (nonnull NSData *)getData {
    
    return self.data;
}

@end

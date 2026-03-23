/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLCryptoDataOutput.h"
#import "TLCryptoBox.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLCryptoDataOutput ()
//

@interface TLCryptoDataOutput ()
@property (readonly, nonnull) TLCryptoBox *cryptoBox;
@property (readonly, nonnull) NSFileHandle *fileHandle;

@property (readonly, nonnull) NSMutableData *buffer;
@property int count;
@property uint64_t nonceSequence;
@end

//
// Implementation: TLCryptoDataOutput
//

#undef LOG_TAG
#define LOG_TAG @"TLCryptoDataOutput"

@implementation TLCryptoDataOutput

- (nonnull instancetype)initWithFileHandle:(nonnull NSFileHandle *)fileHandle size:(int)size cryptoBox:(nonnull TLCryptoBox *)cryptoBox {
    DDLogVerbose(@"%@ initWithFileHandle: %@", LOG_TAG, fileHandle);
    
    self = [super init];
    
    if (self) {
        _cryptoBox = cryptoBox;
        _fileHandle = fileHandle;
        
        _buffer = [[NSMutableData alloc] initWithLength:size];
        _count = 0;
        _nonceSequence = 0;
    }
    return self;
}

- (void)appendBytes:(nonnull const void *)bytes length:(NSUInteger)length {
    DDLogVerbose(@"%@ appendBytes, data length=%lu", LOG_TAG, (unsigned long)length);
    NSData * input = [NSData dataWithBytes:bytes length:length];
    [self appendData:input];
}

- (void)appendData:(nonnull NSData *)other {
    DDLogVerbose(@"%@ appendData, data length=%lu", LOG_TAG, (unsigned long)other.length);
    int off = 0;
    uint64_t length = other.length;
    while (length >= self.buffer.length) {
        [self flushBuffer];
        [self.buffer replaceBytesInRange:NSMakeRange(self.count, self.buffer.length) withBytes:[other subdataWithRange:NSMakeRange(off, self.buffer.length)].bytes];
        
        self.count = (int)self.buffer.length;
        off += self.buffer.length;
        length -= self.buffer.length;
    }
    
    if (length > self.buffer.length - self.count) {
        [self flushBuffer];
    }
    
    [self.buffer replaceBytesInRange:NSMakeRange(self.count, length) withBytes:[other subdataWithRange:NSMakeRange(off, length)].bytes];
    self.count += (int)length;
}

- (void)flushBuffer {
    DDLogVerbose(@"%@ flushBuffer, buffer length=%d", LOG_TAG, self.count);
    if (self.count > 0) {
        NSMutableData *auth = [[NSMutableData alloc] initWithCapacity:4 + 8];
        
        [auth appendData:[self dataFromInt:self.count]];
        [auth appendData:[self dataFromLong:self.nonceSequence]];
        
        NSMutableData *encrypted = [[NSMutableData alloc] initWithLength:auth.length + self.buffer.length + 64];
        int len = [self.cryptoBox encryptAEAD:self.nonceSequence data:[self.buffer subdataWithRange:NSMakeRange(0, self.count)] auth:auth output:encrypted];
        if (len <= 0) {
            //TODO BKP handle error
            DDLogError(@"%@ encryption failed: %d", LOG_TAG, len);
            return;
        }
        
        self.nonceSequence++;
        self.count = 0;
        
        [self writeDataToFileWithData:auth];
        [self writeDataToFileWithData:[self dataFromInt:len]];
        [self writeDataToFileWithData:[encrypted subdataWithRange:NSMakeRange(0, len)]];
    }
}

- (BOOL) writeDataToFileWithData:(nonnull NSData *)data {
    BOOL success;
    if (@available(iOS 13.0, *)) {
        __autoreleasing NSError *error = nil;
        success = [self.fileHandle writeData:data error:&error];
        
        //TODO BKP: handle error
        if (!success || error != nil) {
            DDLogError(@"%@ could not write auth: %@", LOG_TAG, error);
        }
    } else {
        @try {
            [self.fileHandle writeData:data];
            success = YES;
        } @catch (NSException *exception) {
            DDLogError(@"%@ could not write data to backup file: %@", LOG_TAG, exception);
            success = NO;
        }
    }
    
    DDLogVerbose(@"%@ writeDataToFileWithData, data length=%lu success=%@", LOG_TAG, (unsigned long)data.length, success ? @"YES" : @"NO");
    
    return success;
}


- (NSData *)dataFromLong:(int64_t)l {
    uint8_t result[8];
    for (int i = 7; i >= 0; i--) {
        result[i] = (uint8_t)(l & 0xFF);
        l >>= 8;
    }
    return [NSData dataWithBytes:result length:sizeof(result)];
}

- (NSData *)dataFromInt:(int)value {
    uint8_t result[4];
    for (int i = 3; i >= 0; i--) {
        result[i] = (uint8_t)(value & 0xFF);
        value >>= 8;
    }
    return [NSData dataWithBytes:result length:sizeof(result)];
}

@end

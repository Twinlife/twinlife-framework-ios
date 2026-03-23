/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLCryptoDataInput.h"
#import "TLCryptoBox.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLCryptoDataInput ()
//

@interface TLCryptoDataInput ()
@property (readonly, nonnull) TLCryptoBox *cryptoBox;
@property (readonly, nonnull) NSFileHandle *fileHandle;
@property (readonly) NSUInteger fileSize;

/// The current chunk of decrypted data
@property (nonnull) NSMutableData *buffer;
/// The current position in the underlying decrypted data, i.e. buffer[0] is byte number [pos] in the decrypted data.
@property int64_t pos;
@property int64_t lastPosRead;

- (BOOL)decryptBlock;

- (int)intFromData:(nonnull NSData *)data;

- (int64_t)longFromData:(nonnull NSData *)data;
@end

//
// Implementation: TLCryptoDataInput
//

#undef LOG_TAG
#define LOG_TAG @"TLCryptoDataInput"

@implementation TLCryptoDataInput

- (nonnull instancetype)initWithFileHandle:(nonnull NSFileHandle *)fileHandle cryptoBox:(nonnull TLCryptoBox *)cryptoBox {
    DDLogVerbose(@"%@ initWithFileHandle: %@", LOG_TAG, fileHandle);
    
    self = [super init];
    
    if (self) {
        _cryptoBox = cryptoBox;
        _fileHandle = fileHandle;
        
        _buffer = [[NSMutableData alloc] init];
        _pos = 0;
        _lastPosRead = 0;
        
        NSInteger currentOffset = fileHandle.offsetInFile;
        _fileSize = [fileHandle seekToEndOfFile] - currentOffset;
        [fileHandle seekToFileOffset:currentOffset];
    }
    return self;
}

- (NSUInteger)length {
    // Not the actual length of the decrypted data, but good enough approximation as far as TLBinaryDecoder is concerned.
    return self.fileSize;
}

- (BOOL)fullyRead {
    if (self.pos == -1) {
        return YES;
    }
    
    NSInteger currentOffset = self.fileHandle.offsetInFile;
    if ([self.fileHandle seekToEndOfFile] != currentOffset) {
        // File still has content to be read.
        [self.fileHandle seekToFileOffset:currentOffset];
        return NO;
    }
    
    // File is fully read, check the buffer
    if (self.pos + self.buffer.length > self.lastPosRead) {
        return NO;
    }
    
    return YES;
}

- (nonnull NSData *)subdataWithRange:(NSRange)range {
    NSMutableData *buffer = [[NSMutableData alloc] initWithLength:range.length];
    [self getBytes:buffer.mutableBytes range:range];
    return buffer;
}

- (void)getBytes:(void *)buffer range:(NSRange)range {
    int64_t rangeStart = range.location;
    int64_t rangeLength = range.length;
    
    if (rangeLength == 0) {
        return;
    }
    
    uint8_t *output = (uint8_t *)buffer;
    uint64_t read = 0;
    
    while (read < rangeLength) {
        int64_t blockEnd = self.pos + self.buffer.length;
        
        if (rangeStart < self.pos) {
            DDLogError(@"%@ backward seeking not supported. Requested location: %lld, current location: %lld", LOG_TAG, rangeStart, self.pos);
            @throw [NSException exceptionWithName:NSRangeException reason:@"backward seeking not supported" userInfo:nil];
        }
        
        while (rangeStart >= blockEnd) {
            BOOL decryptOK = [self decryptBlock];
            if (!decryptOK || self.pos == -1) {
                DDLogError(@"%@ Read/decrypt error. Requested location: %lld, data size= %lld", LOG_TAG, rangeStart, blockEnd);
                @throw [NSException exceptionWithName:NSRangeException reason:@"Read/decrypt error." userInfo:nil];
            }
            blockEnd = self.pos + self.buffer.length;
        }
        
        int64_t offset = rangeStart - self.pos;
        int64_t available = self.buffer.length - offset;
        int64_t length = MIN(rangeLength - read, available);
        
        if (length == 0) {
            break;
        }
        
        memcpy(output + read, self.buffer.bytes + offset, length);
        
        read += length;
        rangeStart += length;
    }
    
    self.lastPosRead = range.location + range.length;
}

-(void)close {
    [self.fileHandle closeFile];
}


// TODO BKP: handle errors
- (BOOL)decryptBlock {
    NSError *error;
    
    NSData *countData = [self readDataUpToLength:4 error:&error];
    if (!countData || error) {
        DDLogError(@"%@ could not read count: %@", LOG_TAG, error);
        return NO;
    }
    
    if (countData.length == 0) {
        //End of encrypted file
        DDLogError(@"%@ EOF reached", LOG_TAG);
        self.pos = -1;
        return NO;
    }
    
    int count = [self intFromData:countData];
    if (count <= 0) {
        DDLogError(@"%@ invalid decrypted data length: %d", LOG_TAG, count);
        return NO;
    }
    
    error = nil;
    NSData *nonceSequenceData = [self readDataUpToLength:8 error:&error];
    if (!nonceSequenceData || error) {
        DDLogError(@"%@ could not read nonceSequence: %@", LOG_TAG, error);
        return NO;
    }
    int64_t nonceSequence = [self longFromData:nonceSequenceData];
    if (nonceSequence < 0) {
        DDLogError(@"%@ invalid nonceSequence: %lld", LOG_TAG, nonceSequence);
        return NO;
    }
    
    error = nil;
    NSData *encryptedDataLength = [self readDataUpToLength:4 error:&error];
    if (!encryptedDataLength || error) {
        DDLogError(@"%@ could not read encrypted data length: %@", LOG_TAG, error);
        return NO;
    }
    int length = [self intFromData:encryptedDataLength];
    if (length <= 0) {
        DDLogError(@"%@ invalid encrypted data length: %d", LOG_TAG, length);
        return NO;
    }
    
    error = nil;
    NSData *encrypted = [self readDataUpToLength:length error:&error];
    
    if (encrypted.length != length || error) {
        DDLogError(@"%@ Error while reading encrypted data: expected: %d bytes, read: %d", LOG_TAG, length, (int)encrypted.length);
        return NO;
    }
    
    NSMutableData *decrypted = [[NSMutableData alloc] initWithLength:count];
    
    int decryptedLength = [self.cryptoBox decryptAEAD:nonceSequence data:encrypted authLength:(4+8) output:decrypted];
    
    if (decryptedLength <= 0 || decryptedLength != decrypted.length) {
        DDLogError(@"%@ error while decrypting data: %d", LOG_TAG, decryptedLength);
        return NO;
    }
    
    self.pos += self.buffer.length;
    self.buffer = decrypted;
    
    return YES;
}

- (nullable NSData *)readDataUpToLength:(int)length error:(out NSError **)error {
    if (@available(iOS 13.0, *)) {
        return [self.fileHandle readDataUpToLength:length error:error];
    } else {
        @try {
            return [self.fileHandle readDataOfLength:length];
        } @catch (NSException *exception) {

            *error = [NSError errorWithDomain:@"TLCryptoData" code:1 userInfo:exception.userInfo];
            return nil;
        }
    }
}

- (int)intFromData:(nonnull NSData *)data {
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    
    int result = 0;
    for (int i = 0; i < 4; i++) {
        result = (result << 8) | (bytes[i] & 0xFF);
    }
    
    return result;
}

- (int64_t)longFromData:(nonnull NSData *)data {
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    
    int64_t result = 0;
    for (int i = 0; i < 8; i++) {
        result = (result << 8) | (bytes[i] & 0xFF);
    }
    
    return result;
}
@end

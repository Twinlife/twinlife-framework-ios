/*
 *  Copyright (c) 2021-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <stdlib.h>
#import <libkern/OSAtomic.h>

#import <CocoaLumberjack.h>
#include <CommonCrypto/CommonDigest.h>

#import "TLTwinlifeImpl.h"
#import "TLSendingFileInfo.h"
#import "TLFileInfo.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLSendingFileInfo
//

@interface TLSendingFileInfo ()

@property (nullable) NSFileHandle *fileHandle;
@property int64_t position;
@property (nonnull, readonly) TLFileInfo* fileInfo;
@property CC_SHA256_CTX ctx;

@end

//
// Implementation: TLSendingFileInfo
//

#undef LOG_TAG
#define LOG_TAG @"TLSendingFileInfo"

@implementation TLSendingFileInfo

- (nonnull instancetype)initWithPath:(nonnull NSString *)path fileInfo:(nonnull TLFileInfo *)fileInfo{
    DDLogVerbose(@"%@ initWithPath: %@", LOG_TAG, path);
    
    self = [super init];
    if (self) {
        _fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
        _position = 0;
        _fileInfo = fileInfo;
        CC_SHA256_Init(&_ctx);

        // Position to the correct position reading the file and computing its checksum.
        if (fileInfo.remoteOffset > 0) {
            while (_position < fileInfo.remoteOffset) {
                long remain = fileInfo.remoteOffset - _position;
                if (remain > 64*1024) {
                    remain = 64*1024;
                }

                // We must use @autoreleasepool because when we read a large file (video file),
                // the data block of 64K is allocated and must be released immediately and not
                // by the GCD later (when we return and finish executing some dispatch_async).
                @autoreleasepool {
                    NSData *data = [_fileHandle readDataOfLength:remain];
                    if (data) {
                        _position = _position + data.length;
                        CC_SHA256_Update(&_ctx, [data bytes], (int)data.length);
                    } else {
                        break;
                    }
                }
            }
        }
    }
    return self;
}

- (NSData *)readChunkWithSize:(int)size position:(int64_t)position {
    DDLogVerbose(@"%@ readChunk: %d position: %lldd", LOG_TAG, size, position);

    if (self.position != position) {
        [self.fileHandle seekToFileOffset:position];
        self.position = position;
    }

    NSData *data = [self.fileHandle readDataOfLength:size];
    if (data) {
        self.position = self.position + data.length;
        CC_SHA256_Update(&_ctx, [data bytes], (int)data.length);
    }
    return data;
}

- (BOOL)isAcceptedDataChunkWithFileInfo:(nonnull TLFileInfo *)fileInfo offset:(int64_t)offset queueSize:(int64_t)queueSize {

    if (![self.fileInfo.index isEqualToNumber:fileInfo.index]) {
        return YES;
    }
    return self.position < offset + queueSize;
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    if (self.fileHandle) {
        [self.fileHandle closeFile];
        self.fileHandle = nil;
    }
}

- (BOOL)isFinished {
    return self.position == self.fileInfo.size;
}

- (int64_t) currentPosition {
    return self.position;
}

- (int)fileIndex {
    return self.fileInfo.fileId;
}

- (nonnull NSData *)digest {
    
    [self cancel];

    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash, &_ctx);

    NSData *sha256 = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
    return sha256;
}

@end

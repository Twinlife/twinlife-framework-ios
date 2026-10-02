/*
 *  Copyright (c) 2021-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <stdlib.h>
#import <libkern/OSAtomic.h>

#import <CocoaLumberjack.h>
#include <CommonCrypto/CommonDigest.h>

#import "TLTwinlifeImpl.h"
#import "TLReceivingFileInfo.h"
#import "TLFileInfo.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLReceivingFileInfo
//

@interface TLReceivingFileInfo ()

@property (nullable) NSFileHandle *fileHandle;
@property (nonnull, readonly) NSString *path;
@property (nonnull, readonly) TLFileInfo *fileInfo;
@property int64_t currentPosition;
@property CC_SHA256_CTX ctx;

@end

//
// Implementation: TLReceivingFileInfo
//

#undef LOG_TAG
#define LOG_TAG @"TLReceivingFileInfo"

@implementation TLReceivingFileInfo

- (nonnull instancetype)initWithPath:(nonnull NSString *)path {
    DDLogVerbose(@"%@ initWithPath: %@", LOG_TAG, path);
    
    self = [super init];
    if (self) {
        _path = path;
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        _currentPosition = 0;
        CC_SHA256_Init(&_ctx);
    }
    return self;
}

- (nonnull instancetype)initWithPath:(nonnull NSString *)path fileInfo:(nonnull TLFileInfo *)fileInfo offset:(int64_t)offset {
    DDLogVerbose(@"%@ initWithPath: %@ fileInfo: %@ offset: %lld", LOG_TAG, path, fileInfo, offset);
    
    self = [super init];
    if (self) {
        _path = path;
        _fileInfo = fileInfo;
        _currentPosition = 0;
        CC_SHA256_Init(&_ctx);

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *parentDir = [path stringByDeletingLastPathComponent];
        NSError *error = nil;
        if (![fileManager fileExistsAtPath:parentDir] && ![fileManager createDirectoryAtPath:parentDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogWarn(@"%@ Cannot create directory: %@ error: %@", LOG_TAG, parentDir, error);
        }

        // We are receiving a first block and the file exists: remove it so that we start a fresh file.
        NSDictionary<NSFileAttributeKey, id> *fileAttrs = [fileManager attributesOfItemAtPath:path error:nil];
        if (offset == 0 && fileAttrs && [fileAttrs fileSize] > 0) {
            DDLogWarn(@"%@ Removing old file %@", LOG_TAG, path);
            [fileManager removeItemAtPath:path error:nil];
        }

        // Open the file in read/write mode so that we can proceed after interruption.
        if (![fileManager fileExistsAtPath:path] && ![fileManager createFileAtPath:path contents:nil attributes:nil]) {
            DDLogError(@"%@ Cannot create file %@", LOG_TAG, path);
            return self;
        }
        _fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
        if (!_fileHandle) {
            return self;
        }

        // Setup to the correct position reading the file and computing its checksum.
        @try {
            int64_t fileSize = (int64_t)[_fileHandle seekToEndOfFile];
            if (fileSize > 0) {
                if (fileSize > offset) {
                    DDLogError(@"%@ Truncated file to %lld to continue receiving data", LOG_TAG, offset);
                    [_fileHandle truncateFileAtOffset:offset];
                    fileSize = offset;
                }

                [_fileHandle seekToFileOffset:0];
                while (_currentPosition < fileSize) {
                    int64_t remain = fileSize - _currentPosition;
                    if (remain > 64 * 1024) {
                        remain = 64 * 1024;
                    }

                    // We must use @autoreleasepool to release the 64K data block immediately (see TLSendingFileInfo).
                    @autoreleasepool {
                        NSData *data = [_fileHandle readDataOfLength:(NSUInteger)remain];
                        if (data.length == 0) {
                            break;
                        }
                        CC_SHA256_Update(&_ctx, [data bytes], (CC_LONG)data.length);
                        _currentPosition += data.length;
                        if (data.length != remain) {
                            DDLogError(@"%@ Read block too short missing %lld bytes", LOG_TAG, remain - (int64_t)data.length);
                            break;
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            DDLogError(@"%@ Cannot setup %@ at offset %lld: %@", LOG_TAG, path, offset, exception);
            [_fileHandle closeFile];
            _fileHandle = nil;
        }
    }
    return self;
}

- (BOOL)seekToFileOffset:(int64_t)position {
    DDLogVerbose(@"%@ seekToFileOffset: %lld", LOG_TAG, position);

    if (!self.fileHandle) {
        return NO;
    }
    if (position == LONG_MAX) {
        [self.fileHandle seekToEndOfFile];
        self.currentPosition = [self.fileHandle offsetInFile];
    } else {
        [self.fileHandle seekToFileOffset:position];
        self.currentPosition = position;
    }
    return YES;
}

- (int64_t)writeChunkWithData:(nonnull NSData *)data {
    DDLogVerbose(@"%@ writeChunkWithData: %@", LOG_TAG, data);

    if (!self.fileHandle) {
        return -1L;
    }
    [self.fileHandle writeData:data];
    self.currentPosition = [self.fileHandle offsetInFile];
    CC_SHA256_Update(&_ctx, [data bytes], (int)data.length);
    return self.currentPosition;
}

- (int64_t)position {
    
    return self.currentPosition;
}

- (BOOL)close {
    
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    return YES;
}

- (BOOL)close:(nonnull NSData *)sha256 {
    
    [self.fileHandle closeFile];
    self.fileHandle = nil;

    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(hash, &_ctx);

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *fileSha256 = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
    if (![sha256 isEqualToData:fileSha256]) {
        [fileManager removeItemAtPath:self.path error:nil];
        return NO;
    }

    if (self.fileInfo) {
        NSError *error;

        NSMutableDictionary<NSFileAttributeKey, id> *attributes = [[NSMutableDictionary alloc] init];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.fileInfo.date / 1000L];
        [attributes setObject:date forKey:NSFileCreationDate];
        [attributes setObject:date forKey:NSFileModificationDate];
        [fileManager setAttributes:attributes ofItemAtPath:self.path error:&error];
        if (error) {
            return NO;
        }
    }
    return YES;
}

- (void)cancel {
    DDLogVerbose(@"%@ cancel", LOG_TAG);

    if (self.fileHandle) {
        [self.fileHandle closeFile];
        self.fileHandle = nil;
    }
}

- (BOOL)isOpened {
    DDLogVerbose(@"%@ isOpened", LOG_TAG);

    return self.fileHandle != nil;
}

@end

/*
 *  Copyright (c) 2021-2024 twinlife SA.
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

- (nonnull instancetype)initWithPath:(nonnull NSString *)path fileInfo:(nonnull TLFileInfo *)fileInfo {
    DDLogVerbose(@"%@ initWithPath: %@ fileInfo: %@", LOG_TAG, path, fileInfo);
    
    self = [super init];
    if (self) {
        _path = path;
        _fileInfo = fileInfo;
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
        _currentPosition = 0;
        CC_SHA256_Init(&_ctx);
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

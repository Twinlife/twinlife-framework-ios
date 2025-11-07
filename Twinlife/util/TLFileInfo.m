/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLFileInfo.h"

@implementation TLFileInfo

- (nonnull instancetype)initWithFileId:(int)fileId path:(nonnull NSString *)path size:(long)size date:(long)date {
    
    self = [[TLFileInfo alloc] init];
    
    if (self) {
        _fileId = fileId;
        _path = path;
        _size = size;
        _date = date;
    }
    
    return self;
}

- (nonnull NSNumber *)index {
    return [[NSNumber alloc] initWithInt:self.fileId];
}

@end

@implementation TLFileState


- (nonnull instancetype)initWithFileId:(int)fileId offset:(long)offset {
    self = [[TLFileState alloc] init];
    
    if (self) {
        _fileId = fileId;
        _offset = offset;
    }
    
    return self;
}

- (nonnull NSNumber *)index {
    return [[NSNumber alloc] initWithInt:self.fileId];
}

@end

@implementation TLQueryInfo


- (nonnull instancetype)initWithDirectoryCount:(long)directoryCount fileCount:(long)fileCount maxFileSize:(long)maxFileSize totalFileSize:(long)totalFileSize databaseFileSize:(long)databaseFileSize localFileAvailableSize:(long)localFileAvailableSize localDatabaseAvailableSize:(long)localDatabaseAvailableSize {
    
    self = [[TLQueryInfo alloc] init];
    
    if (self) {
        _directoryCount = directoryCount;
        _fileCount = fileCount;
        _maxFileSize = maxFileSize;
        _totalFileSize = totalFileSize;
        _databaseFileSize = databaseFileSize;
        _localDatabaseAvailableSize = localDatabaseAvailableSize;
        _localFileAvailableSize = localFileAvailableSize;
    }
    
    return self;
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithFormat:@"[fileCount: %ld, dirCount: %ld, dbSize: %ld]", self.fileCount, self.directoryCount, self.databaseFileSize];
    return description;
}

@end

@implementation TLMigrationStatus


- (nonnull instancetype)initWithState:(TLAccountMigrationState)state isConnected:(BOOL)isConnected bytesSent:(long)bytesSent estimatedBytesRemainSend:(long)estimatedBytesRemainSend bytesReceived:(long)bytesReceived estimatedBytesRemainReceive:(long)estimatedBytesRemainReceive receiveErrorCount:(int)receiveErrorCount sendErrorCount:(int)sendErrorCount errorCode:(TLAccountMigrationErrorCode)errorCode {
    
    self = [[TLMigrationStatus alloc] init];
    
    if (self) {
        _state = state;
        _isConnected = isConnected;
        _bytesSent = bytesSent;
        _estimatedBytesRemainSend = estimatedBytesRemainSend;
        _bytesReceived = bytesReceived;
        _estimatedBytesRemainReceive = estimatedBytesRemainReceive;
        _receiveErrorCount = receiveErrorCount;
        _sendErrorCount = sendErrorCount;
        _errorCode = errorCode;
    }
    
    return self;
}

- (double)sendProgress {
    double total = self.bytesSent + self.estimatedBytesRemainSend;
    
    if (total == 0) {
        return 0;
    } else {
        return (self.bytesSent * 100.0) / total;
    }
}

- (double)receiveProgress {
    long total = self.bytesReceived + self.estimatedBytesRemainReceive;
    
    if (total == 0) {
        return 0;
    } else {
        return (self.bytesReceived * 100.0) / (double)total;
    }
}

- (double)progress {
    long total = self.bytesReceived + self.estimatedBytesRemainReceive + self.bytesSent + self.estimatedBytesRemainSend;
    
    if (total == 0) {
        return 0;
    } else {
        return ((self.bytesReceived + self.bytesSent) * 100.0) / (double)total;
    }

}

@end

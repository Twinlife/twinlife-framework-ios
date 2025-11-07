/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAccountMigrationService.h"

/// Information about a file that must be sent or received.
/// The path is relative to the application files directory.
@interface TLFileInfo : NSObject

@property (readonly) int fileId;
@property (readonly, nonnull) NSString *path;
@property (readonly) long date;
@property (readonly) long size;
@property long remoteOffset;

- (nonnull instancetype)initWithFileId:(int)fileId path:(nonnull NSString *)path size:(long)size date:(long)date;

- (nonnull NSNumber *)index;
@end


/// File state information as transmitted by the peer.
/// This indicates for a given file id, the current known size of that file on the peer.
@interface TLFileState : NSObject

@property (readonly) int fileId;
@property long offset;

- (nonnull instancetype)initWithFileId:(int)fileId offset:(long)offset;

- (nonnull NSNumber *)index;
@end

@interface TLQueryInfo: NSObject

@property (readonly) long directoryCount;
@property (readonly) long fileCount;
@property (readonly) long maxFileSize;
@property (readonly) long totalFileSize;
@property (readonly) long databaseFileSize;
@property (readonly) long localDatabaseAvailableSize;
@property (readonly) long localFileAvailableSize;

- (nonnull instancetype)initWithDirectoryCount:(long)directoryCount fileCount:(long)fileCount maxFileSize:(long)maxFileSize totalFileSize:(long)totalFileSize databaseFileSize:(long)databaseFileSize localFileAvailableSize:(long)localFileAvailableSize localDatabaseAvailableSize:(long)localDatabaseAvailableSize;

@end

@interface TLMigrationStatus : NSObject

@property (readonly) TLAccountMigrationState state;
@property (readonly) BOOL isConnected;
@property (readonly) long bytesSent;
@property (readonly) long estimatedBytesRemainSend;
@property (readonly) long bytesReceived;
@property (readonly) long estimatedBytesRemainReceive;
@property (readonly) int receiveErrorCount;
@property (readonly) int sendErrorCount;
@property (readonly) TLAccountMigrationErrorCode errorCode;

- (nonnull instancetype)initWithState:(TLAccountMigrationState)state isConnected:(BOOL)isConnected bytesSent:(long)bytesSent estimatedBytesRemainSend:(long)estimatedBytesRemainSend bytesReceived:(long)bytesReceived estimatedBytesRemainReceive:(long)estimatedBytesRemainReceive receiveErrorCount:(int)receiveErrorCount sendErrorCount:(int)sendErrorCount errorCode:(TLAccountMigrationErrorCode)errorCode;

- (double)sendProgress;

- (double)receiveProgress;

- (double)progress;
@end

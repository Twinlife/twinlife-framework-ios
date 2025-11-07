/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLFileInfo;

/**
 * A file that is being sent.  The file input stream remains open while we are sending it.
 * The SHA256 signature is computed while we read the input stream.
 * The signature is returned by getDigest() when the complete file was transferred.
 */

//
// Interface: TLSendingFileInfo ()
//

@interface TLSendingFileInfo : NSObject

/// Create the sending stream object.
- (nonnull instancetype)initWithPath:(nonnull NSString *)path fileInfo:(nonnull TLFileInfo *)fileInfo;

/// Read a block of data from the file stream and update the digest (raises and exception if there is a problem).
- (nullable NSData *)readChunkWithSize:(int)size position:(int64_t)position;

- (BOOL) isAcceptedDataChunkWithFileInfo:(nonnull TLFileInfo *)fileInfo offset:(int64_t)offset queueSize:(int64_t)queueSize;

/// Cancel sending the file.
- (void)cancel;

/// Check if we have transferred the complete file.
- (BOOL)isFinished;

- (int64_t)currentPosition;

- (int)fileIndex;

/// Close the sending file stream and return the SHA256 signature.
- (nonnull NSData *)digest;

@end

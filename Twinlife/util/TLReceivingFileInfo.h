/*
 *  Copyright (c) 2021-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

/**
 * A file that is being received.  The file output stream remains open while we are receiving it.
 * The SHA256 signature is computed while we write the output stream.
 * At the end, the close() method will verify the SHA256 signature.
 * If the signature is not correct, the file is removed and it must be transferred again.
 */

@class TLFileInfo;

//
// Interface: TLReceivingFileInfo ()
//

@interface TLReceivingFileInfo : NSObject

/// The file length.
@property (readonly) int64_t length;

/// Create the receiving stream object.
- (nonnull instancetype)initWithPath:(nonnull NSString *)path;

- (nonnull instancetype)initWithPath:(nonnull NSString *)path fileInfo:(nonnull TLFileInfo *)fileInfo;

/// Seek the receiving stream at the given position (raises an exception if there is a problem).
- (BOOL)seekToFileOffset:(int64_t)position;

/// Read a block of data from the file stream and update the digest (raises and exception if there is a problem).
- (int64_t)writeChunkWithData:(nonnull NSData *)data;

- (int64_t)position;

/// Close the receiving stream.
- (BOOL)close;

/// Close the receiving stream and verify the SHA256 signature.
///
/// If there is a write error, the file is removed.
/// If the signature is invalid, the file is removed.
/// If the signature is correct, the modification date is updated.
- (BOOL)close:(nonnull NSData *)sha256;

/// Cancel receiving the file.
- (void)cancel;

- (BOOL)isOpened;

@end

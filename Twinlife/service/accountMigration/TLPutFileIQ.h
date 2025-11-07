/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLPutFileIQSerializer
//

@interface TLPutFileIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPutFileIQ
//

@interface TLPutFileIQ : TLBinaryPacketIQ

@property (readonly) int fileId;
@property (readonly) int dataOffset;
@property (readonly) int64_t offset;
@property (readonly) int size;
@property (readonly, nullable) NSData *fileData;
@property (readonly, nullable) NSData *sha256;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId fileId:(int)fileId dataOffset:(int)dataOffset offset:(int64_t)offset size:(int)size fileData:(nullable NSData *)fileData sha256:(nullable NSData *)sha256;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq fileId:(int)fileId offset:(long)offset fileData:(nullable NSData *)fileData sha256:(nullable NSData *)sha256;

- (nonnull NSNumber *)fileIndex;

@end

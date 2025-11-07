/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"
#import "TLImageService.h"

//
// Interface: TLPutImageIQSerializer
//

@interface TLPutImageIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPutImageIQ
//

@interface TLPutImageIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *imageId;
@property (readonly) TLImageServiceKind kind;
@property (readonly) int64_t offset;
@property (readonly) int64_t totalSize;
@property (readonly, nonnull) NSData *imageData;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId imageId:(nonnull NSUUID *)imageId kind:(TLImageServiceKind)kind offset:(int64_t)offset totalSize:(int64_t)totalSize imageData:(nonnull NSData *)imageData;

@end

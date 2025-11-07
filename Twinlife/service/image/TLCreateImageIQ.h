/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLCreateImageIQSerializer
//

@interface TLCreateImageIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCreateImageIQ
//

@interface TLCreateImageIQ : TLBinaryPacketIQ

@property (readonly, nullable) NSData *imageSha;
@property (readonly, nullable) NSData *imageLargeSha;
@property (readonly, nonnull) NSData *thumbnailSha;
@property (readonly, nonnull) NSData *thumbnail;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId thumbnailSha:(nullable NSData *)thumbnailSha imageSha:(nullable NSData *)imageSha imageLargeSha:(nullable NSData *)imageLargeSha thumbnail:(nonnull NSData *)thumbnail;

- (long)bufferSize;

@end

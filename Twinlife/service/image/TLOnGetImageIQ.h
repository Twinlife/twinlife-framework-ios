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
// Interface: TLOnGetImageIQSerializer
//

@interface TLOnGetImageIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnGetImageIQ
//

@interface TLOnGetImageIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSData *imageData;
@property (readonly, nullable) NSData *imageSha;
@property (readonly) int64_t offset;
@property (readonly) int64_t totalSize;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq imageData:(nonnull NSData *)imageData offset:(int64_t)offset totalSize:(int64_t)totalSize imageSha:(nullable NSData *)imageSha;

@end

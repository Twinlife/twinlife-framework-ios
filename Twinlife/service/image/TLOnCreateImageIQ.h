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
// Interface: TLOnCreateImageIQSerializer
//

@interface TLOnCreateImageIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnCreateImageIQ
//

@interface TLOnCreateImageIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *imageId;
@property (readonly) int64_t chunkSize;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq imageId:(nonnull NSUUID *)imageId chunkSize:(int64_t)chunkSize;

@end

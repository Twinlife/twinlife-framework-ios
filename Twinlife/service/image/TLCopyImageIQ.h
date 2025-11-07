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
// Interface: TLCopyImageIQSerializer
//

@interface TLCopyImageIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLCopyImageIQ
//

@interface TLCopyImageIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *imageId;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId imageId:(nonnull NSUUID *)imageId;

@end

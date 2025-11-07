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
// Interface: TLGetImageIQSerializer
//

@interface TLGetImageIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLGetImageIQ
//

@interface TLGetImageIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *imageId;
@property (readonly) TLImageServiceKind kind;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId imageId:(nonnull NSUUID *)imageId kind:(TLImageServiceKind)kind;

@end

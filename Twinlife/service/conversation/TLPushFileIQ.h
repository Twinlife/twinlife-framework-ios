/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLFileDescriptor;

//
// Interface: TLPushFileIQSerializer
//

@interface TLPushFileIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLPushFileIQ
//

@interface TLPushFileIQ : TLBinaryPacketIQ

@property (readonly, nonnull) TLFileDescriptor *fileDescriptor;
@property (readonly, nullable) NSData *thumbnail;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_7;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_7;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor thumbnail:(nullable NSData *)thumbnail;

@end

/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"
#import "TLFileInfo.h"

//
// Interface: TLOnPutFileIQSerializer
//

@interface TLOnPutFileIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnPutFileIQ
//

@interface TLOnPutFileIQ : TLBinaryPacketIQ

@property (readonly) int fileId;
@property (readonly) long offset;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq fileId:(int)fileId offset:(long)offset;

@end

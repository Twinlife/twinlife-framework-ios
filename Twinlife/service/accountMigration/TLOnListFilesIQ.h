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
// Interface: TLOnListFilesIQSerializer
//

@interface TLOnListFilesIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnListFilesIQ
//

@interface TLOnListFilesIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSArray<TLFileState *> *files;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId files:(nonnull NSArray<TLFileState *> *)files;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq files:(nonnull NSArray<TLFileState *> *)files;

@end

/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

@class TLFileInfo;

//
// Interface: TLListFilesIQSerializer
//

@interface TLListFilesIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLListFilesIQ
//

@interface TLListFilesIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSArray<TLFileInfo *> *files;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId files:(nonnull NSArray<TLFileInfo *> *)files;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq files:(nonnull NSArray<TLFileInfo *> *)files;

@end

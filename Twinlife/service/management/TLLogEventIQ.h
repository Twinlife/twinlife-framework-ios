/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

@class TLEvent;

//
// Interface: TLLogEventIQSerializer
//

@interface TLLogEventIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLLogEventIQ
//

@interface TLLogEventIQ : TLBinaryPacketIQ

@property (readonly, nullable) NSArray<TLEvent *> *events;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId events:(nonnull NSArray<TLEvent *> *)events;

@end

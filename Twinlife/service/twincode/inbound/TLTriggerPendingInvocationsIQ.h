/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLTriggerPendingInvocationsIQSerializer
//

@interface TLTriggerPendingInvocationsIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLTriggerPendingInvocationsIQ
//

@interface TLTriggerPendingInvocationsIQ : TLBinaryPacketIQ

@property (readonly, nullable) NSArray<NSString *> *filters;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId filters:(nullable NSArray<NSString *> *)filters;

@end

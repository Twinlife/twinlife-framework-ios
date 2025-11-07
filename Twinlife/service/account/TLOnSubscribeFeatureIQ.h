/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryErrorPacketIQ.h"

//
// Interface: TLOnSubscribeFeatureIQSerializer
//

@interface TLOnSubscribeFeatureIQSerializer : TLBinaryErrorPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnSubscribeFeatureIQ
//

@interface TLOnSubscribeFeatureIQ : TLBinaryErrorPacketIQ

@property (readonly, nullable) NSString *features;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryErrorPacketIQ *)iq features:(nullable NSString *)features;

@end

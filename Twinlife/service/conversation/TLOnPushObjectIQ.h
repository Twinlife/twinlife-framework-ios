/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLOnPushIQ.h"

//
// Interface: TLOnPushObjectIQ
//

@interface TLOnPushObjectIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_3;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_3;

@end

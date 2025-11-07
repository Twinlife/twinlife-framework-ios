/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushIQ.h"

//
// Interface: TLOnUpdateAnnotationsIQ
//

@interface TLOnUpdateAnnotationsIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

@end

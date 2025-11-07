/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushIQ.h"

//
// Interface: TLOnResetConversationIQ
//

@interface TLOnResetConversationIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_3;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_3;

@end

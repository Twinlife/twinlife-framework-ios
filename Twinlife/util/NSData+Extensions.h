/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: NSData (Extensions)
//

@interface NSData (Extensions)

+ (nullable NSData *)secureRandomWithLength:(int)length;

@end

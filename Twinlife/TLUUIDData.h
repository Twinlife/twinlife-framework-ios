/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPrimitiveData.h"

//
// Interface: TLUUIDData
//

@interface TLUUIDData : TLPrimitiveData

- (nonnull instancetype)initWithName:(nonnull NSString *)name value:(nonnull NSUUID *)value;

@end

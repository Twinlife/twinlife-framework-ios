/*
 *  Copyright (c) 2014-2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLPrimitiveData.h"

//
// Interface: TLStringData
//

@interface TLStringData : TLPrimitiveData

- (instancetype)initWithName:(NSString *)name value:(NSString *)value;

@end

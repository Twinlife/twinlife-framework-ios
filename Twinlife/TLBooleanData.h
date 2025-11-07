/*
 *  Copyright (c) 2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 */

#import "TLPrimitiveData.h"

//
// Interface: TLBooleanData
//

@interface TLBooleanData : TLPrimitiveData

- (instancetype)initWithName:(NSString *)name value:(BOOL)value;

@end

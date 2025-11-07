/*
 *  Copyright (c) 2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

//
// Implementation: TLCDATAData
//

#import "TLData.h"

//
// Interface: TLCDATAData
//

@interface TLCDATAData : TLData

- (instancetype)initWithName:(NSString *)name value:(NSString *)value;

- (NSString *)stringValue;

@end

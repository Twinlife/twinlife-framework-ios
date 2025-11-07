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
// Interface(): TLPrimitiveData
//

@interface TLPrimitiveData ()

@property NSString *type;

- (instancetype)initWithName:(NSString *)name type:(NSString *)type value:(NSString *)value;

- (NSData *)bitmapValue;

- (BOOL)booleanValue;

- (int64_t)longValue;

- (NSString *)stringValue;

@end

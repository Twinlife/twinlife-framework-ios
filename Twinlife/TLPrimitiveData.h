/*
 *  Copyright (c) 2014-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLData.h"

//
// TLPrimitiveData
//

@interface TLPrimitiveData : TLData

- (NSData *)bitmapValue;

- (BOOL)booleanValue;

- (int64_t)longValue;

- (NSString *)stringValue;

- (NSUUID *)uuidValue;

@end

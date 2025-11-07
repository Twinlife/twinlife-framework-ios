/*
 *  Copyright (c) 2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLData.h"

//
// Interface: TLArrayData
//

@interface TLArrayData : TLData

- (instancetype)initWithName:(NSString *)name;

- (NSArray *)values;

- (void)setValues:(NSArray *)array;

- (void)addData:(TLData *)data;

- (void)addAttributes:(NSArray *)attributes;

- (NSArray *)attributes;

- (NSArray *)stringValues;

- (NSInteger)count;

@end

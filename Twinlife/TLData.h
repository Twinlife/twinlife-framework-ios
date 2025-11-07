/*
 *  Copyright (c) 2014-2015 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

//
// Interface: TLData
//

@interface TLData : NSObject {
}

@property NSString *name;

- (instancetype)initWithName:(NSString *)name value:(NSString *)value;

- (NSString *)type;

- (BOOL)isArrayData;

- (BOOL)isPrimitiveData;

- (BOOL)isRecordData;

- (BOOL)isVoidData;

- (BOOL)isCDATAData;

@end

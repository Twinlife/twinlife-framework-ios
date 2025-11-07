/*
 *  Copyright (c) 2022-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryEncoder.h"

//
// Interface: TLBinaryCompactEncoder
//

@interface TLBinaryCompactEncoder : TLBinaryEncoder

- (nonnull instancetype)initWithData:(nonnull NSMutableData *)data;

+ (nullable NSData *)serializeWithAttributes:(nullable NSArray<TLAttributeNameValue *> *)attributes;

@end

/*
 *  Copyright (c) 2022-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryDecoder.h"

//
// Interface: TLBinaryCompactDecoder
//

@interface TLBinaryCompactDecoder : TLBinaryDecoder

- (nonnull instancetype)initWithData:(nonnull NSData *)data;

+ (nullable NSMutableArray<TLAttributeNameValue *> *)deserializeWithData:(nullable NSData *)data;

@end

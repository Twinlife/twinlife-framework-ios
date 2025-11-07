/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDecoder.h"

//
// Interface: TLBinaryDecoder
//

@interface TLBinaryDecoder : NSObject <TLDecoder>

@property (readonly, nonnull) NSData *data;
@property (readonly) NSUInteger length;
@property NSUInteger read;

- (nonnull instancetype)initWithData:(nonnull NSData *)data;

- (nullable NSString *)readIP;

@end

/*
 *  Copyright (c) 2015-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLEncoder.h"

//
// Interface: TLBinaryEncoder
//

@interface TLBinaryEncoder : NSObject <TLEncoder>

@property (readonly, nonnull) NSMutableData *data;

- (nonnull instancetype)initWithData:(nonnull NSMutableData *)data;

- (void)writeAttribute:(nonnull TLAttributeNameValue *)attribute;

@end

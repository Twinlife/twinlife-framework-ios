/*
 *  Copyright (c) 2015-2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import "TLIQ.h"

//
// Interface: TLRequestIQSerialiser
//

@interface TLRequestIQSerializer : TLIQSerializer

@end

//
// Interface: TLRequestIQ
//

@interface TLRequestIQ : TLIQ

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to;

- (instancetype)initWithRequestIQ:(TLRequestIQ *)requestIQ;

@end

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
// Interface: TLResultIQSerialiser
//

@interface TLResultIQSerializer : TLIQSerializer

@end

//
// Interface: TLResultIQ
//

@interface TLResultIQ : TLIQ

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to;

- (instancetype)initWithTLResultIQ:(TLResultIQ *)resultIQ;

@end

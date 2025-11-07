/*
 *  Copyright (c) 2015-2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import "TLResultIQ.h"

//
// Interface: TLServiceResultIQSerializer
//

@interface TLServiceResultIQSerializer : TLResultIQSerializer

@end

//
// Interface: TLServiceResultIQSerializer_1
//

@interface TLServiceResultIQSerializer_1 : TLResultIQSerializer

@end

//
// Interface: TLServiceResultIQ
//

@interface TLServiceResultIQ : TLResultIQ

@property (readonly) int64_t requestId;
@property (readonly) NSString *service;
@property (readonly) NSString *action;
@property (readonly) int majorVersion;
@property (readonly) int minorVersion;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ;

@end

/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLRequestIQ.h"

//
// Interface: TLServiceRequestIQSerializer
//

@interface TLServiceRequestIQSerializer : TLRequestIQSerializer

@end

//
// Interface: TLServiceRequestIQSerializer_1
//

@interface TLServiceRequestIQSerializer_1 : TLRequestIQSerializer

@end

//
// Interface: TLServiceRequestIQ
//

@interface TLServiceRequestIQ : TLRequestIQ

@property (readonly) int64_t requestId;
@property (readonly) NSString *service;
@property (readonly) NSString *action;
@property (readonly) int majorVersion;
@property (readonly) int minorVersion;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ;

@end

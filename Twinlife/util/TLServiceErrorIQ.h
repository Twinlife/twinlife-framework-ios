/*
 *  Copyright (c) 2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLErrorIQ.h"

//
// Interface: TLServiceErrorIQSerializer
//

@interface TLServiceErrorIQSerializer : TLErrorIQSerializer

@end

//
// Interface: TLServiceErrorIQ
//

@interface TLServiceErrorIQ : TLErrorIQ

@property (readonly) int64_t requestId;
@property (readonly) NSString *service;
@property (readonly) NSString *action;
@property (readonly) int majorVersion;
@property (readonly) int minorVersion;

+ (NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to errorType:(TLErrorIQType)errorType condition:(NSString *)condition requestSchemaId:(NSUUID *)requestSchemaId requestSchemaVersion:(int)requestSchemaVersion requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

- (instancetype)initWithServiceErrorIQ:(TLServiceErrorIQ *)serviceErrorIQ;

@end

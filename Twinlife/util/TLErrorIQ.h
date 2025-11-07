/*
 *  Copyright (c) 2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLIQ.h"

//
// Interface: TLErrorIQSerialiser
//

@interface TLErrorIQSerializer : TLIQSerializer

@end

//
// Interface: TLErrorIQ
//

typedef enum {
    TLErrorIQTypeCancel, TLErrorIQTypeContinue, TLErrorIQTypeModify, TLErrorIQTypeAuth, TLErrorIQTypeWait
} TLErrorIQType;

#define TL_ERROR_IQ_BAD_REQUEST @"bad-request"
#define TL_ERROR_IQ_FEATURE_NOT_IMPLEMENTED @"feature-not-implemented"
#define TL_ERROR_IQ_GONE @"gone"
#define TL_ERROR_IQ_ITEM_NOT_FOUND @"item-not-found"

@interface TLErrorIQ : TLIQ

@property (readonly) TLErrorIQType errorType;
@property (readonly) NSString *condition;
@property (readonly) NSUUID *requestSchemaId;
@property (readonly) int requestSchemaVersion;

+ (NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to errorType:(TLErrorIQType)errorType condition:(NSString *)condition requestSchemaId:(NSUUID *)requestSchemaId requestSchemaVersion:(int)requestSchemaVersion;

- (instancetype)initWithTLErrorIQ:(TLErrorIQ *)errorIQ;

- (void)appendTo:(NSMutableString*)string;

@end

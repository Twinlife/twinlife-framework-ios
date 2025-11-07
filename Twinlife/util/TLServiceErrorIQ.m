/*
 *  Copyright (c) 2016-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLServiceErrorIQ.h"
#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * <pre>
 *
 * Schema version 1
 *  Date: 2016/09/12
 *
 * {
 *  "type":"record",
 *  "name":"ServiceErrorIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.ErrorIQ"
 *  "fields":
 *  [
 *   {"name":"requestId", "type":"long"}
 *   {"name":"service", "type":"string"},
 *   {"name":"action", "type":"string"}
 *   {"name":"majorVersion", "type":"int"}
 *   {"name":"minorVersion", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLServiceErrorIQ ()
//

@interface TLServiceErrorIQ ()

- (instancetype)initWithErrorIQ:(TLErrorIQ *)errorIQ requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

@end

//
// Implementation: TLServiceErrorIQSerializer
//

static NSUUID *SERVICE_ERROR_IQ_SCHEMA_ID = nil;
static int SERVICE_ERROR_IQ_SCHEMA_VERSION = 1;
static TLSerializer *SERVICE_ERROR_IQ_SERIALIZER = nil;

@implementation TLServiceErrorIQSerializer

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLServiceErrorIQ *serviceErrorIQ = (TLServiceErrorIQ *)object;
    [encoder writeLong:serviceErrorIQ.requestId];
    [encoder writeString:serviceErrorIQ.service];
    [encoder writeString:serviceErrorIQ.action];
    [encoder writeInt:serviceErrorIQ.majorVersion];
    [encoder writeInt:serviceErrorIQ.minorVersion];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLErrorIQ *errorIQ = (TLErrorIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t requestId = [decoder readLong];
    NSString *service = [decoder readString];
    NSString *action = [decoder readString];
    int majorVersion = [decoder readInt];
    int minorVersion = [decoder readInt];
    
    return [[TLServiceErrorIQ alloc] initWithErrorIQ:errorIQ requestId:requestId service:service action:action majorVersion:majorVersion minorVersion:minorVersion];
}

@end

//
// Implementation: TLServiceErrorIQ
//

@implementation TLServiceErrorIQ

+ (void)initialize {
    
    SERVICE_ERROR_IQ_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"6548c8a9-3a68-45da-a26e-e82b1630c321"];
    SERVICE_ERROR_IQ_SERIALIZER = [[TLServiceErrorIQSerializer alloc] initWithSchemaId:SERVICE_ERROR_IQ_SCHEMA_ID schemaVersion:SERVICE_ERROR_IQ_SCHEMA_VERSION class:[TLServiceErrorIQ class]];
}

+ (NSUUID *)SCHEMA_ID {
    
    return SERVICE_ERROR_IQ_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return SERVICE_ERROR_IQ_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return SERVICE_ERROR_IQ_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to errorType:(TLErrorIQType)errorType condition:(NSString *)condition requestSchemaId:(NSUUID *)requestSchemaId requestSchemaVersion:(int)requestSchemaVersion requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    self = [super initWithId:id from:from to:to errorType:errorType condition:condition requestSchemaId:requestSchemaId requestSchemaVersion:requestSchemaVersion];
    
    if (self) {
        _requestId = requestId;
        _service = service;
        _action = action;
        _majorVersion = majorVersion;
        _minorVersion = minorVersion;
    }
    return self;
}

- (instancetype)initWithServiceErrorIQ:(TLServiceErrorIQ *)serviceErrorIQ {
    
    self = [super initWithTLErrorIQ:serviceErrorIQ];
    
    if (self) {
        _requestId = serviceErrorIQ.requestId;
        _service = serviceErrorIQ.service;
        _action = serviceErrorIQ.action;
        _majorVersion = serviceErrorIQ.majorVersion;
        _minorVersion = serviceErrorIQ.minorVersion;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" requestId:    %lld\n", self.requestId];
    [string appendFormat:@" service:      %@\n", self.service];
    [string appendFormat:@" action:       %@\n", self.action];
    [string appendFormat:@" majorVersion: %d\n", self.majorVersion];
    [string appendFormat:@" minorVersion: %d\n", self.minorVersion];
}

#pragma - mark NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLServiceErrorIQ\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLServiceErrorIQ ()

- (instancetype)initWithErrorIQ:(TLErrorIQ *)errorIQ requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    self = [super initWithTLErrorIQ:errorIQ];
    
    if (self) {
        _requestId = requestId;
        _service = service;
        _action = action;
        _majorVersion = majorVersion;
        _minorVersion = minorVersion;
    }
    return self;
}

@end

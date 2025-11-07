/*
 *  Copyright (c) 2015-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLServiceRequestIQ.h"
#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * <pre>
 *
 * Schema version 2
 *  Date: 2016/10/10
 *
 * {
 *  "type":"record",
 *  "name":"ServiceRequestIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.RequestIQ"
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
 *
 * Schema version 1
 *
 * {
 *  "type":"record",
 *  "name":"ServiceRequestIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.RequestIQ"
 *  "fields":
 *  [
 *   {"name":"requestId", "type":"long"}
 *   {"name":"service", "type":"string"},
 *   {"name":"action", "type":"string"}
 *   {"name":"version", "type":"string"}
 *  ]
 * }
 *
 * </pre>
 */

static TLSerializer *SERVICE_REQUEST_SERIALIZER = nil;

//
// Interface: TLServiceRequestIQ ()
//

@interface TLServiceRequestIQ ()

- (instancetype)initWithRequestIQ:(TLRequestIQ *)requestIQ requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

@end

//
// Implementation: TLServiceRequestIQSerializer
//

@implementation TLServiceRequestIQSerializer

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)object;
    [encoder writeLong:serviceRequestIQ.requestId];
    [encoder writeString:serviceRequestIQ.service];
    [encoder writeString:serviceRequestIQ.action];
    [encoder writeInt:serviceRequestIQ.majorVersion];
    [encoder writeInt:serviceRequestIQ.minorVersion];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLRequestIQ *requestIQ = (TLRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t requestId = [decoder readLong];
    NSString *service = [decoder readString];
    NSString *action = [decoder readString];
    int majorVersion = [decoder readInt];
    int minorVersion = [decoder readInt];
    
    return [[TLServiceRequestIQ alloc] initWithRequestIQ:requestIQ requestId:requestId service:service action:action majorVersion:majorVersion minorVersion:minorVersion];
}

@end

//
// Implementation: TLServiceRequestIQSerializer_1
//

@implementation TLServiceRequestIQSerializer_1

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLServiceRequestIQ *serviceRequestIQ = (TLServiceRequestIQ *)object;
    [encoder writeLong:serviceRequestIQ.requestId];
    [encoder writeString:serviceRequestIQ.service];
    [encoder writeString:serviceRequestIQ.action];
    [encoder writeString:@"1.0.0"];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLRequestIQ *requestIQ = (TLRequestIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int64_t requestId = [decoder readLong];
    NSString *service = [decoder readString];
    NSString *action = [decoder readString];
    // unused version
    [decoder readString];
    int majorVersion = 1;
    int minorVersion = 0;
    
    return [[TLServiceRequestIQ alloc] initWithRequestIQ:requestIQ requestId:requestId service:service action:action majorVersion:majorVersion minorVersion:minorVersion];
}

@end

//
// Implementation: TLServiceRequestIQ
//

@implementation TLServiceRequestIQ

+ (void)initialize {
    
    SERVICE_REQUEST_SERIALIZER = [[TLServiceRequestIQSerializer alloc] init];
}

+ (TLSerializer *)SERIALIZER {

    return SERVICE_REQUEST_SERIALIZER;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    self = [super initWithFrom:from to:to];
    if (self) {
        _requestId = requestId;
        _service = service;
        _action = action;
        _majorVersion = majorVersion;
        _minorVersion = minorVersion;
    }
    return self;
}

- (instancetype)initWithServiceRequestIQ:(TLServiceRequestIQ *)serviceRequestIQ {
    
    self = [super initWithRequestIQ:serviceRequestIQ];
    if (self) {
        _requestId = serviceRequestIQ.requestId;
        _service = serviceRequestIQ.service;
        _action = serviceRequestIQ.action;
        _majorVersion = serviceRequestIQ.majorVersion;
        _minorVersion = serviceRequestIQ.minorVersion;
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

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLServiceRequestIQ\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLServiceRequestIQ ()

- (instancetype)initWithRequestIQ:(TLRequestIQ *)requestIQ requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    self = [super initWithRequestIQ:requestIQ];
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

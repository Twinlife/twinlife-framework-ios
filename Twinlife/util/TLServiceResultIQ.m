/*
 *  Copyright (c) 2015-2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLServiceResultIQ.h"
#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * <pre>
 *
 * Schema version 2
 *  Date: 2016/10/11
 *
 * {
 *  "type":"record",
 *  "name":"ServiceResultIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.ResultIQ"
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
 * Schema version 1
 *
 * {
 *  "type":"record",
 *  "name":"ServiceResultIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.ResultIQ"
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

//
// Interface: TLServiceResultIQ ()
//

@interface TLServiceResultIQ ()

- (instancetype)initWithResultIQ:(TLResultIQ *)resultIQ requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion;

@end

//
// Implementation: TLServiceResultIQSerializer
//

@implementation TLServiceResultIQSerializer

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)object;
    [encoder writeLong:serviceResultIQ.requestId];
    [encoder writeString:serviceResultIQ.service];
    [encoder writeString:serviceResultIQ.action];
    [encoder writeInt:serviceResultIQ.majorVersion];
    [encoder writeInt:serviceResultIQ.minorVersion];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLResultIQ *resultIQ = (TLResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    int64_t requestId = [decoder readLong];
    NSString *service = [decoder readString];
    NSString *action = [decoder readString];
    int majorVersion = [decoder readInt];
    int minorVersion = [decoder readInt];
    
    return [[TLServiceResultIQ alloc] initWithResultIQ:resultIQ requestId:requestId service:service action:action majorVersion:majorVersion minorVersion:minorVersion];
}

@end

//
// Implementation: TLServiceTLResultIQSerializer_1
//

@implementation TLServiceResultIQSerializer_1

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    TLServiceResultIQ *serviceResultIQ = (TLServiceResultIQ *)object;
    [encoder writeLong:serviceResultIQ.requestId];
    [encoder writeString:serviceResultIQ.service];
    [encoder writeString:serviceResultIQ.action];
    [encoder writeString:@"1.0.0"];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLResultIQ *resultIQ = (TLResultIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    int64_t requestId = [decoder readLong];
    NSString *service = [decoder readString];
    NSString *action = [decoder readString];
    // unused version
    [decoder readString];
    int majorVersion = 1;
    int minorVersion = 0;
    
    return [[TLServiceResultIQ alloc] initWithResultIQ:resultIQ requestId:requestId service:service action:action majorVersion:majorVersion minorVersion:minorVersion];
}

@end

//
// Implementation: TLServiceResultIQ
//

@implementation TLServiceResultIQ

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion{
    
    self = [super initWithId:id from:from to:to];
    if (self) {
        _requestId = requestId;
        _service = service;
        _action = action;
        _majorVersion = majorVersion;
        _minorVersion = minorVersion;
    }
    return self;
}

- (instancetype)initWithServiceResultIQ:(TLServiceResultIQ *)serviceResultIQ {
    
    self = [super initWithTLResultIQ:serviceResultIQ];
    if (self) {
        _requestId = serviceResultIQ.requestId;
        _service = serviceResultIQ.service;
        _action = serviceResultIQ.action;
        _majorVersion = serviceResultIQ.majorVersion;
        _minorVersion = serviceResultIQ.minorVersion;
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
    [string appendString:@"TLServiceResultIQ\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLServiceResultIQ ()

- (instancetype)initWithResultIQ:(TLResultIQ *)resultIQ requestId:(int64_t)requestId service:(NSString *)service action:(NSString *)action majorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    self = [super initWithTLResultIQ:resultIQ];
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

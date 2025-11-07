/*
 *  Copyright (c) 2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLErrorIQ.h"
#import "TLEncoder.h"
#import "TLDecoder.h"

/**
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "type":"enum",
 *  "name":"ErrorIQType",
 *  "namespace":"org.twinlife.schemas",
 *  "symbols" : ["CANCEL", "CONTINUE", "MODIFY", "AUTH", "WAIT"]
 * }
 *
 * {
 *  "type":"record",
 *  "name":"ErrorIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.IQ"
 *  "fields":
 *  [
 *   {"name":"errorType", "type":"org.twinlife.schemas.ErrorIQType"}
 *   {"name":"condition", "type":"string"}
 *   {"name":"requestSchemaId", "type":"uuid"},
 *   {"name":"requestSchemaVersion", "type":"int"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Interface: TLErrorIQ ()
//

@interface TLErrorIQ ()

- (instancetype)initWithIQ:(TLIQ *)iq errorType:(TLErrorIQType)errorType condition:(NSString *)condition requestSchemaId:(NSUUID *)requestSchemaId requestSchemaVersion:(int)requestSchemaVersion;

@end

//
// Implementation: TLErrorIQSerializer
//

static NSUUID *ERROR_IQ_SCHEMA_ID = nil;
static int ERROR_IQ_SCHEMA_VERSION = 1;
static TLSerializer *ERROR_IQ_SERIALIZER = nil;

@implementation TLErrorIQSerializer

- (instancetype)init {
    
    self = [super initWithSchemaId:TLErrorIQ.SCHEMA_ID schemaVersion:TLErrorIQ.SCHEMA_VERSION class:[TLErrorIQSerializer class]];
    
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLErrorIQ *errorIQ = (TLErrorIQ *)object;
    switch (errorIQ.errorType) {
        case TLErrorIQTypeCancel:
            [encoder writeEnum:0];
            break;
        case TLErrorIQTypeContinue:
            [encoder writeEnum:1];
            break;
        case TLErrorIQTypeModify:
            [encoder writeEnum:2];
            break;
        case TLErrorIQTypeAuth:
            [encoder writeEnum:3];
            break;
        case TLErrorIQTypeWait:
            [encoder writeEnum:4];
            break;
    }
    [encoder writeString:errorIQ.condition];
    [encoder writeUUID:errorIQ.requestSchemaId];
    [encoder writeInt:errorIQ.requestSchemaVersion];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLIQ *iq = (TLIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    int value = [decoder readEnum];
    TLErrorIQType errorType;
    switch (value) {
        case 0:
            errorType = TLErrorIQTypeCancel;
            break;
        case 1:
            errorType = TLErrorIQTypeContinue;
            break;
        case 2:
            errorType = TLErrorIQTypeModify;
            break;
        case 3:
            errorType = TLErrorIQTypeAuth;
            break;
        case 4:
            errorType = TLErrorIQTypeWait;
            break;
        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    NSString *condition = [decoder readString];
    NSUUID *requestSchemaId = [decoder readUUID];
    int requestSchemaVersion = [decoder readInt];
    return [[TLErrorIQ alloc] initWithIQ:iq errorType:errorType condition:condition requestSchemaId:requestSchemaId requestSchemaVersion:requestSchemaVersion];
}

@end

//
// Implementation: TLErrorIQ
//

@implementation TLErrorIQ

+ (void)initialize {
    
    ERROR_IQ_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"982ca04e-5b94-4382-acda-b710973b9a04"];
    ERROR_IQ_SERIALIZER = [[TLErrorIQSerializer alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return ERROR_IQ_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return ERROR_IQ_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return ERROR_IQ_SERIALIZER;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to errorType:(TLErrorIQType)errorType condition:(NSString *)condition requestSchemaId:(NSUUID *)requestSchemaId requestSchemaVersion:(int)requestSchemaVersion {
    
    self = [super initWithId:id from:from to:to type:TLIQTypeError];
    
    if (self) {
        _errorType = errorType;
        _condition = condition;
        _requestSchemaId = requestSchemaId;
        _requestSchemaVersion = requestSchemaVersion;
    }
    return self;
}

- (instancetype)initWithTLErrorIQ:(TLErrorIQ *)errorIQ {
    
    self = [super initWithIQ:errorIQ];
    
    if (self) {
        _errorType = errorIQ.errorType;
        _condition = errorIQ.condition;
        _requestSchemaId = errorIQ.requestSchemaId;
        _requestSchemaVersion = errorIQ.requestSchemaVersion;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" errorType: %u\n", self.errorType];
    [string appendFormat:@" condition: %@\n", self.condition];
    [string appendFormat:@" requestSchemaId: %@\n", [self.requestSchemaId UUIDString]];
    [string appendFormat:@" requestSchemaVersion: %d\n", self.requestSchemaVersion];
}

#pragma - mark NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLErrorIQ\n"];
    [self appendTo:string];
    return string;
}

#pragma - mark TLErrorIQ ()

- (instancetype)initWithIQ:(TLIQ *)iq errorType:(TLErrorIQType)errorType condition:(NSString *)condition requestSchemaId:(NSUUID *)requestSchemaId requestSchemaVersion:(int)requestSchemaVersion {
    
    self = [super initWithIQ:iq];
    
    if (self) {
        _errorType = errorType;
        _condition = condition;
        _requestSchemaId = requestSchemaId;
        _requestSchemaVersion = requestSchemaVersion;
    }
    return self;
}

@end

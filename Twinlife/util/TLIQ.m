/*
 *  Copyright (c) 2015-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#include <stdlib.h>
#include <stdatomic.h>

#import "TLIQ.h"
#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "type":"enum",
 *  "name":"IQType",
 *  "namespace":"org.twinlife.schemas",
 *  "symbols" : ["SET", "GET", "RESULT", "ERROR"]
 * }
 *
 * {
 *  "type":"record",
 *  "name":"IQ",
 *  "namespace":"org.twinlife.schemas",
 *  "fields":
 *  [
 *   {"name":"schemaId", "type":"uuid"},
 *   {"name":"schemaVersion", "type":"int"}
 *   {"name":"id", "type":"string"}
 *   {"name":"from", "type":"string"}
 *   {"name":"to", "type":"string"}
 *   {"name":"type", "type":"org.twinlife.schemas.IQType"}
 *  ]
 * }
 *
 * </pre>
 */

static NSUUID *IQ_SCHEMA_ID = nil;
static int IQ_SCHEMA_VERSION = 1;
static TLSerializer *IQ_SERIALIZER = nil;

//
// Implementation: TLIQSerializer
//

@implementation TLIQSerializer

+ (void)initialize {
    
    IQ_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"7866f017-62b6-4c3f-8c55-711f48aae233"];
    IQ_SERIALIZER = [[TLIQSerializer alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return IQ_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return IQ_SCHEMA_VERSION;
}

+ (TLSerializer *)SERIALIZER {
    
    return IQ_SERIALIZER;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLIQ *iq = (TLIQ *)object;
    [encoder writeString:iq.id];
    [encoder writeString:iq.from];
    [encoder writeString:iq.to];
    switch (iq.type) {
        case TLIQTypeSet:
            [encoder writeEnum:0];
            break;
        case TLIQTypeGet:
            [encoder writeEnum:1];
            break;
        case TLIQTypeResult:
            [encoder writeEnum:2];
            break;
        case TLIQTypeError:
            [encoder writeEnum:3];
            break;
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    NSString *id = [decoder readString];
    NSString *from = [decoder readString];
    NSString *to = [decoder readString];
    int value = [decoder readEnum];
    TLIQType type;
    switch (value) {
        case 0:
            type = TLIQTypeSet;
            break;
        case 1:
            type = TLIQTypeGet;
            break;
        case 2:
            type = TLIQTypeResult;
            break;
        case 3:
            type = TLIQTypeError;
            break;
        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    return [[TLIQ alloc]initWithId:id from:from to:to type:type];
}

@end

//
// Implementation: TLIQ
//

static atomic_int ID;

@implementation TLIQ

+ (void)initialize {
    
    ID = 0L;
}

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to type:(TLIQType)type {
    
    self = [super init];
    if (self) {
        NSMutableString* string = [NSMutableString stringWithCapacity:256];
        [string appendFormat:@"%x", arc4random()];
        [string appendFormat:@"%x", atomic_fetch_add(&ID, 1)];
        _id = string;
        _from = from;
        _to = to;
        _type = type;
    }
    return self;
}

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to type:(TLIQType)type {
    
    self = [super init];
    if (self) {
        _id = id;
        _from = from;
        _to = to;
        _type = type;
    }
    return self;
}

- (instancetype)initWithIQ:(TLIQ *)iq {
    
    self = [super init];
    if (self) {
        _id = iq.id;
        _from = iq.from;
        _to = iq.to;
        _type = iq.type;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {
    
    [string appendFormat:@" id:   %@\n", self.id];
    [string appendFormat:@" from: %@\n", self.from];
    [string appendFormat:@" to:   %@\n", self.to];
    [string appendFormat:@" type: %u\n", self.type];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLIQ\n"];
    [self appendTo:string];
    return string;
}

@end

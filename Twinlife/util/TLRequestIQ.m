/*
 *  Copyright (c) 2015-2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import "TLRequestIQ.h"

/**
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "type":"record",
 *  "name":"RequestIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.IQ"
 *  "fields":
 *  []
 * }
 *
 * </pre>
 */

//
// Implementation: TLRequestIQSerializer
//

@implementation TLRequestIQSerializer

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLIQ *iq = (TLIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    return [[TLRequestIQ alloc] initWithIQ:iq];
}

@end

//
// Implementation: TLRequestIQ
//

@implementation TLRequestIQ

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to {
    
    self = [super initWithFrom:from to:to type:TLIQTypeSet];
    return self;
}

- (instancetype)initWithRequestIQ:(TLRequestIQ *)requestIQ {
    
    self = [super initWithIQ:requestIQ];
    return self;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLRequestIQ\n"];
    [self appendTo:string];
    return string;
}

@end

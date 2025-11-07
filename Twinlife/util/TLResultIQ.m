/*
 *  Copyright (c) 2015-2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import "TLResultIQ.h"

/**
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "type":"record",
 *  "name":"ResultIQ",
 *  "namespace":"org.twinlife.schemas",
 *  "super":"org.twinlife.schemas.IQ"
 *  "fields":
 *  []
 * }
 *
 * </pre>
 */

//
// Implementation: TLResultIQSerializer
//

@implementation TLResultIQSerializer

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLIQ *iq = (TLIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    return [[TLResultIQ alloc] initWithIQ:iq];
}

@end

//
// Implementation: TLResultIQ
//

@implementation TLResultIQ

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to {
    
    self = [super initWithId:id from:from to:to type:TLIQTypeResult];
    return self;
}

- (instancetype)initWithTLResultIQ:(TLResultIQ *)resultIQ {
    
    self = [super initWithIQ:resultIQ];
    return self;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLResultIQ\n"];
    [self appendTo:string];
    return string;
}

@end

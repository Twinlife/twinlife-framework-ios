/*
 *  Copyright (c) 2020-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryErrorPacketIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"

//
// Implementation: TLBinaryErrorPacketIQSerializer
//

@implementation TLBinaryErrorPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLBinaryErrorPacketIQ class]];
}

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(int)schemaVersion class:(nonnull Class) clazz {
    
    self = [super initWithSchemaId:schemaId schemaVersion:schemaVersion class:clazz];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLBinaryErrorPacketIQ *errorPacketIQ = (TLBinaryErrorPacketIQ *)object;
    [encoder writeEnum:[TLBaseService fromErrorCode:errorPacketIQ.errorCode]];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    TLBaseServiceErrorCode errorCode = [TLBaseService toErrorCode:[decoder readEnum]];
    return [[TLBinaryErrorPacketIQ alloc] initWithSerializer:self requestId:requestId errorCode:errorCode];
}

@end

@implementation TLBinaryErrorPacketIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _errorCode = errorCode;
    }
    return self;
}

- (void)appendTo:(NSMutableString*)string {

    [super appendTo:string];
    [string appendFormat:@" errorCode: %d\n", self.errorCode];
}

@end

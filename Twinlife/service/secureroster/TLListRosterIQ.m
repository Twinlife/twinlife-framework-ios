/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLListRosterIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * List members of a secure roster for members created after a given timestamp.
 *
 * Schema version 1
 *  Date: 2026/03/25
 * <pre>
 * {
 *  "schemaId":"8da99a60-25e5-49f6-acc9-93c28c1d3314",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ListRosterIQ",
 *  "namespace":"org.twinlife.schemas.secureroster",
 *  "super":"org.twinlife.schemas.SecureRosterIQ"
 *  "fields": {
 *     {"name":"minimumCreationTime", "type":"long"},
 *  }
 * }
 * </pre>
 */

//
// Implementation: TLListRosterIQSerializer
//

@implementation TLListRosterIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLListRosterIQ class]];
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder object:(NSObject *)object {

    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLListRosterIQ *listRosterIQ = (TLListRosterIQ *)object;
    [encoder writeLong:listRosterIQ.minimumCreationTime];
}

- (NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLListRosterIQ
//

@implementation TLListRosterIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId rosterId:(nonnull NSUUID *)rosterId minimumCreationTime:(int64_t)minimumCreationTime {

    self = [super initWithSerializer:serializer requestId:requestId rosterId:rosterId];
    
    if (self) {
        _minimumCreationTime = minimumCreationTime;
    }
    return self;
}

- (void)appendTo:(nonnull NSMutableString*)string {

    [super appendTo:string];

    [string appendFormat:@" minimumCreationTime=%lld", self.minimumCreationTime];
}

- (NSString *)description {

    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLListRosterIQ:"];
    [self appendTo:string];
    return string;
}

@end

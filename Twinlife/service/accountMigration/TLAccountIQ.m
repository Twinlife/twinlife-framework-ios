/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLAccountIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Account IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"04A8EFC7-F261-4D19-A0E0-0248359CB4DF",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"AccountIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"securedConfiguration", "type":"bytes"},
 *     {"name":"accountConfiguration", "type":"bytes"},
 *     {"name":"hasPeerAccount", "type":"boolean"}
 *  ]
 * }
 *</pre>
 *
 * Important note: Old version with the 'environmentId' is not supported by new versions because
 * the environment ID is now embedded within the accountConfiguration which now has an incompatible
 * format with past version: to simplify, we can migrate only between versions with the schema 3 of accountConfiguration.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"04A8EFC7-F261-4D19-A0E0-0248359CB4DF",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AccountIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"securedConfiguration", "type":"bytes"},
 *     {"name":"accountConfiguration", "type":"bytes"},
 *     {"name":"environmentId", "type":"uuid"},
 *     {"name":"hasPeerAccount", "type":"boolean"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSwapAccountIQSerializer
//

@implementation TLSwapAccountIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLAccountIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLAccountIQ *accountIQ = (TLAccountIQ *)object;
    [encoder writeData:accountIQ.securedConfiguration];
    [encoder writeData:accountIQ.accountConfiguration];
    [encoder writeBoolean:accountIQ.hasPeerAccount];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSData *securedConf = [decoder readData];
    NSData *accountConf = [decoder readData];
    BOOL hasPeerAccount = [decoder readBoolean];
    
    return [[TLAccountIQ alloc] initWithSerializer:self iq:iq securedConfiguration:securedConf accountConfiguration:accountConf hasPeerAccount:hasPeerAccount];
}

@end

//
// Implementation: TLAccountIQ
//

@implementation TLAccountIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq securedConfiguration:(nonnull NSData *)securedConfiguration accountConfiguration:(nonnull NSData *)accountConfiguration hasPeerAccount:(BOOL)hasPeerAccount {
    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _accountConfiguration = accountConfiguration;
        _securedConfiguration = securedConfiguration;
        _hasPeerAccount = hasPeerAccount;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId securedConfiguration:(nonnull NSData *)securedConfiguration accountConfiguration:(nonnull NSData *)accountConfiguration hasPeerAccount:(BOOL)hasPeerAccount {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _accountConfiguration = accountConfiguration;
        _securedConfiguration = securedConfiguration;
        _hasPeerAccount = hasPeerAccount;
    }
    
    return self;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" hasPeerAccount: %d account.length: %ld secure.length: %ld", self.hasPeerAccount, self.accountConfiguration.length, self.securedConfiguration.length];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLAccountIQ "];
    [self appendTo:description];
    return description;
}

@end

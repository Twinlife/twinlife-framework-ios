/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLErrorIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Error message IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"42705574-8e05-47fd-9742-ffd86a923cea",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"ErrorIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"errorCode", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLE
//

@implementation TLMigrationErrorIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLMigrationErrorIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
        
    TLMigrationErrorIQ *errorIQ = (TLMigrationErrorIQ *)object;
    switch (errorIQ.errorCode) {
        case TLAccountMigrationErrorCodeInternalError:
            [encoder writeEnum:1];
            break;
            
        case TLAccountMigrationErrorCodeNoSpaceLeft:
            [encoder writeEnum:2];
            break;
            
        case TLAccountMigrationErrorCodeIoError:
            [encoder writeEnum:3];
            break;

        case TLAccountMigrationErrorCodeRevoked:
            [encoder writeEnum:4]; // Note: will never be sent in the IQ.
            break;

        case TLAccountMigrationErrorCodeBadPeerVersion:
            [encoder writeEnum:5]; // Note: will never be sent in the IQ.
            break;

        case TLAccountMigrationErrorCodeBadDatabase:
            [encoder writeEnum:6];
            break;

        case TLAccountMigrationErrorCodeSecureStoreError:
            [encoder writeEnum:7];
            break;

        default:
            break;
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    TLAccountMigrationErrorCode errorCode;
    
    switch ([decoder readEnum]) {
        default:
        case 1:
            errorCode = TLAccountMigrationErrorCodeInternalError;
            break;
        case 2:
            errorCode = TLAccountMigrationErrorCodeNoSpaceLeft;
            break;
        case 3:
            errorCode = TLAccountMigrationErrorCodeIoError;
            break;
        case 4:
            errorCode = TLAccountMigrationErrorCodeRevoked;
            break;
        case 5:
            errorCode = TLAccountMigrationErrorCodeBadPeerVersion;
            break;
        case 6:
            errorCode = TLAccountMigrationErrorCodeBadDatabase;
            break;
        case 7:
            errorCode = TLAccountMigrationErrorCodeSecureStoreError;
            break;
    }
    
    return [[TLMigrationErrorIQ alloc] initWithSerializer:self iq:iq errorCode:errorCode];
}

@end

//
// Implementation: TLMigrationErrorIQ
//

@implementation TLMigrationErrorIQ
- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq errorCode:(TLAccountMigrationErrorCode)errorCode {
    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _errorCode = errorCode;
    }
    
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId errorCode:(TLAccountMigrationErrorCode)errorCode {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _errorCode = errorCode;
    }
    
    return self;
}

@end

/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLAttributeNameValue.h"
#import "TLPeerConnectionService.h"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

//
// Implementation: TLBinaryPacketIQSerializer
//

@implementation TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(int)schemaVersion class:(nonnull Class) clazz {
    
    self = [super initWithSchemaId:schemaId schemaVersion:schemaVersion class:clazz];
    return self;
}

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion class:(nonnull Class) clazz {
    
    self = [super initWithSchemaId:[[NSUUID alloc] initWithUUIDString:schema] schemaVersion:schemaVersion class:clazz];
    return self;
}

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    self = [super initWithSchemaId:[[NSUUID alloc] initWithUUIDString:schema] schemaVersion:schemaVersion class:[TLBinaryPacketIQ class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [encoder writeUUID:self.schemaId];
    [encoder writeInt:self.schemaVersion];
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)object;
    [encoder writeLong:iq.requestId];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    
    return [[TLBinaryPacketIQ alloc] initWithSerializer:self requestId:requestId];
}

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {
    
    [encoder writeAttributes:attributes];
}

- (nullable NSMutableArray<TLAttributeNameValue *> *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder {
    
    return [decoder readAttributes];
}

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder errorCode:(TLBaseServiceErrorCode)errorCode {

    switch (errorCode) {
        case TLBaseServiceErrorCodeSuccess:
            [encoder writeEnum:0];
            break;
            
        case TLBaseServiceErrorCodeBadRequest:
            [encoder writeEnum:1];
            break;
            
        case TLBaseServiceErrorCodeCanceledOperation:
            [encoder writeEnum:2];
            break;
            
        case TLBaseServiceErrorCodeFeatureNotImplemented:
            [encoder writeEnum:3];
            break;
            
        case TLBaseServiceErrorCodeFeatureNotSupportedByPeer:
            [encoder writeEnum:4];
            break;
            
        case TLBaseServiceErrorCodeServerError:
            [encoder writeEnum:5];
            break;
            
        case TLBaseServiceErrorCodeItemNotFound:
            [encoder writeEnum:6];
            break;
            
        case TLBaseServiceErrorCodeLibraryError:
            [encoder writeEnum:7];
            break;
            
        case TLBaseServiceErrorCodeLibraryTooOld:
            [encoder writeEnum:8];
            break;
            
        case TLBaseServiceErrorCodeNotAuthorizedOperation:
            [encoder writeEnum:9];
            break;
            
        case TLBaseServiceErrorCodeServiceUnavailable:
            [encoder writeEnum:10];
            break;
            
        case TLBaseServiceErrorCodeTwinlifeOffline:
            [encoder writeEnum:11];
            break;
            
        case TLBaseServiceErrorCodeWebrtcError:
            [encoder writeEnum:12];
            break;
            
        case TLBaseServiceErrorCodeWrongLibraryConfiguration:
            [encoder writeEnum:13];
            break;
            
        case TLBaseServiceErrorCodeNoStorageSpace:
            [encoder writeEnum:14];
            break;
            
        case TLBaseServiceErrorCodeNoPermission:
            [encoder writeEnum:15];
            break;
            
        case TLBaseServiceErrorCodeLimitReached:
            [encoder writeEnum:16];
            break;
            
        case TLBaseServiceErrorCodeDatabaseError:
            [encoder writeEnum:17];
            break;

        case TLBaseServiceErrorCodeQueued:
            [encoder writeEnum:18];
            break;

        case TLBaseServiceErrorCodeQueuedNoWakeup:
            [encoder writeEnum:19];
            break;

        case TLBaseServiceErrorCodeExpired:
            [encoder writeEnum:20];
            break;

        case TLBaseServiceErrorCodeInvalidPublicKey:
            [encoder writeEnum:21];
            break;

        case TLBaseServiceErrorCodeInvalidPrivateKey:
            [encoder writeEnum:22];
            break;

        case TLBaseServiceErrorCodeNoPublicKey:
            [encoder writeEnum:23];
            break;

        case TLBaseServiceErrorCodeNoPrivateKey:
            [encoder writeEnum:24];
            break;

        case TLBaseServiceErrorCodeBadSignature:
            [encoder writeEnum:25];
            break;

        case TLBaseServiceErrorCodeBadSignatureFormat:
            [encoder writeEnum:26];
            break;

        case TLBaseServiceErrorCodeBadSignatureMissingAttribute:
            [encoder writeEnum:27];
            break;

        case TLBaseServiceErrorCodeBadSignatureNotSignedAttribute:
            [encoder writeEnum:28];
            break;

        case TLBaseServiceErrorCodeEncryptError:
            [encoder writeEnum:29];
            break;

        case TLBaseServiceErrorCodeDecryptError:
            [encoder writeEnum:30];
            break;

        case TLBaseServiceErrorCodeBadEncryptionFormat:
            [encoder writeEnum:31];
            break;

        case TLBaseServiceErrorCodeNoSecretKey:
            [encoder writeEnum:32];
            break;

        case TLBaseServiceErrorCodeNotEncrypted:
            [encoder writeEnum:33];
            break;

        case TLBaseServiceErrorCodeFileNotFound:
            [encoder writeEnum:34];
            break;

        case TLBaseServiceErrorCodeFileNotSupported:
            [encoder writeEnum:35];
            break;

        case TLBaseServiceErrorCodeTimeoutError:
            [encoder writeEnum:7];
            break;

        case TLBaseServiceErrorCodeAccountDeleted:
            [encoder writeEnum:7];
            break;

        default:
            [encoder writeEnum:7];
            break;
    }
}

@end

@implementation TLBinaryPacketIQ : NSObject

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId {
    
    self = [super init];
    if (self) {
        _serializer = serializer;
        _requestId = requestId;
    }
    return self;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq {
    
    self = [super init];
    if (self) {
        _serializer = serializer;
        _requestId = iq.requestId;
    }
    return self;
}

- (nonnull NSMutableData *)serializeCompactWithSerializerFactory:(nonnull TLSerializerFactory *)factory {

    long size = [self bufferSize];
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:size];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];

    [self.serializer serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    return data;
}

- (nonnull NSMutableData *)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)factory {

    long size = [self bufferSize];
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:size];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];

    [self.serializer serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    return data;
}

- (nonnull NSMutableData *)serializePaddingWithSerializerFactory:(nonnull TLSerializerFactory *)factory withLeadingPadding:(BOOL)withLeadingPadding {
    
    long size = [self bufferSize];
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:size];
    
    TLBinaryEncoder *binaryEncoder;
    if (withLeadingPadding) {
        binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
    } else {
        binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
    }
    [self.serializer serializeWithSerializerFactory:factory encoder:binaryEncoder object:self];
    return data;
}

- (long)bufferSize {
    
    return SERIALIZER_BUFFER_DEFAULT_SIZE;
}

- (void)appendTo:(NSMutableString*)string {

    [string appendFormat:@" schemaId: %@.%d req: %lld", self.serializer.schemaId, self.serializer.schemaVersion, self.requestId];
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLBinaryPacketIQ:"];
    [self appendTo:string];
    return string;
}

@end

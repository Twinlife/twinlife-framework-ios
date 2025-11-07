/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "NSData+Extensions.h"
#import "TLTwinlifeImpl.h"
#import "TLBaseServiceImpl.h"
#import "TLCryptoServiceProvider.h"
#import "TLCryptoServiceImpl.h"
#import "TLTwincode.h"
#import "TLRepositoryServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLAttributeNameValue.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLSignatureInfoIQ.h"
#import "TLSessionSecretKeyPair.h"
#import <WebRTC/TLCryptoBox.h>

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define CRYPTO_SERVICE_VERSION          @"1.0.0"
#define SIGNATURE_VERSION_ECDSA         1
#define SIGNATURE_VERSION_ED25519       2
#define ENCRYPT_VERSION_ECDSA           1
#define ENCRYPT_VERSION_X25519          2
#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024
#define MAX_ATTRIBUTES                 64
#define ECDSA_PUBKEY_LENGTH            124

static NSArray<NSString *> *PREDEFINED_LIST;

#undef LOG_TAG
#define LOG_TAG @"TLKeyInfo"

//
// Implementation: TLKeyInfo
//

@implementation TLKeyInfo

- (nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode modificationDate:(int64_t)modificationDate flags:(int)flags signingKey:(nullable NSData *)signingKey encryptionKey:(nullable NSData *)encryptionKey nonceSequence:(int64_t)nonceSequence keyIndex:(int)keyIndex secret:(nullable NSData *)secret {

    self = [super init];
    if (self) {
        _twincodeOutbound = twincode;
        _signKind = [TLKeyInfo toCryptoKindWithFlags:flags encrypt:NO];
        _encryptionKind = [TLKeyInfo toCryptoKindWithFlags:flags encrypt:YES];
        _keyIndex = keyIndex;
        _secretKey = secret;
        _nonceSequence = nonceSequence;
        if ((flags & TL_KEY_PRIVATE_FLAG) != 0) {
            _signingKey = [TLCryptoKey importPrivateKey:_signKind privateKey:signingKey isBase64:NO];
            _encryptionKey = [TLCryptoKey importPrivateKey:_encryptionKind privateKey:encryptionKey isBase64:NO];
        } else {
            _signingKey = [TLCryptoKey importPublicKey:_signKind pubKey:signingKey isBase64:NO];
            _encryptionKey = [TLCryptoKey importPublicKey:_encryptionKind pubKey:encryptionKey isBase64:NO];
        }
    }
    return self;
}

+ (TLCryptoKind)toCryptoKindWithFlags:(int)flags encrypt:(BOOL)encrypt {
    
    switch (flags & TL_KEY_TYPE_MASK) {
        case TL_KEY_TYPE_25519:
            return encrypt ? TLCryptoKindX25519 : TLCryptoKindED25519;

        case TL_KEY_TYPE_ECDSA:
        default:
            return TLCryptoKindECDSA;
    }
}

- (nullable NSString *)publicBase64EncryptionKey {
    DDLogVerbose(@"%@ publicBase64EncryptionKey", LOG_TAG);

    if (!self.encryptionKey) {
        return nil;
    }
    NSData *key = [self.encryptionKey publicKey:YES];
    if (!key) {
        return nil;
    }
    return [[NSString alloc] initWithData:key encoding:NSUTF8StringEncoding];
}

- (nullable NSString *)publicBase64SigningKey {
    DDLogVerbose(@"%@ publicBase64SigningKey", LOG_TAG);

    if (!self.signingKey) {
        return nil;
    }
    NSData *key = [self.signingKey publicKey:YES];
    if (!key) {
        return nil;
    }
    return [[NSString alloc] initWithData:key encoding:NSUTF8StringEncoding];
}

@end

//
// Interface: TLKeyPair
//

@implementation TLKeyPair

- (nonnull instancetype)initWithFlags:(int)flags privKey:(nonnull NSData *)privKey peerFlags:(int)peerFlags peerPubKey:(nonnull NSData *)peerPubKey twincodeId:(nonnull NSUUID *)twincodeId peerTwincodeId:(nonnull NSUUID *)peerTwincodeId subjectId:(nonnull NSUUID *)subjectId {
    DDLogVerbose(@"%@ initWithFlags", LOG_TAG);

    self = [super init];
    if (self) {
        _twincodeId = twincodeId;
        _peerTwincodeId = peerTwincodeId;
        _subjectId = subjectId;
        
        _privateKey = [TLCryptoKey importPrivateKey:[TLKeyInfo toCryptoKindWithFlags:flags encrypt:NO] privateKey:privKey isBase64:NO];
        _peerPublicKey = [TLCryptoKey importPublicKey:[TLKeyInfo toCryptoKindWithFlags:peerFlags encrypt:NO] pubKey:peerPubKey isBase64:NO];
    }
    return self;
}

@end

//
// Implementation: TLCryptoServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLCryptoServiceConfiguration"

@implementation TLCryptoServiceConfiguration

- (nonnull instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    return [super initWithBaseServiceId:TLBaseServiceIdCryptoService version:[TLCryptoService VERSION] serviceOn:NO];
}

@end

//
// Implementation: TLVerifyResult
//

#undef LOG_TAG
#define LOG_TAG @"TLVerifyResult"

@implementation TLVerifyResult

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode signingKey:(nullable NSData *)signingKey encryptionKey:(nullable NSData *)encryptionKey imageSha:(nullable NSData *)imageSha {
    
    self = [super init];
    if (self) {
        _errorCode = errorCode;
        _publicSigningKey = signingKey;
        _publicEncryptionKey = encryptionKey;
        _imageSha = imageSha;
    }
    return self;
}

+ (nonnull TLVerifyResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    
    return [[TLVerifyResult alloc] initWithErrorCode:errorCode signingKey:nil encryptionKey:nil imageSha:nil];
}

+ (nonnull TLVerifyResult *)initWithSigningKey:(nonnull NSData *)signingKey encryptionKey:(nullable NSData *)encryptionKey imageSha:(nullable NSData *)imageSha {
    
    return [[TLVerifyResult alloc] initWithErrorCode:TLBaseServiceErrorCodeSuccess signingKey:signingKey encryptionKey:encryptionKey imageSha:imageSha];
}

@end

//
// Implementation: TLCipherResult
//
#undef LOG_TAG
#define LOG_TAG @"TLCipherResult"

@implementation TLCipherResult

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode data:(nullable NSData *)data length:(int)length {
    
    self = [super init];
    if (self) {
        _errorCode = errorCode;
        _data = data;
        _length = length;
    }
    return self;
}

+ (nonnull TLCipherResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogError(@"%@ errorWithErrorCode: %d", LOG_TAG, errorCode);

    return [[TLCipherResult alloc] initWithErrorCode:errorCode data:nil length:0];
}

+ (nonnull TLCipherResult *)initWithData:(nullable NSData *)data length:(int)length {

    return [[TLCipherResult alloc] initWithErrorCode:TLBaseServiceErrorCodeSuccess data:data length:length];
}

@end

//
// Implementation: TLDecipherResult
//
#undef LOG_TAG
#define LOG_TAG @"TLDecipherResult"

@implementation TLDecipherResult

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode attributes:(nullable NSMutableArray<TLAttributeNameValue *> *)attributes peerTwincodeId:(nullable NSUUID *)peerTwincodeId keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey publicKey:(nullable NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod {
    
    self = [super init];
    if (self) {
        _errorCode = errorCode;
        _attributes = attributes;
        _peerTwincodeId = peerTwincodeId;
        _keyIndex = keyIndex;
        _secretKey = secretKey;
        _publicKey = publicKey;
        _trustMethod = trustMethod;
    }
    return self;
}

+ (nonnull TLDecipherResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogError(@"%@ errorWithErrorCode: %d", LOG_TAG, errorCode);

    return [[TLDecipherResult alloc] initWithErrorCode:errorCode attributes:nil peerTwincodeId:nil keyIndex:0 secretKey:nil publicKey:nil trustMethod:TLTrustMethodNone];
}

+ (nonnull TLDecipherResult *)initWithAttributes:(nullable NSArray<TLAttributeNameValue *> *)attributes peerTwincodeId:(nullable NSUUID *)peerTwincodeId keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey publicKey:(nullable NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod {

    return [[TLDecipherResult alloc] initWithErrorCode:TLBaseServiceErrorCodeSuccess attributes:attributes peerTwincodeId:peerTwincodeId keyIndex:keyIndex secretKey:secretKey publicKey:publicKey trustMethod:trustMethod];
}

@end

//
// Implementation: TLSignResult
//
#undef LOG_TAG
#define LOG_TAG @"TLSignResult"

@implementation TLSignResult

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode signature:(nullable NSString *)signature {
    
    self = [super init];
    if (self) {
        _errorCode = errorCode;
        _signature = signature;
    }
    return self;
}

+ (nonnull TLSignResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogError(@"%@ errorWithErrorCode: %d", LOG_TAG, errorCode);

    return [[TLSignResult alloc] initWithErrorCode:errorCode signature:nil];
}

+ (nonnull TLSignResult *)initWithSignature:(nonnull NSString *)signature {

    return [[TLSignResult alloc] initWithErrorCode:TLBaseServiceErrorCodeSuccess signature:signature];
}

@end

//
// Implementation: TLVerifyAuthenticateResult
//
#undef LOG_TAG
#define LOG_TAG @"TLVerifyAuthenticateResult"

@implementation TLVerifyAuthenticateResult

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode subjectId:(nullable NSUUID *)subjectId {
    
    self = [super init];
    if (self) {
        _errorCode = errorCode;
        _subjectId = subjectId;
    }
    return self;
}

+ (nonnull TLVerifyAuthenticateResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    DDLogError(@"%@ errorWithErrorCode: %d", LOG_TAG, errorCode);

    return [[TLVerifyAuthenticateResult alloc] initWithErrorCode:errorCode subjectId:nil];
}

+ (nonnull TLVerifyAuthenticateResult *)initWithSubjectId:(nonnull NSUUID *)subjectId {

    return [[TLVerifyAuthenticateResult alloc] initWithErrorCode:TLBaseServiceErrorCodeSuccess subjectId:subjectId];
}

@end

//
// Interface: TLCryptoService
//

@interface TLCryptoService ()

@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) TLCryptoServiceProvider *serviceProvider;

@end

//
// Implementation: TLTwincodeCryptoService
//

#undef LOG_TAG
#define LOG_TAG @"TLCryptoService"

@implementation TLCryptoService

+ (nonnull NSString *)VERSION {
    
    return CRYPTO_SERVICE_VERSION;
}

+ (void)initialize {

    PREDEFINED_LIST = @[
        TL_TWINCODE_NAME,
        TL_TWINCODE_DESCRIPTION,
        TL_TWINCODE_CAPABILITIES,
        TL_TWINCODE_AVATAR_ID
    ];
}

+ (int)getEncryptVersion:(TLCryptoKind)privateKind publicKind:(TLCryptoKind)publicKind {
    DDLogVerbose(@"%@ getEncryptVersion: %d publicKind: %d", LOG_TAG, privateKind, publicKind);
    
    if (privateKind != publicKind) {
        return -1;
    }
    switch (privateKind) {
        case TLCryptoKindECDSA:
            return ENCRYPT_VERSION_ECDSA;

        case TLCryptoKindX25519:
            return ENCRYPT_VERSION_X25519;

        default:
            return -1;
    }
}

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    _serviceProvider = [[TLCryptoServiceProvider alloc] initWithService:self database:twinlife.databaseService];
    _serializerFactory = twinlife.serializerFactory;

    return self;
}

#pragma mark - TLBaseServiceImpl

- (void)configure:(nonnull TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLCryptoServiceConfiguration* cryptoServiceConfiguration = [[TLCryptoServiceConfiguration alloc] init];
    TLCryptoServiceConfiguration* serviceConfiguration = (TLCryptoServiceConfiguration *) baseServiceConfiguration;
    cryptoServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.serviceConfiguration = cryptoServiceConfiguration;
    self.serviceOn = cryptoServiceConfiguration.isServiceOn;
}

#pragma mark - TLCryptoService

- (nullable NSString *)getPublicKeyWithTwincode:(nonnull TLTwincodeOutbound*)twincodeOutbound {
    DDLogVerbose(@"%@: getPublicKeyWithTwincode: %@", LOG_TAG, twincodeOutbound);

    if (!self.serviceOn) {
        return nil;
    }

    TLKeyInfo *keyInfo = [self.serviceProvider loadKeyWithTwincode:twincodeOutbound];
    if (!keyInfo) {
        return nil;
    }

    if (!keyInfo.signingKey) {
        return nil;
    }

    NSData *rawKey = [keyInfo.signingKey publicKey:YES];
    return [[NSString alloc] initWithData:rawKey encoding:NSUTF8StringEncoding];
}

- (nullable NSData *)signWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@: signWithTwincode: %@", LOG_TAG, twincodeOutbound);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    TLKeyInfo *keyInfo = [self.serviceProvider loadKeyWithTwincode:twincodeOutbound];
    if (!keyInfo || !keyInfo.signingKey) {
        return nil;
    }
    
    TLAttributeNameValue *imageAttribute = [TLAttributeNameValue getAttributeWithName:TL_TWINCODE_AVATAR_ID list:attributes];
    NSData *sha;
    if (imageAttribute) {
        TLImageInfo *info = [self.serviceProvider loadImageInfoWithId:((TLImageId *)imageAttribute.value).localId];
        if (!info) {
            return nil;
        }
        sha = info.data;

    } else if (twincodeOutbound.avatarId) {
        int64_t localId = twincodeOutbound.avatarId.localId;
        TLImageInfo *info = [self.serviceProvider loadImageInfoWithId:localId];
        if (!info) {
            return nil;
        }
        [attributes addObject:[[TLAttributeNameImageIdValue alloc] initWithName:TL_TWINCODE_AVATAR_ID imageId:[[TLExportedImageId alloc] initWithPublicId:info.publicId localId:localId]]];
        sha = info.data;

    } else {
        sha = nil;
    }

    NSData *encryptionPubKey = keyInfo.encryptionKey ? [keyInfo.encryptionKey publicKey:NO] : nil;

    NSMutableArray<TLAttributeNameValue *> *signAttributes = [[NSMutableArray alloc] initWithArray:attributes];
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];

    int version;
    switch (keyInfo.signKind) {
        case TLCryptoKindED25519:
            version = SIGNATURE_VERSION_ED25519;
            break;

        case TLCryptoKindECDSA:
            version = SIGNATURE_VERSION_ECDSA;
            break;

        default:
            return nil;
    }

    [binaryEncoder writeInt:version];
    [binaryEncoder writeUUID:twincodeOutbound.uuid];
    for (NSString *name in PREDEFINED_LIST) {
        TLAttributeNameValue *attribute = [TLAttributeNameValue removeAttributeWithName:name list:signAttributes];
        if (attribute) {
            if ([attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                [binaryEncoder writeOptionalString:(NSString *)attribute.value];
            } else if ([attribute isKindOfClass:[TLAttributeNameUUIDValue class]]) {
                [binaryEncoder writeOptionalUUID:(NSUUID *)attribute.value];
            } else if ([attribute isKindOfClass:[TLAttributeNameImageIdValue class]]) {
                [binaryEncoder writeOptionalUUID:((TLExportedImageId *)attribute.value).publicId];
            } else {
                [binaryEncoder writeOptionalString:nil];
            }
        } else {
            [binaryEncoder writeOptionalString:nil];
        }
    }
    [binaryEncoder writeOptionalData:sha];
    [binaryEncoder writeOptionalData:encryptionPubKey];
    [binaryEncoder writeAttributes:signAttributes];

    // Sign what is serialized with the private key.
    NSData *signature = [keyInfo.signingKey signWithData:data isBase64:NO];

    // Build the final signature where we indicate the version and list of attributes
    // in the same order as we serialized them.
    data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
    [binaryEncoder writeInt:version];
    [binaryEncoder writeData:signature];
    [binaryEncoder writeOptionalData:sha];
    [binaryEncoder writeOptionalData:encryptionPubKey];
    [binaryEncoder writeInt:(int)signAttributes.count];
    for (TLAttributeNameValue *attribute in signAttributes) {
        [binaryEncoder writeString:attribute.name];
    }

    return data;
}

- (nonnull TLVerifyResult *)verifyWithPublicKey:(nonnull NSString *)publicKey twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nonnull NSData *)signature {
    DDLogVerbose(@"%@: verifyWithPublicKey: %@ twincodeId: %@ attributes: %@", LOG_TAG, publicKey, twincodeId, attributes);

    if (!self.serviceOn) {
        return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }

    TLCryptoKind kind = (publicKey.length >= ECDSA_PUBKEY_LENGTH) ? TLCryptoKindECDSA : TLCryptoKindED25519;
    TLCryptoKey *key = [TLCryptoKey importPublicKey:kind pubKey:[publicKey dataUsingEncoding:NSUTF8StringEncoding] isBase64:YES];
    if (!key) {
        return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeInvalidPublicKey];
    }

    return [self verifyWithKey:key kind:kind twincodeId:twincodeId attributes:attributes signature:signature];
}

- (nonnull TLVerifyResult *)verifyWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nonnull NSData *)signature {
    DDLogVerbose(@"%@: verifyWithTwincode: %@", LOG_TAG, twincode);

    if (!self.serviceOn) {
        return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }
   
    TLKeyInfo *keyInfo = [self.serviceProvider loadKeyWithTwincode:twincode];
    if (!keyInfo || !keyInfo.signingKey) {
        return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeNoPublicKey];
    }

    return [self verifyWithKey:keyInfo.signingKey kind:keyInfo.signKind twincodeId:twincode.uuid attributes:attributes signature:signature];
}

- (nonnull TLVerifyResult *)verifyWithKey:(nonnull TLCryptoKey *) key kind:(TLCryptoKind)kind twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nonnull NSData *)signature {
    DDLogVerbose(@"%@: verifyWithKey: %@ kind: %d twincodeId: %@ attributes: %@ signature: %@", LOG_TAG, key, kind, twincodeId, attributes, signature);
    
    NSData *pubKey = [key publicKey:NO];
    if (!pubKey) {
        return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeNoPublicKey];
    }

    int expectVersion;
    switch (kind) {
        case TLCryptoKindED25519:
            expectVersion = SIGNATURE_VERSION_ED25519;
            break;

        case TLCryptoKindECDSA:
            expectVersion = SIGNATURE_VERSION_ECDSA;
            break;

        default:
            return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeInvalidPublicKey];
    }

    @try {
        // Step 1: extract the ECDSA/ED25519 signature, the expected avatar SHA and number of attributes.
        TLBinaryCompactDecoder *decoder = [[TLBinaryCompactDecoder alloc] initWithData:signature];
        int version = [decoder readInt];
        if (version != expectVersion) {
            return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];
        }
        NSData *keySignature = [decoder readData];
        NSData *sha = [decoder readOptionalData];
        NSData *encryptionPubKey = [decoder readOptionalData];
        int attributeCount = [decoder readInt];
        if (attributeCount < 0 || attributeCount > MAX_ATTRIBUTES) {
            return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];
        }
        
        // Step 2: build the data to be verified.
        NSMutableArray<TLAttributeNameValue *> *signAttributes = [[NSMutableArray alloc] initWithArray:attributes];
        NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
        TLBinaryCompactEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
        [binaryEncoder writeInt:version];
        [binaryEncoder writeUUID:twincodeId];
        for (NSString *name in PREDEFINED_LIST) {
            TLAttributeNameValue *attribute = [TLAttributeNameValue removeAttributeWithName:name list:signAttributes];
            if (attribute) {
                if ([attribute isKindOfClass:[TLAttributeNameStringValue class]]) {
                    [binaryEncoder writeOptionalString:(NSString *)attribute.value];
                } else if ([attribute isKindOfClass:[TLAttributeNameUUIDValue class]]) {
                    [binaryEncoder writeOptionalUUID:(NSUUID *)attribute.value];
                } else if ([attribute isKindOfClass:[TLAttributeNameImageIdValue class]]) {
                    [binaryEncoder writeOptionalUUID:((TLExportedImageId *)attribute.value).publicId];
                } else {
                    [binaryEncoder writeOptionalString:nil];
                }
            } else {
                [binaryEncoder writeOptionalString:nil];
            }
        }
        [binaryEncoder writeOptionalData:sha];
        [binaryEncoder writeOptionalData:encryptionPubKey];
        [binaryEncoder writeInt:attributeCount];
        while (attributeCount > 0) {
            attributeCount--;
            NSString *name = [decoder readString];
            TLAttributeNameValue *attribute = [TLAttributeNameValue removeAttributeWithName:name list:signAttributes];
            if (!attribute) {
                // This attribute is not found, no need to proceed: it is invalid, they must be present.
                return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignatureMissingAttribute];
            }
            [binaryEncoder writeAttribute:attribute];
        }
        if (signAttributes.count > 0) {
            // We still have some attributes to be signed: it is invalid they should have been removed.
            return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignatureNotSignedAttribute];
        }
        int result = [key verifyWithData:data signature:keySignature isBase64:NO];
        if (result != 1) {
            return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];
        }
        return [TLVerifyResult initWithSigningKey:pubKey encryptionKey:encryptionPubKey imageSha:sha];

    } @catch (NSException *exception) {
        return [TLVerifyResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];
    }
}

- (nonnull TLSignResult *)signAuthenticateWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@: signAuthenticateWithTwincode: %@", LOG_TAG, twincodeOutbound);
    
    if (!self.serviceOn) {
        return [TLSignResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }
    
    TLKeyPair *keyPair = [self.serviceProvider loadKeyPairWithTwincode:twincodeOutbound];
    if (!keyPair || !keyPair.privateKey) {
        return [TLSignResult errorWithErrorCode:TLBaseServiceErrorCodeNoPrivateKey];
    }
    
    TLCryptoKey *privKey = keyPair.privateKey;
    NSString *signature = [privKey signAuthWithKey:keyPair.peerPublicKey item:[keyPair.twincodeId toString] peerItem:[keyPair.peerTwincodeId toString]];
    if (!signature) {
        return [TLSignResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];
    }

    return [TLSignResult initWithSignature:signature];
}

- (nonnull TLVerifyAuthenticateResult *)verifyAuthenticateWithSignature:(nonnull NSString *)signature {
    DDLogVerbose(@"%@: verifyAuthenticateWithSignature: %@", LOG_TAG, signature);
    
    if (!self.serviceOn) {
        return [TLVerifyAuthenticateResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }
    
    NSData *rawKey = [TLCryptoKey extractAuthPublicKeyWithSignature:signature];
    if (!rawKey) {
        return [TLVerifyAuthenticateResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];
    }

    TLKeyPair *keyPair = [self.serviceProvider loadKeyPairWithKey:rawKey];
    if (!keyPair) {
        return [TLVerifyAuthenticateResult errorWithErrorCode:TLBaseServiceErrorCodeItemNotFound];
    }

    TLCryptoKey *privKey = keyPair.privateKey;
    TLCryptoKey *peerPublicKey = keyPair.peerPublicKey;
    if (!privKey || !peerPublicKey) {
        return [TLVerifyAuthenticateResult errorWithErrorCode:TLBaseServiceErrorCodeNoPrivateKey];
    }

    // The signature could be created with the peer's private key or our own private key.
    // Check for the peer's signature, otherwise check for our signature.
    NSData *pubKeyData = [privKey publicKey:NO];
    TLCryptoKey *pubKey = [TLCryptoKey importPublicKey:TLCryptoKindED25519 pubKey:pubKeyData isBase64:NO];
    int result = [peerPublicKey verifyAuthWithKey:pubKey item:[keyPair.twincodeId toString] peerItem:[keyPair.peerTwincodeId toString] signature:signature];
    if (result != 1) {
        result = [pubKey verifyAuthWithKey:peerPublicKey item:[keyPair.twincodeId toString] peerItem:[keyPair.peerTwincodeId toString] signature:signature];
    }
    if (result != 1) {
        return [TLVerifyAuthenticateResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];
    }

    return [TLVerifyAuthenticateResult initWithSubjectId:keyPair.subjectId];
}

- (nullable NSString *)signContentWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound content:(nonnull NSData *)content {
    DDLogVerbose(@"%@: signContentWithTwincode: %@ content: %@", LOG_TAG, twincodeOutbound, content);

    if (!self.serviceOn) {
        return nil;
    }

    TLKeyInfo *keyInfo = [self.serviceProvider loadKeyWithTwincode:twincodeOutbound];
    if (!keyInfo || !keyInfo.signingKey) {
        return nil;
    }
    
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];

    int version;
    switch (keyInfo.signKind) {
        case TLCryptoKindED25519:
            version = SIGNATURE_VERSION_ED25519;
            break;

        case TLCryptoKindECDSA:
            version = SIGNATURE_VERSION_ECDSA;
            break;

        default:
            return nil;
    }

    [binaryEncoder writeInt:version];
    [binaryEncoder writeUUID:twincodeOutbound.uuid];
    [binaryEncoder writeData:content];
    
    DDLogError(@"%@: data to sign: %@", LOG_TAG, data);

    // Sign what is serialized with the private key.
    NSData *signature = [keyInfo.signingKey signWithData:data isBase64:YES];
    if (!signature) {
        return nil;
    }

    return [[NSString alloc] initWithBytes:[signature bytes] length:signature.length encoding:NSUTF8StringEncoding];
}

- (TLBaseServiceErrorCode)verifyContentWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound content:(nonnull NSData *)content signature:(nonnull NSString *)signature {
    DDLogVerbose(@"%@: verifyContentWithTwincode: %@ content: %@ signature: %@", LOG_TAG, twincodeOutbound, content, signature);

    if (!self.serviceOn) {
        return TLBaseServiceErrorCodeServiceUnavailable;
    }

    TLKeyInfo *keyInfo = [self.serviceProvider loadKeyWithTwincode:twincodeOutbound];
    if (!keyInfo || !keyInfo.signingKey) {
        return TLBaseServiceErrorCodeNoPublicKey;
    }
    
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];

    int version;
    switch (keyInfo.signKind) {
        case TLCryptoKindED25519:
            version = SIGNATURE_VERSION_ED25519;
            break;

        case TLCryptoKindECDSA:
            version = SIGNATURE_VERSION_ECDSA;
            break;

        default:
            return TLBaseServiceErrorCodeBadRequest;
    }

    [binaryEncoder writeInt:version];
    [binaryEncoder writeUUID:twincodeOutbound.uuid];
    [binaryEncoder writeData:content];

    // Sign what is serialized with the private key.
    int result = [keyInfo.signingKey verifyWithData:data signature:[signature dataUsingEncoding:NSUTF8StringEncoding] isBase64:YES];
    return result == 1 ? TLBaseServiceErrorCodeSuccess : TLBaseServiceErrorCodeBadSignature;
}

- (nonnull TLCipherResult *)encryptWithTwincode:(nonnull TLTwincodeOutbound *)cipherTwincode senderTwincode:(nonnull TLTwincodeOutbound *)senderTwincode targetTwincode:(nonnull TLTwincodeOutbound *)targetTwincode options:(int)options attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes {
    DDLogVerbose(@"%@: encryptWithTwincode: %@ senderTwincode: %@ targetTwincode: %@ options: %d", LOG_TAG, cipherTwincode, senderTwincode, targetTwincode, options);

    if (!self.serviceOn) {
        return [TLCipherResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }

    TLKeyInfo *targetKey = [self.serviceProvider loadKeyWithTwincode:targetTwincode];
    if (!targetKey || !targetKey.encryptionKey) {
        return [TLCipherResult errorWithErrorCode:TLBaseServiceErrorCodeNoPublicKey];
    }

    int createSecret = 0;
    if ((options & TLInvokeTwincodeCreateSecret) != 0) {
        createSecret = TLCryptoServiceProviderCreateSecret;
    } else if ((options & TLInvokeTwincodeCreateNewSecret) != 0) {
        createSecret = TLCryptoServiceProviderCreateNextSecret;
    } else if ((options & TLInvokeTwincodeSendSecret) != 0) {
        createSecret = TLCryptoServiceProviderCreateFirstSecret;
    }
    TLKeyInfo *keyInfo;
    TLKeyInfo *senderInfo;
    if (cipherTwincode != senderTwincode) {
        keyInfo = [self.serviceProvider loadKeySecretsWithTwincode:cipherTwincode peerTwincode:targetTwincode useSequenceCount:1 options:0];

        senderInfo = [self.serviceProvider loadKeySecretsWithTwincode:senderTwincode peerTwincode:targetTwincode useSequenceCount:0 options:createSecret];

    } else {
        keyInfo = [self.serviceProvider loadKeySecretsWithTwincode:cipherTwincode peerTwincode:targetTwincode useSequenceCount:1 options:createSecret];

        senderInfo = keyInfo;
    }
    if (!keyInfo || !keyInfo.encryptionKey) {
        return [TLCipherResult errorWithErrorCode:TLBaseServiceErrorCodeNoPrivateKey];
    }
    if (!senderInfo) {
        return [TLCipherResult errorWithErrorCode:TLBaseServiceErrorCodeNoPrivateKey];
    }

    int version = [TLCryptoService getEncryptVersion:keyInfo.encryptionKind publicKind:targetKey.encryptionKind];
    if (version <= 0) {
        return [TLCipherResult errorWithErrorCode:TLBaseServiceErrorCodeInvalidPrivateKey];
    }
    NSData *salt = [NSData secureRandomWithLength:TL_KEY_LENGTH];
    int64_t nonceSequence = [keyInfo nonceSequence];

    NSMutableData *auth = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryCompactEncoder *encoder = [[TLBinaryCompactEncoder alloc] initWithData:auth];

    // Not encrypted content which is authenticated by the private key:
    // - version identifying the encryption method
    // - nonce sequence (because it's easier to transmit that way),
    // - salt used for the key generation,
    // - the twincode used for the authenticate+encrypt,
    // - either:
    //   1 => the twincode used for encryption (the receiver MUST know and trust that twincode),
    //   2 => the public key used for authenticate+encrypt.
    [encoder writeInt:version];
    [encoder writeLong:nonceSequence];
    [encoder writeData:salt];
    [encoder writeOptionalUUID:senderTwincode.uuid];
    if (cipherTwincode != senderTwincode) {
        [encoder writeEnum:1];
        [encoder writeUUID:cipherTwincode.uuid];
    } else {
        [encoder writeEnum:2];
        [encoder writeOptionalString:[keyInfo publicBase64EncryptionKey]];
    }

    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    encoder = [[TLBinaryCompactEncoder alloc] initWithData:data];
    [encoder writeOptionalString:[senderInfo publicBase64SigningKey]];
    if (options != 0) {
        [encoder writeInt:senderInfo.keyIndex];
        [encoder writeOptionalData:senderInfo.secretKey];
    } else {
        // Secure invocation without sending a secret.
        [encoder writeInt:0];
        [encoder writeOptionalData:nil];
    }
    [encoder writeAttributes:attributes];

    TLCryptoBox *cipherBox = [TLCryptoBox createWithKind:TLCryptoBoxKindAES_GCM];
    int result = [cipherBox bindWithKey:keyInfo.encryptionKey peerPublicKey:targetKey.encryptionKey encrypt:YES salt:salt];
    if (result != 1) {
        return [TLCipherResult errorWithErrorCode:TLBaseServiceErrorCodeInvalidPrivateKey];
    }

    NSMutableData *output = [[NSMutableData alloc] initWithLength:data.length + auth.length + 64];
    int len = [cipherBox encryptAEAD:nonceSequence data:data auth:auth output:output];
    if (len <= 0) {
        return [TLCipherResult errorWithErrorCode:TLBaseServiceErrorCodeEncryptError];
    }
    return [TLCipherResult initWithData:output length:len];
}

/// Decrypt and authenticate the message received by using the private key associated with the twincode.
- (nonnull TLDecipherResult *)decryptWithTwincode:(nonnull TLTwincodeOutbound *)receiverTwincode encrypted:(nonnull NSData *)encrypted {
    DDLogVerbose(@"%@: decryptWithTwincode: %@", LOG_TAG, receiverTwincode);

    if (!self.serviceOn) {
        return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeServiceUnavailable];
    }

    TLBinaryCompactDecoder *decoder = [[TLBinaryCompactDecoder alloc] initWithData:encrypted];
    // Extract information from the clear content are which is authenticated by the private key:
    // - version identifying the encryption method
    // - the nonce,
    // - salt used for the key generation,
    // - the optional sender twincode,
    // - either:
    //   1 => the twincode used for encryption (the receiver MUST know and trust that twincode),
    //   2 => the public key used for authenticate+encrypt.
    //   * => error
    int version = [decoder readInt];
    int64_t nonceSequence = [decoder readLong];
    NSData *salt = [decoder readData];
    NSUUID *twincodeId = [decoder readOptionalUUID];
    int encryptionKey = [decoder readEnum];
    NSString *pubEncryptionKey;
    NSUUID *cipherTwincodeId;
    TLKeyInfo *cipherKeyInfo;
    TLTrustMethod trustMethod;
    switch (encryptionKey) {
        case 1:
            cipherTwincodeId = [decoder readUUID];

            // Get the sender encryption key since we must know the twincode.
            // That twincode is a Profile or Invitation and the associated public key should be trusted.
            cipherKeyInfo = [self.serviceProvider loadPeerEncryptionKeyWithTwincodeId:cipherTwincodeId];
            if (!cipherKeyInfo) {
                return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeNoPublicKey];
            }
            pubEncryptionKey = [cipherKeyInfo publicBase64EncryptionKey];
            trustMethod = [cipherKeyInfo.twincodeOutbound trustMethod];
            break;

        case 2:
            // This invocation is made with a public key that is not yet trusted.
            // The `trusted` flag gets propagated up to ProcessInvocation which could retrieve
            // a peer's twincode with getSignedTwincode() and that twincode will not be trusted yet.
            pubEncryptionKey = [decoder readOptionalString];
            if (twincodeId) {
                // Look if we trust the twincode.
                cipherKeyInfo = [self.serviceProvider loadPeerEncryptionKeyWithTwincodeId:twincodeId];
                if (cipherKeyInfo) {
                    trustMethod = cipherKeyInfo.twincodeOutbound.trustMethod;
                } else {
                    trustMethod = TLTrustMethodNone;
                }
            } else {
                trustMethod = TLTrustMethodNone;
            }
            break;

        default:
            return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeBadEncryptionFormat];
    }
    if (!pubEncryptionKey) {
        return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeInvalidPublicKey];
    }

    TLCryptoKey *senderPublicKey;
    switch (version) {
        case ENCRYPT_VERSION_X25519:
            senderPublicKey = [TLCryptoKey importPublicKey:TLCryptoKindX25519 pubKey:[pubEncryptionKey dataUsingEncoding:NSUTF8StringEncoding] isBase64:YES];
            break;

        case ENCRYPT_VERSION_ECDSA:
            senderPublicKey = [TLCryptoKey importPublicKey:TLCryptoKindECDSA pubKey:[pubEncryptionKey dataUsingEncoding:NSUTF8StringEncoding] isBase64:YES];
            break;

        default:
            return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignature];

    }
    if (!senderPublicKey) {
        return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeInvalidPublicKey];
    }

    // Get the receiver twincode private key.
    TLKeyInfo *keyInfo = [self.serviceProvider loadKeyWithTwincode:receiverTwincode];
    if (!keyInfo || !keyInfo.encryptionKey) {
        return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeNoPrivateKey];
    }

    TLCryptoBox *cipherBox = [TLCryptoBox createWithKind:TLCryptoBoxKindAES_GCM];
    int result = [cipherBox bindWithKey:keyInfo.encryptionKey peerPublicKey:senderPublicKey encrypt:NO salt:salt];
    if (result != 1) {
        return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeNoPrivateKey];
    }

    NSMutableData *output = [[NSMutableData alloc] initWithLength:encrypted.length + 64];
    int len = [cipherBox decryptAEAD:nonceSequence data:encrypted authLength:(int)decoder.read output:output];
    if (len <= 0) {
        return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeDecryptError];
    }

    // Extract the attributes from the decrypted content.
    decoder = [[TLBinaryCompactDecoder alloc] initWithData:output];
    NSString *pubSigningKey = [decoder readOptionalString];
    int keyIndex = [decoder readInt];
    NSData *secretKey = [decoder readOptionalData];
    NSMutableArray<TLAttributeNameValue *> *attributes = [decoder readAttributes];
    if (!attributes) {
        return [TLDecipherResult errorWithErrorCode:TLBaseServiceErrorCodeBadSignatureFormat];
    }

    return [TLDecipherResult initWithAttributes:attributes peerTwincodeId:twincodeId keyIndex:keyIndex secretKey:secretKey publicKey:pubSigningKey trustMethod:trustMethod];
}

- (void)createPrivateKeyWithTransaction:(nonnull TLTransaction *)transaction twincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@: createPrivateKeyWithTransaction: %@ twincodeOutbound: %@", LOG_TAG, twincodeInbound, twincodeOutbound);

    [self.serviceProvider insertKeyWithTransaction:transaction twincodeOutbound:twincodeOutbound flags:TL_KEY_TYPE_25519];
}

- (TLBaseServiceErrorCode)createPrivateKeyWithTwincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound {
    DDLogVerbose(@"%@: createPrivateKeyWithTwincodeInbound: %@ twincodeOutbound: %@", LOG_TAG, twincodeInbound, twincodeOutbound);

    return [self.serviceProvider insertKeyWithTwincodeOutbound:twincodeOutbound flags:TL_KEY_TYPE_25519];
}

- (void)saveSecretKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound keyIndex:(int)keyIndex secretKey:(nonnull NSData *)secretKey {
    DDLogVerbose(@"%@ saveSecretKeyWithTwincode: %@ peerTwincodeOutbound: %@ keyIndex: %d secretKey: %@", LOG_TAG, twincodeOutbound, peerTwincodeOutbound, keyIndex, secretKey);

    [self.serviceProvider saveSecretKeyWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound keyIndex:keyIndex secretKey:secretKey];
}

- (void)validateSecretWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ validateSecretWithTwincode: %@ peerTwincodeOutbound: %@", LOG_TAG, twincodeOutbound, peerTwincodeOutbound);

    [self.serviceProvider validateSecretWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound];
}

- (TLBaseServiceErrorCode)createKeyPairWithSessionId:(nonnull NSUUID *)sessionId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound keyPair:(id<TLSessionKeyPair> _Nullable *_Nullable)keyPair strict:(BOOL)strict {
    DDLogVerbose(@"%@: createKeyPairWithSessionId: %@ twincodeOutbound: %@ peerTwincodeOutbound: %@ strict: %d", LOG_TAG, sessionId, twincodeOutbound, peerTwincodeOutbound, strict);

    return [self.serviceProvider prepareWithSessionId:sessionId twincodeOutbound:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound keyPair:keyPair strict:strict];
}

- (nullable TLSdp *)encryptWithSessionKeyPair:(nonnull id<TLSessionKeyPair>)sessionKeyPair sdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode {
    DDLogVerbose(@"%@: encryptWithSessionKeyPair: %@", LOG_TAG, sessionKeyPair);

    TLSdp *result = [sessionKeyPair encryptWithSdp:sdp errorCode:errorCode];

    // When there is no more nonce sequence, we get the NoPrivateKey error and we must get a new
    // block of nonce sequences from the secret key pair in the database.
    if (!result && *errorCode == TLBaseServiceErrorCodeNoPrivateKey && [(NSObject *)sessionKeyPair isKindOfClass:[TLSessionSecretKeyPair class]]) {
        [self.serviceProvider refreshWithSessionKeyPair:(TLSessionSecretKeyPair *)sessionKeyPair];
        result = [sessionKeyPair encryptWithSdp:sdp errorCode:errorCode];
    }
    return result;
}

- (nullable TLSignatureInfoIQ *)getSignatureInfoIQWithTwincode:(nonnull TLTwincodeOutbound*)twincodeOutbound peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode renew:(BOOL)renew {
    DDLogVerbose(@"%@: getSignatureInfoIQWithTwincode: %@ peerTwincode: %@ renew: %d", LOG_TAG, twincodeOutbound, peerTwincode, renew);
    
    if (!self.serviceOn) {
        return nil;
    }

    TLKeyInfo *keyInfo = [self.serviceProvider loadKeySecretsWithTwincode:twincodeOutbound peerTwincode:peerTwincode useSequenceCount:0 options:renew ? TLCryptoServiceProviderCreateNextSecret : TLCryptoServiceProviderCreateFirstSecret];
    
    if (!keyInfo) {
        return nil;
    }
    
    NSData *secretKey = keyInfo.secretKey;
    NSString *publicKey = keyInfo.publicBase64SigningKey;
    
    if (!secretKey || !publicKey) {
        return nil;
    }
    
    return [[TLSignatureInfoIQ alloc] initWithSerializer:TLSignatureInfoIQ.SERIALIZER requestId:[TLTwinlife newRequestId] twincodeOutboundId:twincodeOutbound.uuid publicKey:publicKey keyIndex:keyInfo.keyIndex secret:secretKey];
}

@end

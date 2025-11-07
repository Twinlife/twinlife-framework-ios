/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <WebRTC/TLCryptoKey.h>
#import "TLBaseServiceImpl.h"
#import "TLCryptoService.h"

@class TLCryptoServiceProvider;
@class TLTransaction;
@class TLTwincodeInbound;

#define TL_KEY_TYPE_MASK    0x0ff
#define TL_KEY_TYPE_25519       1
#define TL_KEY_TYPE_ECDSA       2
#define TL_KEY_PRIVATE_FLAG 0x100

//
// Interface: TLKeyInfo
//

@interface TLKeyInfo : NSObject

@property (readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (readonly) TLCryptoKind signKind;
@property (readonly) TLCryptoKind encryptionKind;
@property (readonly, nullable) TLCryptoKey *encryptionKey;
@property (readonly, nullable) TLCryptoKey *signingKey;
@property (readonly, nullable) NSData *secretKey;
@property (readonly) int keyIndex;
@property int64_t nonceSequence;

- (nonnull instancetype)initWithTwincode:(nonnull TLTwincodeOutbound *)twincode modificationDate:(int64_t)modificationDate flags:(int)flags signingKey:(nullable NSData *)signingKey encryptionKey:(nullable NSData *)encryptionKey nonceSequence:(int64_t)nonceSequence keyIndex:(int)keyIndex secret:(nullable NSData *)secret;

+ (TLCryptoKind)toCryptoKindWithFlags:(int)flags encrypt:(BOOL)encrypt;

- (nullable NSString *)publicBase64EncryptionKey;

- (nullable NSString *)publicBase64SigningKey;

@end

//
// Interface: TLKeyPair
//

@interface TLKeyPair : NSObject

@property (readonly, nullable) TLCryptoKey *privateKey;
@property (readonly, nullable) TLCryptoKey *peerPublicKey;
@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nonnull) NSUUID *peerTwincodeId;
@property (readonly, nonnull) NSUUID *subjectId;

- (nonnull instancetype)initWithFlags:(int)flags privKey:(nonnull NSData *)privKey peerFlags:(int)peerFlags peerPubKey:(nonnull NSData *)peerPubKey twincodeId:(nonnull NSUUID *)twincodeId peerTwincodeId:(nonnull NSUUID *)peerTwincodeId subjectId:(nonnull NSUUID *)subjectId;

@end

//
// Interface: TLVerifyResult
//

@interface TLVerifyResult ()

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode signingKey:(nullable NSData *)signingKey encryptionKey:(nullable NSData *)encryptionKey imageSha:(nullable NSData *)imageSha;

+ (nonnull TLVerifyResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

+ (nonnull TLVerifyResult *)initWithSigningKey:(nonnull NSData *)signingKey encryptionKey:(nullable NSData *)encryptionKey imageSha:(nullable NSData *)imageSha;

@end

//
// Interface: TLCipherResult
//

@interface TLCipherResult ()

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode data:(nullable NSData *)data length:(int)length;

+ (nonnull TLCipherResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

+ (nonnull TLCipherResult *)initWithData:(nullable NSData *)data length:(int)length;

@end

//
// Interface: TLDecipherResult
//

@interface TLDecipherResult ()

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode attributes:(nullable NSArray<TLAttributeNameValue *> *)attributes peerTwincodeId:(nullable NSUUID *)peerTwincodeId keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey publicKey:(nullable NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod;

+ (nonnull TLDecipherResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

+ (nonnull TLDecipherResult *)initWithAttributes:(nullable NSArray<TLAttributeNameValue *> *)attributes peerTwincodeId:(nullable NSUUID *)peerTwincodeId keyIndex:(int)keyIndex secretKey:(nullable NSData *)secretKey publicKey:(nullable NSString *)publicKey trustMethod:(TLTrustMethod)trustMethod;

@end

//
// Interface: TLSignResult
//

@interface TLSignResult : NSObject

@property (readonly) TLBaseServiceErrorCode errorCode;
@property (readonly, nullable) NSString *signature;

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode signature:(nullable NSString *)signature;

+ (nonnull TLSignResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

+ (nonnull TLSignResult *)initWithSignature:(nonnull NSString *)signature;

@end

//
// Interface: TLSignResult
//

@interface TLVerifyAuthenticateResult : NSObject

@property (readonly) TLBaseServiceErrorCode errorCode;
@property (readonly, nullable) NSUUID *subjectId;

- (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode subjectId:(nullable NSUUID *)subjectId;

+ (nonnull TLVerifyAuthenticateResult *)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

+ (nonnull TLVerifyAuthenticateResult *)initWithSubjectId:(nonnull NSUUID *)subjectId;

@end

//
// Interface: TLCryptoService ()
//

@interface TLCryptoService ()

+ (void)initialize;

/// Internal method to create the private keys when a new twincode is created.
- (void)createPrivateKeyWithTransaction:(nonnull TLTransaction *)transaction twincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (TLBaseServiceErrorCode)createPrivateKeyWithTwincodeInbound:(nonnull TLTwincodeInbound *)twincodeInbound twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (void)saveSecretKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound keyIndex:(int)keyIndex secretKey:(nonnull NSData *)secretKey;

- (void)validateSecretWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound;

- (nullable TLSignatureInfoIQ *)getSignatureInfoIQWithTwincode:(nonnull TLTwincodeOutbound*)twincodeOutbound peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode renew:(BOOL)renew;

- (TLBaseServiceErrorCode)createKeyPairWithSessionId:(nonnull NSUUID *)sessionId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound keyPair:(id<TLSessionKeyPair> _Nullable *_Nullable)keyPair strict:(BOOL)strict;

/// Create the authenticate signature for the twincode's relation.
- (nonnull TLSignResult *)signAuthenticateWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound;

- (nonnull TLVerifyAuthenticateResult *)verifyAuthenticateWithSignature:(nonnull NSString *)signature;

- (nullable NSString *)signContentWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound content:(nonnull NSData *)content;

- (TLBaseServiceErrorCode)verifyContentWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound content:(nonnull NSData *)content signature:(nonnull NSString *)signature;

- (nullable TLSdp *)encryptWithSessionKeyPair:(nonnull id<TLSessionKeyPair>)sessionKeyPair sdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode;

@end

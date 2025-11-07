/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"
#import "TLTwincode.h"

@class TLTwincodeOutbound;
@class TLAttributeNameValue;
@class TLSdp;
@class TLSignatureInfoIQ;

#define TLCryptoServiceUseSecret1   0x01
#define TLCryptoServiceUseSecret2   0x02
#define TLCryptoServiceNewSecret1   0x10
#define TLCryptoServiceNewSecret2   0x20

//
// Interface: TLVerifyResult
//

@interface TLVerifyResult : NSObject

@property (readonly, nonatomic) TLBaseServiceErrorCode errorCode;
@property (readonly, nonatomic, nullable) NSData *publicSigningKey;
@property (readonly, nonatomic, nullable) NSData *publicEncryptionKey;
@property (readonly, nonatomic, nullable) NSData *imageSha;

@end

//
// Interface: TLCipherResult
//

@interface TLCipherResult : NSObject

@property (readonly, nonatomic) TLBaseServiceErrorCode errorCode;
@property (readonly, nonatomic, nullable) NSData *data;
@property (readonly, nonatomic) int length;

@end

//
// Interface: TLDecipherResult
//

@interface TLDecipherResult : NSObject

@property (readonly, nonatomic) TLBaseServiceErrorCode errorCode;
@property (readonly, nonatomic, nullable) NSMutableArray<TLAttributeNameValue *> *attributes;
@property (readonly, nonatomic, nullable) NSUUID *peerTwincodeId;
@property (readonly, nonatomic, nullable) NSData *secretKey;
@property (readonly, nonatomic, nullable) NSString *publicKey;
@property (readonly, nonatomic) int keyIndex;
@property (readonly, nonatomic) TLTrustMethod trustMethod;

@end

//
// Protocol: TLSessionKeyPair
//

@protocol TLSessionKeyPair

@property (readonly, nonatomic, nonnull) NSUUID *sessionId;

- (int64_t)sequenceCount;

- (int64_t)nonceSequence;

- (int64_t)allocateNonce;

- (BOOL)needRenew;

- (nullable TLSdp *)encryptWithSdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode;

- (nullable TLSdp *)decryptWithSdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode;

@end

//
// Interface: TLCryptoServiceConfiguration
//

@interface TLCryptoServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Interface: TLCryptoService
//

@interface TLCryptoService : TLBaseService

+ (nonnull NSString *)VERSION;

/// Get the public key encoded in Base64url associated with the twincode.
- (nullable NSString *)getPublicKeyWithTwincode:(nonnull TLTwincodeOutbound*)twincodeOutbound;

/// Sign the twincode attributes by using the twincode private key.
- (nullable NSData *)signWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound attributes:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes;

/// Verify the signature of the twincode attributes by using the public key encoded in Base64url
/// or by using the public key already associated with the twincodeOutbound object.
- (nonnull TLVerifyResult *)verifyWithPublicKey:(nonnull NSString *)publicKey twincodeId:(nonnull NSUUID *)twincodeId attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nonnull NSData *)signature;

- (nonnull TLVerifyResult *)verifyWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes signature:(nonnull NSData *)signature;

/// Encrypt by using the encryption keys defined for the `cipherTwincode` for a message to the
/// `targetTwincode`.  Give in the message the public keys used by the `senderTwincode`
/// (which can be the `cipherTwincode`).
- (nonnull TLCipherResult *)encryptWithTwincode:(nonnull TLTwincodeOutbound *)cipherTwincode senderTwincode:(nonnull TLTwincodeOutbound *)senderTwincode targetTwincode:(nonnull TLTwincodeOutbound *)targetTwincode options:(int)options attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes;

/// Decrypt and authenticate the message received by using the private key associated with the twincode.
- (nonnull TLDecipherResult *)decryptWithTwincode:(nonnull TLTwincodeOutbound *)receiverTwincode encrypted:(nonnull NSData *)encrypted;

@end

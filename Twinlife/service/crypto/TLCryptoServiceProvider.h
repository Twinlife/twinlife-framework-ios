/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#include "TLDatabaseServiceProvider.h"
#import "TLImageServiceProvider.h"

@protocol TLSessionKeyPair;
@class TLCryptoService;
@class TLTwincodeOutbound;
@class TLKeyInfo;
@class TLKeyPair;
@class TLSessionSecretKeyPair;

// Create a secret and mark it is as ready to be used.
// Flags are immediately set with USE_SECRET1
#define TLCryptoServiceProviderCreateSecret     0x01

// Create the next secret for the relation:
// - if there is no secret, secret1 is allocated
// - if secret1 is in use, the next secret is allocated in secret2
// - if secret2 is in use, the next secret is allocated in secret1
// Note: secret1 and secret2 cannot be used at the same time.
// Flags are set with NEW_SECRET1 or NEW_SECRET2 and a call to validateSecrets()
// is necessary to turn the NEW_SECRETx into the USE_SECRETx flag.
#define TLCryptoServiceProviderCreateNextSecret 0x02

// Create the first secret to be exchanged when upgrading a non-encrypted relation to an encrypted one.
#define TLCryptoServiceProviderCreateFirstSecret 0x04

//
// Interface: TLCryptoServiceProvider
//

@interface TLCryptoServiceProvider : TLDatabaseServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLCryptoService *)service database:(nonnull TLDatabaseService *)database;

- (nullable TLKeyInfo *)loadPeerEncryptionKeyWithTwincodeId:(nonnull NSUUID *)twincodeId;

/// Load the twincode signing and encryption keys with flags.
- (nullable TLKeyInfo *)loadKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincode;

/// Load the twincode signing and encryption keys with the secret key to talk to the given peer twincode.
/// When `options` is set, a new secret is created and associated with the pair (twincode, peerTwincode).
- (nullable TLKeyInfo *)loadKeySecretsWithTwincode:(nonnull TLTwincodeOutbound *)twincode peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode useSequenceCount:(long)useSequenceCount options:(int)options;

- (nullable TLKeyPair *)loadKeyPairWithTwincode:(nonnull TLTwincodeOutbound *)twincode;

- (nullable TLKeyPair *)loadKeyPairWithKey:(nonnull NSData *)key;

- (nullable TLImageInfo *)loadImageInfoWithId:(int64_t)identifier;

/// Save the secret key used to decrypt the SDPs sent by the peer with the given twincode.
- (void)saveSecretKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound keyIndex:(int)keyIndex secretKey:(nonnull NSData *)secretKey;

- (void)validateSecretWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound;

- (TLBaseServiceErrorCode)insertKeyWithTransaction:(nonnull TLTransaction *)transaction twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound flags:(int)flags;

- (TLBaseServiceErrorCode)insertKeyWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound flags:(int)flags;

/// Prepare to encrypt/decrypt the SDPs to establish a WebRTC session:
/// - if we have the peer twincode, the encryption is based on secrets that were exchanged when the relation was established.
/// - if there is no peer twincode (ex: click-to-call), we use the encryption key.
/// A nonce sequence is allocated and allows to make up to SessionKeyPairImpl.MAX_EXCHANGE encryptions.
/// After that, the `prepareSession` must be called again to allocate a new nonce sequence.
- (TLBaseServiceErrorCode)prepareWithSessionId:(nonnull NSUUID *)sessionId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound keyPair:(id<TLSessionKeyPair> _Nullable *_Nullable)keyPair strict:(BOOL)strict;

/// Refresh the session key pair when the nonce sequence block was fully used and we need more nonce sequences.
- (TLBaseServiceErrorCode)refreshWithSessionKeyPair:(nonnull TLSessionSecretKeyPair *)sessionKeyPair;

@end

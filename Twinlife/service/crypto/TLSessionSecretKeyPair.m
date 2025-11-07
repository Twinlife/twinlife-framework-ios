/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <WebRTC/TLCryptoBox.h>
#import "TLSessionSecretKeyPair.h"
#import "TLCryptoServiceImpl.h"
#import "TLBinaryCompactDecoder.h"
#import "TLBinaryCompactEncoder.h"
#import "TLSdp.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define LOG_TAG @"TLSessionSecretKeyPair"

#if defined(DEBUG) && DEBUG == 1
# define SECRET_RENEW_DELAY (300 * 1000L) // 5mn to stress development
#else
# define SECRET_RENEW_DELAY (30L * 86400L * 1000L) // 30 days
#endif

//
// Interface: TLSessionSecretKeyPair
//

@interface TLSessionSecretKeyPair ()

@property (readonly, nonnull) NSData *secret;
@property (readonly, nonnull) NSData *peerSecret1;
@property (readonly, nullable) NSData *peerSecret2;
@property (readonly) int keyIndex;
@property (readonly) BOOL needRenew;
@property int64_t nonceSequence;
@property int64_t sequenceCounter;

@end

//
// Implementation: TLSessionSecretKeyPair
//

@implementation TLSessionSecretKeyPair

- (nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound privKeyFlags:(int)privKeyFlags secretUpdateDate:(int64_t)secretUpdateDate nonceSequence:(int64_t)nonceSequence keyIndex:(int)keyIndex secret:(nonnull NSData *)secret peerSecret1:(nonnull NSData *)peerSecret1 peerSecret2:(nullable NSData *)peerSecret2 {
    DDLogVerbose(@"%@ initWithSessionId: %@ twincodeOutbound: %@ peerTwincodeOutbound: %@", LOG_TAG, sessionId, twincodeOutbound, peerTwincodeOutbound);

    self = [super init];
    if (self) {
        _sessionId = sessionId;
        _twincodeOutbound = twincodeOutbound;
        _peerTwincodeOutbound = peerTwincodeOutbound;
        _keyIndex = keyIndex;
        _secret = secret;
        _peerSecret1 = peerSecret1;
        _peerSecret2 = peerSecret2;
        _nonceSequence = nonceSequence;
        _sequenceCounter = MAX_EXCHANGE;

        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
        _needRenew = secretUpdateDate + SECRET_RENEW_DELAY < now;
    }
    return self;
}

- (nullable NSData *)getSecretWithKeyIndex:(int)keyIndex {

    return keyIndex == 1 ? self.peerSecret1 : self.peerSecret2;
}

- (void)refreshWithNonceSequence:(int64_t)nonceSequence {
    
    self.nonceSequence = nonceSequence;
    self.sequenceCounter = MAX_EXCHANGE;
}

- (nullable TLSdp *)encryptWithSdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode {
    DDLogVerbose(@"%@ encryptWithSdp: %@", LOG_TAG, sdp);
    
    int64_t nonceSequence = [self allocateNonce];
    if (nonceSequence == 0) {
        *errorCode = TLBaseServiceErrorCodeNoPrivateKey;
        return nil;
    }
    
    // Not encrypted content which is authenticated by the private key:
    // - P2P session id (also acts as random nonce),
    // - nonce sequence (because it's easier to transmit that way),
    NSMutableData *auth = [[NSMutableData alloc] initWithCapacity:128];
    TLBinaryCompactEncoder *encoder = [[TLBinaryCompactEncoder alloc] initWithData:auth];
    [encoder writeUUID:self.sessionId];
    [encoder writeLong:nonceSequence];
    
    TLCryptoBox *cipherBox = [TLCryptoBox createWithKind:TLCryptoBoxKindAES_GCM];
    int result = [cipherBox bindWithKey:self.secret];
    if (result != 1) {
        *errorCode = TLBaseServiceErrorCodeInvalidPrivateKey;
        return nil;
    }
    
    NSData *sdpData = [sdp data];
    NSMutableData *output = [[NSMutableData alloc] initWithLength:sdpData.length + auth.length + 64];
    int len = [cipherBox encryptAEAD:nonceSequence data:sdpData auth:auth output:output];
    if (len <= 0) {
        *errorCode = TLBaseServiceErrorCodeEncryptError;
        return nil;
    }

    output.length = len;
    *errorCode = TLBaseServiceErrorCodeSuccess;
    return [[TLSdp alloc] initWithData:output compressed:[sdp isCompressed] keyIndex:self.keyIndex];
}

- (nullable TLSdp *)decryptWithSdp:(nonnull TLSdp *)sdp errorCode:(nonnull TLBaseServiceErrorCode *)errorCode {
    DDLogVerbose(@"%@ decryptWithSdp: %@", LOG_TAG, sdp);
    
    if (![sdp isEncrypted]) {
        *errorCode = TLBaseServiceErrorCodeSuccess;
        return sdp;
    }
    
    NSData *encrypted = sdp.data;
    
    // Extract information from the clear content which is authenticated by the secret key:
    // - P2P sessionId (which must match our P2P sessionId)
    // - nonce sequence
    TLBinaryCompactDecoder *decoder = [[TLBinaryCompactDecoder alloc] initWithData:encrypted];
    NSUUID *sessionId = [decoder readUUID];
    int64_t nonceSequence = [decoder readLong];
    if (![self.sessionId isEqual:sessionId]) {
        *errorCode = TLBaseServiceErrorCodeBadSignature;
        return nil;
    }
    
    TLCryptoBox *cipherBox = [TLCryptoBox createWithKind:TLCryptoBoxKindAES_GCM];
    NSData *secret = [self getSecretWithKeyIndex:[sdp getKeyIndex]];
    if (!secret) {
        *errorCode = TLBaseServiceErrorCodeNoSecretKey;
        return nil;
    }

    int result = [cipherBox bindWithKey:secret];
    if (result != 1) {
        *errorCode = TLBaseServiceErrorCodeDecryptError;
        return nil;
    }
    
    NSMutableData *output = [[NSMutableData alloc] initWithLength:encrypted.length];
    int len = [cipherBox decryptAEAD:nonceSequence data:encrypted authLength:(int)decoder.read output:output];
    if (len <= 0) {
        *errorCode = TLBaseServiceErrorCodeDecryptError;
        return nil;
    }

    output.length = len;
    *errorCode = TLBaseServiceErrorCodeSuccess;
    return [[TLSdp alloc] initWithData:output compressed:[sdp isCompressed] keyIndex:0];
}

- (int64_t)allocateNonce { 
    
    @synchronized (self) {
        if (self.sequenceCount <= 0) {
            return 0;
        }
        self.sequenceCounter--;
        self.nonceSequence++;
        return self.nonceSequence;
    }
}

- (int64_t)sequenceCount { 
    
    return self.sequenceCounter;
}

@end

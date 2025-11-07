/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLCryptoService.h"

#define MAX_EXCHANGE 100

@class TLSdp;

//
// Interface: TLSessionSecretKeyPair
//

@interface TLSessionSecretKeyPair : NSObject <TLSessionKeyPair>

@property (readonly, nonnull) NSUUID *sessionId;
@property (readonly, nonnull) TLTwincodeOutbound *twincodeOutbound;
@property (readonly, nonnull) TLTwincodeOutbound *peerTwincodeOutbound;

- (nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound privKeyFlags:(int)privKeyFlags secretUpdateDate:(int64_t)secretUpdateDate nonceSequence:(int64_t)nonceSequence keyIndex:(int)keyIndex secret:(nonnull NSData *)secret peerSecret1:(nonnull NSData *)peerSecret1 peerSecret2:(nullable NSData *)peerSecret2;

- (void)refreshWithNonceSequence:(int64_t)nonceSequence;

@end

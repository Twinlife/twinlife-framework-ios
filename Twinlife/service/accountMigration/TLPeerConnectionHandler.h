/*
 *  Copyright (c) 2024-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPeerConnectionServiceImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLDataChannelHandler.h"

@interface TLPeerConnectionHandler : TLDataChannelHandler <TLPeerConnectionServiceDelegate, TLPeerConnectionDelegate>

@property (nonatomic, readonly, nonnull) TLTwinlife *twinlife;
@property (nonatomic, nullable) TLVersion *peerVersion;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife peerId:(nonnull NSString *)peerId;

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding;

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onTerminateWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)finish;

- (void)closeConnection;

- (void)onTwinlifeOnline; 

- (void)onDisconnect;

- (void)onDataChannelOpen;

- (void)onTimeout;

- (void)startOutgoingConnection;

- (void)startIncomingConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;
@end

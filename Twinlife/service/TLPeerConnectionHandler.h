/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPeerConnectionServiceImpl.h"
#import "TLTwinlifeImpl.h"

@interface TLPeerConnectionHandler : NSObject <TLPeerConnectionDataChannelDelegate, TLPeerConnectionServiceDelegate, TLPeerConnectionDelegate>

@property (nonatomic, readonly, nonnull) TLTwinlife *twinlife;

@property (nonatomic, readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (nonatomic, nullable) NSUUID *peerConnectionId;
@property (nonatomic, readonly, nonnull) TLSerializerFactory *serializerFactory;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife peerId:(nonnull NSString *)peerId;

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLBinaryPacketListener)listener;

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding;

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onDataChannelMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId data:(nonnull NSData *)data leadingPadding:(BOOL)leadingPadding;

- (BOOL)sendMessageWithIQ:(nonnull TLBinaryPacketIQ *)iq statType:(TLPeerConnectionServiceStatType)statType;

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

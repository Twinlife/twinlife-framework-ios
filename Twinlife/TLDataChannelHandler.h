/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPeerConnectionService.h"
#import "TLAssertion.h"

@class TLBinaryDecoder;
@class TLBinaryPacketIQSerializer;
typedef void (^TLBinaryPacketListener) (TLBinaryPacketIQ * _Nonnull iq);

//
// Interface: TLConversationHandler
//

@interface TLDataChannelHandler : NSObject <TLPeerConnectionDataChannelDelegate>

@property (nonatomic, readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (nonatomic, nullable) NSUUID *peerConnectionId;
@property (nonatomic, readonly, nonnull) TLSerializerFactory *serializerFactory;

- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService;

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLBinaryPacketListener)listener;

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding;

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onDataChannelMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId data:(nonnull NSData *)data leadingPadding:(BOOL)leadingPadding;

- (BOOL)sendMessageWithIQ:(nonnull TLBinaryPacketIQ *)iq statType:(TLPeerConnectionServiceStatType)statType;

/// Check and process the IQ if it corresponds to one of our SDP data channel handler.  Returns YES if the IQ was recognized.
+ (BOOL)processSdpPacketWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService key:(nonnull TLSerializerKey *)key peerConnectionId:(nonnull NSUUID *)peerConnectionId binaryDecoder:(nonnull TLBinaryDecoder *)binaryDecoder;

@end

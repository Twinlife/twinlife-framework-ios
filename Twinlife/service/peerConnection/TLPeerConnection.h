/*
 *  Copyright (c) 2013-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Zhuoyu Ma (Zhuoyu.Ma@twinlife-systems.com)
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPeerConnectionServiceImpl.h"
#import "TLAssertion.h"

//
// Interface: TLPeerConnectionControlPoint
//

@interface TLPeerConnectionAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)CREATE_PEER_CONNECTION;
+(nonnull TLAssertPoint *)CREATE_DATA_CHANNEL;
// +(nonnull TLAssertPoint *)CREATE_AUDIO_SOURCE;
+(nonnull TLAssertPoint *)CREATE_AUDIO_TRACK;
+(nonnull TLAssertPoint *)CREATE_VIDEO_TRACK;
+(nonnull TLAssertPoint *)OFFER_FAILURE;
+(nonnull TLAssertPoint *)SET_LOCAL_FAILURE;
+(nonnull TLAssertPoint *)SET_REMOTE_FAILURE;
+(nonnull TLAssertPoint *)ENCRYPT_ERROR;
+(nonnull TLAssertPoint *)DECRYPT_ERROR_1;
+(nonnull TLAssertPoint *)DECRYPT_ERROR_2;

@end

//
// Interface: TLPeerConnection
//

@protocol TLSessionKeyPair;
@class TLTransportCandidate;
@class RTC_OBJC_TYPE(RTCDataChannelInit);
@class RTC_OBJC_TYPE(RTCPeerConnectionFactory);

@interface TLPeerConnection : NSObject

@property (readonly, nonnull) NSUUID *uuid;
@property (nullable) TLOffer *offer;
@property (nullable) TLOfferToReceive *offerToReceive;
@property (nonatomic, nullable, setter=setPeerOffer:) TLOffer *peerOffer;
@property (nullable) TLOfferToReceive *peerOfferToReceive;
@property (readonly, nonnull) NSString *peerId;
@property (nullable) id<TLPeerConnectionDelegate> delegate;
@property (nullable) id<TLSessionKeyPair> keyPair;

/// Create an outgoing P2P connection.
- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService sessionId:(nonnull NSUUID *)sessionId sessionKeyPair:(nullable id<TLSessionKeyPair>)sessionKeyPair peerId:(nonnull NSString *)peerId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent*)notificationContent configuration:(nonnull TLBaseServiceImplConfiguration *)configuration delegate:(nonnull id<TLPeerConnectionDelegate>)delegate;

/// Create an incoming P2P connection.
- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService sessionId:(nonnull NSUUID *)sessionId peerId:(nonnull NSString *)peerId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive configuration:(nonnull TLBaseServiceImplConfiguration *)configuration sdp:(nonnull TLSdp *)sdp;

- (void)createIncomingPeerConnectionWithSessionDescription:(nullable RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block;

- (void)createOutgoingPeerConnectionWithDataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block;

- (void)initSourcesWithAudioOn:(BOOL)audioOn videoOn:(BOOL)videoOn;

- (TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatus;

- (BOOL)queueWithSdp:(nonnull TLSdp *)sdp;

- (nullable NSArray<TLSdp *> *)configureSessionKey:(nonnull id<TLSessionKeyPair>)sessionKeyPair;

- (void)setAudioDirection:(RTCRtpTransceiverDirection)direction;

- (void)setVideoDirection:(RTCRtpTransceiverDirection)direction;

- (void)acceptRemoteDescription:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription;

- (void)updateRemoteDescription:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription;

- (void)addIceCandidates:(nonnull NSArray<TLTransportCandidate *> *)candidates;

- (void)sendMessageWithData:(nonnull NSMutableData *)data statType:(TLPeerConnectionServiceStatType)statType;

- (void)sendPacketWithIQ:(nonnull TLBinaryPacketIQ *)iq statType:(TLPeerConnectionServiceStatType)statType;

- (void)incrementStatWithStatType:(TLPeerConnectionServiceStatType)statType;

- (void)sessionPing;

- (void)onTwinlifeSuspend;

- (void)terminatePeerConnectionWithTerminateReason:(TLPeerConnectionServiceTerminateReason)reason notifyPeer:(BOOL)notifyPeer;

- (void)sendDeviceRinging;

/// Check if the peer supports receiving SDP signaling (transport-info and session-update)
/// from the data-channel.  The preconditions:
/// - the peer version must be >= 2.3
/// - the data channel must be opened,
/// - the WebRTC connection must be connected.
/// @return true if we can send the SDP in the data-channel.
- (BOOL)isSignalingSupported;

/// Check if the session-update SDP was already received and handled.
/// @param sequenceId the session-update sequence ID.
/// @return true if the session-update was already received and false if this is a new session-update.
- (BOOL)wasReceivedWithSequenceId:(int64_t)sequenceId;

/// Allocate a new sequence ID for the session-update SDP that we send to the peer.
/// This is the low part (16-bits) of the real sequence id, the high part are created
/// from the Unix timestamp.  The sequence ID is allocated only for session-update.
/// @return the new sequence ID.
- (int)allocateSequenceId;

- (void)ackTransportWithRequestId:(int64_t)requestId;

@end

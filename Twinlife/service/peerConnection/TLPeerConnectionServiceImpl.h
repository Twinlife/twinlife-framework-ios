/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPeerConnectionService.h"
#import "TLBaseServiceImpl.h"
#import "TLPeerCallServiceImpl.h"

//
// Interface: TLPeerConnectionService ()
//

@class RTC_OBJC_TYPE(RTCConfiguration);
@class RTC_OBJC_TYPE(RTCPeerConnectionFactory);
@class RTC_OBJC_TYPE(RTCMediaStream);
@class RTC_OBJC_TYPE(RTCDataBuffer);
@class RTC_OBJC_TYPE(RTCVideoSource);
@class RTC_OBJC_TYPE(RTCCameraVideoCapturer);
@class RTC_OBJC_TYPE(RTCIceServer);
@class RTC_OBJC_TYPE(RTCHostname);
@class RTC_OBJC_TYPE(RTCPeerConnectionFactory);
@class RTC_OBJC_TYPE(RTCPeerConnection);
@class TLPeerConnection;
@class TLNetworkLock;
@class TLPeerCallService;
@class TLCryptoService;

@interface TLPeerConnectionService () <TLPeerSignalingDelegate>

@property (readonly, nonnull) TLPeerCallService *peerCallService;
@property (readonly, nonnull) TLCryptoService *cryptoService;
@property (readonly, nonnull) NSMutableDictionary<NSUUID *, TLPeerConnection *> *peerConnections;
@property (nonnull) TLBaseServiceImplConfiguration *configuration;
@property (nonnull) NSArray<RTC_OBJC_TYPE(RTCIceServer) *> *iceServers;
@property (nonnull) NSArray<RTC_OBJC_TYPE(RTCHostname) *> *hostnames;
@property (readonly, nonnull) dispatch_queue_t executorQueue;
@property (nullable) TLNetworkLock *networkLock;
@property (nonnull) RTC_OBJC_TYPE(RTCConfiguration) *peerConnectionConfiguration;
@property int videoConnections;
@property BOOL usingFrontCamera;
@property int videoFrameWidth;
@property int videoFrameHeight;
@property int videoFrameRate;

+ (nonnull NSString *)terminateReasonToString:(TLPeerConnectionServiceTerminateReason)reason;

+ (TLPeerConnectionServiceTerminateReason)stringToTerminateReason:(nonnull NSString *)reason;

/// Get a short peer connection diagnostics for problem reports.
- (nonnull NSString *)getP2PDiagnostics;

/// Get a peer connection factory with optional support for media
- (nonnull RTC_OBJC_TYPE(RTCPeerConnectionFactory) *)getPeerConnectionFactoryWithMedia:(BOOL)withMedia;

/// Release the PeerConnection and the factory.
- (void)disposeWithPeerConnection:(nullable RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection factory:(nullable RTC_OBJC_TYPE(RTCPeerConnectionFactory) *)factory;

- (BOOL)isExecutorQueue;

/// Called when a session-initiate IQ is received.
///
/// @param sessionId the P2P session id.
/// @param from the target identification string.
/// @param to the source/originator identification string.
/// @param sdp the sdp content (clear text | compressed | encrypted).
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max received frame size.
/// @param maxReceivedFrameRate the max received frame rate.
/// @return SUCCESS, NO_PERMISSION, ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onSessionInitiateWithSessionId:(nonnull NSUUID *)sessionId from:(nonnull NSString *)from to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate;

/// Called when a session-accept IQ is received.
///
/// @param sessionId the P2P session id.
/// @param sdp the sdp content (clear text | compressed | encrypted).
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max received frame size.
/// @param maxReceivedFrameRate the max received frame rate.
/// @return SUCCESS, NO_PERMISSION, ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onSessionAcceptWithSessionId:(nonnull NSUUID *)sessionId sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate;

/// Called when a session-update IQ is received.
///
/// @param sessionId the P2P session id.
/// @param updateType whether this is an offer or an answer.
/// @param sdp the sdp content (clear text | compressed | encrypted).
/// @return SUCCESS or ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onSessionUpdateWithSessionId:(nonnull NSUUID *)sessionId updateType:(RTCSdpType)updateType sdp:(nonnull TLSdp *)sdp;

/// Called when a transport-info IQ is received with a list of candidates.
///
/// @param sessionId the P2P session id.
/// @param sdp the list of candidates.
/// @return SUCCESS or ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onTransportInfoWithSessionId:(nonnull NSUUID *)sessionId sdp:(nonnull TLSdp *)sdp;

/// Called when a session-terminate IQ is received for the given P2P session.
///
/// @param sessionId the P2P session id.
/// @param reason the terminate reason.
- (void)onSessionTerminateWithSessionId:(nonnull NSUUID *)sessionId reason:(TLPeerConnectionServiceTerminateReason)reason;

- (void)onChangeConnectionStateWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId state:(TLPeerConnectionServiceConnectionState)state;

- (void)onTerminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (nullable RTC_OBJC_TYPE(RTCVideoTrack) *)createVideoTrackWithPeerConnectionFactory:(nonnull RTC_OBJC_TYPE(RTCPeerConnectionFactory) *)peerConnectionFactory;

- (void)releaseVideoTrack:(nonnull RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack;

- (void)setPeerConstraintsWithMaxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate;

- (void)sendDeviceRingingWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

/// Send the session-initiate to start a P2P connection with the peer.
///
/// @param peerConnection the peerConnection.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param notificationContent information for the push notification.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionInitiateWithPeerConnection:(nonnull TLPeerConnection *)peerConnection sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent *)notificationContent withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send the session-accept to accept an incoming P2P connection with the peer.
///
/// @param peerConnection the peerConnection.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max receive frame size that we accept.
/// @param maxReceivedFrameRate the max receive frame rate that we accept.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionAcceptWithPeerConnection:(nonnull TLPeerConnection *)peerConnection sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send the session-update to ask for a renegotiation with the peer.
///
/// @param peerConnection the peerConnection.
/// @param sdp the sdp to send.
/// @param type the update type to indicate whether this is an offer or answer.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionUpdateWithPeerConnection:(nonnull TLPeerConnection *)peerConnection type:(RTCSdpType)type sdp:(nonnull TLSdp *)sdp withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send the transport info for the P2P session to the peer.
///
/// @param peerConnection the peerConnection.
/// @param candidates the list of candidates.
/// @param block the completion handler executed when the server sends us its response.
- (void)transportInfoWithPeerConnection:(nonnull TLPeerConnection *)peerConnection candidates:(nonnull TLTransportCandidateList *)candidates withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

@end

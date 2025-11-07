/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPeerCallService.h"
#import "TLBaseServiceImpl.h"
#import "TLJobService.h"
#import "TLPeerConnectionService.h"

#import <WebRTC/RTCSessionDescription.h>

@class TLTransportCandidateList;
@class TLTransportCandidate;
@class TLSdp;
@class TLVersion;

//
// Protocol: TLPeerSignalingDelegate
//

@protocol TLPeerSignalingDelegate <NSObject>

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
/// @param sdp the sdp with candidates.
/// @return SUCCESS or ITEM_NOT_FOUND if the session id is not known.
- (TLBaseServiceErrorCode)onTransportInfoWithSessionId:(nonnull NSUUID *)sessionId sdp:(nonnull TLSdp *)sdp;

/// Called when a session-terminate IQ is received for the given P2P session.
///
/// @param sessionId the P2P session id.
/// @param reason the terminate reason.
- (void)onSessionTerminateWithSessionId:(nonnull NSUUID *)sessionId reason:(TLPeerConnectionServiceTerminateReason)reason;

/// Called when a device-ringing IQ is received for the given P2P session.
///
/// @param sessionId the P2P session id.
- (void)onDeviceRingingWithSessionId:(nonnull NSUUID *)sessionId;

@end

//
// Interface: TLPendingRequest ()
//

@interface TLPendingRequest : NSObject

@end

//
// Interface: TLCallRoomPendingRequest ()
//

@interface TLCallRoomPendingRequest : TLPendingRequest

@property (readonly, nonnull) NSUUID *callRoomId;

-(nonnull instancetype)initWithCallRoomId:(nonnull NSUUID *)callRoomId;

@end

//
// Interface: TLSessionPendingRequest ()
//

typedef void (^TLSessionConsumer) (TLBaseServiceErrorCode status, NSNumber * _Nullable requestId);

@interface TLSessionPendingRequest : TLPendingRequest

@property (readonly, nonnull) NSUUID *sessionId;
@property (readonly, nonnull) TLSessionConsumer consumer;

-(nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

@end

//
// Interface: TLPeerCallService ()
//

@interface TLPeerCallService ()

@property (readonly, nonnull) NSMutableDictionary<NSNumber *, TLPendingRequest *> *pendingRequests;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (nullable) id<TLPeerSignalingDelegate> peerSignalingDelegate;

+ (void)initialize;

/// Send the session-initiate to start a P2P connection with the peer.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max receive frame size that we accept.
/// @param maxReceivedFrameRate the max receive frame rate that we accept.
/// @param notificationContent information for the push notification.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionInitiateWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate notificationContent:(nonnull TLNotificationContent *)notificationContent withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send the session-accept to accept an incoming P2P connection with the peer.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the SDP to send.
/// @param offer the offer.
/// @param offerToReceive the offer to receive.
/// @param maxReceivedFrameSize the max receive frame size that we accept.
/// @param maxReceivedFrameRate the max receive frame rate that we accept.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionAcceptWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive maxReceivedFrameSize:(int)maxReceivedFrameSize maxReceivedFrameRate:(int)maxReceivedFrameRate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send the session-update to ask for a renegotiation with the peer.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the sdp to send.
/// @param type the update type to indicate whether this is an offer or answer.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionUpdateWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to type:(RTCSdpType)type sdp:(nonnull TLSdp *)sdp withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send the transport info for the P2P session to the peer.
///
/// @param requestId the request id
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param sdp the SDP with the list of candidates.
/// @param block the completion handler executed when the server sends us its response.
- (void)transportInfoWithRequestId:(int64_t)requestId sessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to sdp:(nonnull TLSdp *)sdp withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send a session-ping with the session id and peer identification string.  The server will check the
/// validity of our session and return SUCCESS or EXPIRED.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param block the completion handler executed when the server sends us its response.
- (void)sessionPingWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSNumber *_Nullable requestId))block;

/// Send the session-terminate to the peer to close the P2P connection.
///
/// Note: we don't need any onComplete listener because the server never returns an error.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
/// @param reason the reason for the termination.
- (void)sessionTerminateWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to reason:(TLPeerConnectionServiceTerminateReason)reason;

/// Send the device-ringing event to the peer.
///
/// @param sessionId the P2P session id.
/// @param to the peer identification string.
- (void)deviceRingingWithSessionId:(nonnull NSUUID *)sessionId to:(nonnull NSString *)to;

- (void)transferDone;

@end

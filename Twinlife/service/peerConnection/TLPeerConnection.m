/*
 *  Copyright (c) 2013-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Zhuoyu Ma (Zhuoyu.Ma@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#include <stdatomic.h>

#import <AVFoundation/AVFoundation.h>

#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCConfiguration.h>
#import <WebRTC/RTCMediaStream.h>
#import <WebRTC/RTCMediaConstraints.h>
#import <WebRTC/RTCAudioTrack.h>
#import <WebRTC/RTCVideoTrack.h>
#import <WebRTC/RTCIceCandidate.h>
#import <WebRTC/RTCDataChannel.h>
#import <WebRTC/RTCDataChannelConfiguration.h>
#import <WebRTC/RTCSessionDescription.h>
#import <WebRTC/RTCAudioSessionConfiguration.h>
#import <WebRTC/RTCStatisticsReport.h>
#import <WebRTC/RTCRtpReceiver.h>
#import <WebRTC/RTCRtpTransceiver.h>
#import <WebRTC/RTCHostname.h>
#import <WebRTC/RTCAudioSession.h>

#import "TLPeerConnection.h"
#import "TLConversationService.h"
#import "TLPeerConnectionServiceImpl.h"
#import "TLManagementServiceImpl.h"
#import "TLCryptoService.h"
#import "TLBaseServiceImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLSdp.h"
#import "TLBinaryPacketIQ.h"

#if 0
#define DEBUG_ICE 1
static const int ddLogLevel = DDLogLevelInfo;
#else
#define DEBUG_ICE 0
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define NS_TO_MSEC(T) ((T) / 1000000LL)
#define NS_TO_SEC(T)  ((T) / 1000000000LL)

typedef enum {
    TLPeerConnectionServiceCameraConstraintsAnyCamera,
    TLPeerConnectionServiceCameraConstraintsFacingBackCamera,
    TLPeerConnectionServiceCameraConstraintsFacingFrontCamera,
    TLPeerConnectionServiceCameraConstraintsNoCamera
} TLPeerConnectionServiceCameraConstraints;

static const int64_t RESTART_ICE_DELAY = 2500; // ms delay to wait before restarting ICE after a disconnect.
static const int64_t RESTART_DATA_ICE_DELAY = 5000; // ms delay to wait before restarting ICE after a disconnect.

static const int STATS_REPORT_VERSION = 2;
static const int CONNECT_REPORT_VERSION = 2;
static const int IQ_REPORT_VERSION = 5;
static const int AUDIO_REPORT_VERSION = 2;
static const int VIDEO_REPORT_VERSION = 2;

// Defines the content of the 'set_report' and order in which these counters are reported.
static const TLPeerConnectionServiceStatType SET_STAT_LIST[] = {
    TLPeerConnectionServiceStatTypeIqSetPushObject,
    TLPeerConnectionServiceStatTypeIqSetPushTransient,
    TLPeerConnectionServiceStatTypeIqSetPushFile,
    TLPeerConnectionServiceStatTypeIqSetPushFileChunk,
    TLPeerConnectionServiceStatTypeIqSetUpdateObject,
    TLPeerConnectionServiceStatTypeIqSetResetConversation,
    TLPeerConnectionServiceStatTypeIqSetInviteGroup,
    TLPeerConnectionServiceStatTypeIqSetJoinGroup,
    TLPeerConnectionServiceStatTypeIqSetLeaveGroup,
    TLPeerConnectionServiceStatTypeIqSetUpdateGroupMember,
    TLPeerConnectionServiceStatTypeIqSetWithdrawInviteGroup,
    TLPeerConnectionServiceStatTypeIqSetPushGeolocation,
    TLPeerConnectionServiceStatTypeIqSetPushTwincode,
    TLPeerConnectionServiceStatTypeIqSetSynchronize,
    TLPeerConnectionServiceStatTypeIqSetSignatureInfo,
    TLPeerConnectionServiceStatTypeIqError
};
static const int SET_STAT_LIST_COUNT = sizeof(SET_STAT_LIST) / sizeof(SET_STAT_LIST[0]);

// Defines the content of the 'result_report' and order in which these counters are reported.
static const TLPeerConnectionServiceStatType RESULT_STAT_LIST[] = {
    TLPeerConnectionServiceStatTypeIqResultPushObject,
    TLPeerConnectionServiceStatTypeIqResultPushTransient,
    TLPeerConnectionServiceStatTypeIqResultPushFile,
    TLPeerConnectionServiceStatTypeIqResultPushFileChunk,
    TLPeerConnectionServiceStatTypeIqResultUpdateObject,
    TLPeerConnectionServiceStatTypeIqResultResetConversation,
    TLPeerConnectionServiceStatTypeIqResultInviteGroup,
    TLPeerConnectionServiceStatTypeIqResultJoinGroup,
    TLPeerConnectionServiceStatTypeIqResultLeaveGroup,
    TLPeerConnectionServiceStatTypeIqResultUpdateGroupMember,
    TLPeerConnectionServiceStatTypeIqResultWithdrawInviteGroup,
    TLPeerConnectionServiceStatTypeIqResultPushGeolocation,
    TLPeerConnectionServiceStatTypeIqResultPushTwincode,
    TLPeerConnectionServiceStatTypeIqResultSynchronize,
    TLPeerConnectionServiceStatTypeIqResultSignatureInfo
};
static const int RESULT_STAT_LIST_COUNT = sizeof(RESULT_STAT_LIST) / sizeof(RESULT_STAT_LIST[0]);

// Defines the content of the 'recv_report' and order in which these counters are reported.
static const TLPeerConnectionServiceStatType RECEIVE_STAT_LIST[] = {
    TLPeerConnectionServiceStatTypeIqReceiveCount,
    TLPeerConnectionServiceStatTypeIqReceiveSetCount,
    TLPeerConnectionServiceStatTypeIqReceiveResultCount,
    TLPeerConnectionServiceStatTypeIqReceiveErrorCount
};
static const int RECEIVE_STAT_LIST_COUNT = sizeof(RECEIVE_STAT_LIST) / sizeof(RECEIVE_STAT_LIST[0]);

// Defines the content of the 'sdp_report' and order in which these counters are reported.
static const TLPeerConnectionServiceStatType SDP_STAT_LIST[] = {
    TLPeerConnectionServiceStatTypeSdpReceiveClearCount,
    TLPeerConnectionServiceStatTypeSdpSendClearCount,
    TLPeerConnectionServiceStatTypeSdpReceiveEncryptedCount,
    TLPeerConnectionServiceStatTypeSdpSendEncryptedCount
};
static const int SDP_STAT_LIST_COUNT = sizeof(SDP_STAT_LIST) / sizeof(SDP_STAT_LIST[0]);

// Defines the content of the 'error_report' and order in which these counters are reported.
static const TLPeerConnectionServiceStatType ERROR_STAT_LIST[] = {
    TLPeerConnectionServiceStatTypeSerializeErrorCount,
    TLPeerConnectionServiceStatTypeSendErrorCount,
    TLPeerConnectionServiceStatTypeAudioTrackErrorCount,
    TLPeerConnectionServiceStatTypeVideoTrackErrorCount,
    TLPeerConnectionServiceStatTypeFirstSendError,
    TLPeerConnectionServiceStatTypeFirstSendErrorTime
};
static const int ERROR_STAT_LIST_COUNT = sizeof(ERROR_STAT_LIST) / sizeof(ERROR_STAT_LIST[0]);

/*
 * <pre>
 * Date: 2024/12/16
 *  changes: added error report and padding flag
 *  iqReport: version 5
 *  iq_report = version:set:set_report:result:result_report:recv:recv_report:sdp:sdp_report:padding_flag:error_report
 *  sdp_report = sdp-receive-clear:sdp-send-clear:sdp-receive-encrypted:sdp-send-encrypted
 *  padding_flag = ':P' if leading padding
 *  error_report = err:serialize-error-count:send-error-count:audio-track-error:video-track-error
 *
 * Date: 2024/10/18
 *  changes: added IQ stats synchronize-iq, signature-info-iq, sdp_report
 *  iqReport: version 4
 *  iq_report = version:set:set_report:result:result_report:recv:recv_report:sdp:sdp_report
 *  sdp_report = sdp-receive-clear:sdp-send-clear:sdp-receive-encrypted:sdp-send-encrypted
 *
 * Date: 2019/11/13
 * version: 2
 * changes: use WebRTC standard stats API and use Android version 2 statsReport
 *
 * stats_report = version::duration:durationS:[transport_report|outbound_rtp_report|inbound_rtp_report|datachannel_report]*
 *
 * transport_report = :transport:bytesSent:bytesReceived:localNetworkType:localProtocol:localCandidateType:remoteProtocol:remoteCandidateType:
 * outbound_rtp_report = audio_outbound_rtp_report|video_outbound_rtp_report
 * audio_outbound_rtp_report = :outbound-rtp:mimeType:clockRate:bytesSent:packetsSent:
 * video_outbound_rtp_report = :outbound-rtp:mimeType:clockRate:bytesSent:packetsSent:framesEncoded:
 * inbound_rtp_report = audio_inbound_rtp_report|video_inbound_rtp_report
 * audio_inbound_rtp_report = :inbound-rtp:mimeType:clockRate:bytesReceived:packetsReceived:packetsLost:
 * video_inbound_rtp_report = :inbound-rtp:mimeType:clockRate:bytesReceived:packetsReceived:packetsLost:framesDecoded:
 *
 * Date: 2019/05/23
 *
 * changes: added IQ stats for push-twincode
 *
 * iq_report = version:set:set_report:result:result_report:recv:recv_report
 * set_report = push-count:transient-count:file-count:chunk-count:update-count:reset-count:invite-count:join-count:leave-count:update-group-count:push-geolocation-count:push-twincode:error-count
 * result_report = push-count:transient-count:file-count:chunk-count:update-count:reset-count:invite-count:join-count:leave-count:update-group-count:push-geolocation-count:push-twincode
 * recv_report = total-count:set-count:result-count:error-count
 *
 * Date: 2019/02/21
 *
 * version: 2
 * changes: added IQ stats for push-geolocation
 *
 * iq_report = version:set:set_report:result:result_report:recv:recv_report
 * set_report = push-count:transient-count:file-count:chunk-count:update-count:reset-count:invite-count:join-count:leave-count:update-group-count:push-geolocation-count:error-count
 * result_report = push-count:transient-count:file-count:chunk-count:update-count:reset-count:invite-count:join-count:leave-count:update-group-count:push-geolocation-count
 * recv_report = total-count:set-count:result-count:error-count
 *
 * Date: 2018/12/13
 *
 * version: 1
 *
 * iq_report = version:set:set_report:result:result_report:recv:recv_report
 * set_report = push-count:transient-count:file-count:chunk-count:update-count:reset-count:invite-count:join-count:leave-count:update-group-count:error-count
 * result_report = push-count:transient-count:file-count:chunk-count:update-count:reset-count:invite-count:join-count:leave-count:update-group-count
 * recv_report = total-count:set-count:result-count:error-count
 *
 * Date: 2018/05/23
 *
 * version: 1
 *
 * connect_report = version::connect:connectmS::accept:acceptmS::iceRemote:value::iceLocal:value:
 * acceptmS: time to receive the session-accept or time to send the session-accept (in milliseconds)
 * connectmS: time to establish the P2P connection when the session-accept is sent/received (in milliseconds)
 * iceRemove: the number of ICE that were received for the P2P connection
 * iceLocal: the number of ICE that were sent to the peer
 *
 * Version 1
 *
 * stats_report = version::duration::conn_report::audio_send_report::audio_recv_report:
 *   :video_send_report::video_recv_report::datachannel_report
 *  conn_report = bytesSent:bytesReceived:googLocalCandidateType:googRemoteCandidateType
 *  audio_send_report = audio_send:bytesSent:googCodecName
 *  audio_recv_report = audio_recv:bytesReceived:googCodecName
 *  video_send_report = video_send:bytesSent:googCodecName:googFrameWidthInput:googFrameHeightInput:
 *   googFrameRateInput:googFrameWidthSent:googFrameHeightSent:googFrameRateSent:googAvgEncodeMs:
 *   googEncodeUsagePercent
 *  video_recv_report = video_recv:bytesReceived:googCodecName:googFrameWidthReceived:googFrameHeightReceived:
 *   googFrameRateReceived:googFrameRateDecoded:googFrameRateOutput:googMaxDecodeMs
 *  datachannel_report = datachannel:count
 *
 * </pre>
 */

typedef enum {
    TLPeerConnectionServiceAudioSend,
    TLPeerConnectionServiceAudioRecv,
    TLPeerConnectionServiceVideoSend,
    TLPeerConnectionServiceVideoRecv
} TLPeerConnectionServiceStatsReportIds;

#define DATA_CHANNEL_LABEL @"twinlife:data:conversation"

static NSArray<RTC_OBJC_TYPE(RTCHostname) *> *sHostnames = nil;

static int MAX_FRAME_SIZE = 128 * 1024;

/*
 * Frame format : derived from WebSocket frame format
 *
 * <pre>
 *    0                   1                   2                   3
 *    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *   +-+-+-+-+-------+-----------------------------------------------+
 *   |F|R|R|R| opcode|                                               |
 *   |I|S|S|S|  (4)  |                                               |
 *   |N|V|V|V|       |                 Payload Data                  |
 *   | |1|2|3|       |                                               |
 *   +-+-+-+-+-------+----------------- - - - - - -- - - - - - - - - +
 *   :                     Payload Data continued ...                :
 *   + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 *   |                     Payload Data continued ...                |
 *   +---------------------------------------------------------------+
 *
 * </pre>
 */

static uint8_t OP_CONTINUATION = 0x00;
// static uint8_t OP_TEXT = 0x01;
static uint8_t OP_BINARY = 0x02;

// static uint8_t OP_CONTROL = 0x08;
// static uint8_t OP_CLOSE = 0x08;
// static uint8_t OP_PING = 0x09;
// static uint8_t OP_PONG = 0x0A;
static uint8_t FLAG_FIN = 0x8;

//
// Event Ids
//

#define EVENT_ID_PEER_CONNECTION @"twinlife::peerConnectionService::peerConnection"
#define STATS_REPORT @"statsReport"
#define PEER_CONNECTION_ID @"p2pSessionId"
#define ORIGIN @"origin"
#define CONNECT_REPORT @"connectReport"
#define IQ_REPORT @"iqReport"
#define AUDIO_REPORT @"audioReport"
#define VIDEO_REPORT @"videoReport"

#define OUTBOUND @"outbound"
#define INBOUND @"inbound"

//
// Interface: TLImageControlPoint ()
//

@implementation TLPeerConnectionAssertPoint

TL_CREATE_ASSERT_POINT(CREATE_PEER_CONNECTION, 300)
TL_CREATE_ASSERT_POINT(CREATE_DATA_CHANNEL, 301)
TL_CREATE_ASSERT_POINT(CREATE_AUDIO_TRACK, 302)
TL_CREATE_ASSERT_POINT(CREATE_VIDEO_TRACK, 303)
TL_CREATE_ASSERT_POINT(OFFER_FAILURE, 304)
TL_CREATE_ASSERT_POINT(SET_LOCAL_FAILURE, 305)
TL_CREATE_ASSERT_POINT(SET_REMOTE_FAILURE, 306)
TL_CREATE_ASSERT_POINT(ENCRYPT_ERROR, 307)
TL_CREATE_ASSERT_POINT(DECRYPT_ERROR_1, 308)
TL_CREATE_ASSERT_POINT(DECRYPT_ERROR_2, 309)

@end

//
// Interface: TLPeerConnection ()
//

@class TLPeerConnectionRTCPeerConnectionDelegate;
@class TLPeerConnectionRTCSessionDescriptionDelegate;
@class TLPeerConnectionRTCDataChannelDelegate;

@interface TLPeerConnection ()

@property (readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (readonly, nonnull) dispatch_queue_t executorQueue;
@property (readonly, nonnull) TLTwinlife *twinlife;
@property (readonly, nonnull) TLPeerCallService *peerCallService;
@property (readonly, nonnull) TLTransportCandidateList *pendingCandidates;

@property (readonly, nonnull) NSString *defaultStreamLabel;
@property (readonly) BOOL initiator;
@property (readonly, nonnull) TLBaseServiceImplConfiguration *configuration;
@property (readonly, nullable) TLNotificationContent *notificationContent;
@property RTC_OBJC_TYPE(RTCPeerConnection) *peerConnection;
@property RTC_OBJC_TYPE(RTCPeerConnectionFactory) *peerConnectionFactory;
@property atomic_bool initialized;
@property atomic_int renegotiationNeeded;
@property atomic_int renegotationPending;
@property atomic_bool terminated;
@property NSMutableArray<TLTransportCandidate *> *iceRemoteCandidates;
@property RTC_OBJC_TYPE(RTCSessionDescription) *remoteSessionDescription;
@property BOOL audioSourceOn;
@property BOOL videoSourceOn;
@property BOOL dataSourceOn;
@property BOOL ignoreOffer;
@property BOOL isSettingRemoteAnswerPending;
@property BOOL withMedia;
@property RTCIceConnectionState state;
@property RTC_OBJC_TYPE(RTCRtpSender) *audioStreamTrackSender;
@property RTC_OBJC_TYPE(RTCAudioTrack) *audioTrack;
@property RTC_OBJC_TYPE(RTCVideoTrack) *videoTrack;
@property RTC_OBJC_TYPE(RTCDataChannel) *inDataChannel;
@property NSString *inDataChannelExtension;
@property RTC_OBJC_TYPE(RTCDataChannel) *outDataChannel;
@property NSMutableArray<NSData *> *outDataFrames;
@property RTCDataChannelState dataChannelState;
@property RTC_OBJC_TYPE(RTCStatisticsReport) *statsReport;
@property RTC_OBJC_TYPE(RTCStatistics) *selectedCandidateStats;
@property int64_t startTimestamp;
@property int64_t stopTimestamp;
@property int64_t acceptedTimestamp;
@property int64_t connectedTimestamp;
@property int64_t restartIceTimestamp;
@property atomic_int remoteIceCandidatesCount;
@property atomic_int localIceCandidatesCount;
@property int *statCounters;
@property id<TLPeerConnectionDataChannelDelegate> dataChannelDelegate;
@property BOOL leadingPadding;
@property int peerMajorVersion;
@property int peerMinorVersion;
@property (nullable) dispatch_source_t flushCandidatesTimer;
@property atomic_bool flushCandidatesActive;
@property (nullable) NSMutableArray<TLSdp *> *pendingSdp;

@property (readonly, nonnull) TLPeerConnectionRTCPeerConnectionDelegate *peerConnectionRTCPeerConnectionDelegate;
@property (readonly, nonnull) TLPeerConnectionRTCSessionDescriptionDelegate *peerConnectionRTCSessionDescriptionDelegate;
@property (readonly, nonnull) TLPeerConnectionRTCDataChannelDelegate *peerConnectionRTCDataChannelDelegate;

- (BOOL)hasRemoveTrackOnMute;

- (void)onSignalingChangeInternalWithSignalingState:(RTCSignalingState)signalingState;

- (void)onIceConnectionChangeInternalWithIceConnectionState:(RTCIceConnectionState)iceConnectionState;

- (void)onIceCandidateInternalWithIceCandidate:(RTC_OBJC_TYPE(RTCIceCandidate) *)candidate;

- (void)onIceCandidateRemovedInternalWithIceCandidate:(NSArray<RTC_OBJC_TYPE(RTCIceCandidate) *> *)candidates;

- (void)onAddReceiverWithReceiver:(RTC_OBJC_TYPE(RTCRtpReceiver) *)rtpReceiver streams:(NSArray<RTC_OBJC_TYPE(RTCMediaStream) *> *)mediaStreams;

- (void)onRemoveRemoteTrackWithTrackId:(nonnull NSString *)trackId;

- (void)onRenegotiationNeededInternal;

- (void)onDataChannelInternalWithDataChannel:(RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel;

- (void)onDataChannelStateChangeInternalWithDataChannel:(RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel;

- (void)onDataChannelMessageWithDataChannel:(RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel buffer:(RTC_OBJC_TYPE(RTCDataBuffer) *)buffer;

- (void)onSetLocalDescriptionWithSessionDescription:(nullable RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription error:(nullable NSError *)error;

- (void)onSendServerWithErrorCode:(TLBaseServiceErrorCode)errorCode requestId:(NSNumber *)requestId;

- (void)terminatePeerConnectionInternalWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason notifyPeer:(BOOL)notifyPeer;

@end

//
// Interface: TLPeerConnectionRTCPeerConnectionDelegate
//

@interface TLPeerConnectionRTCPeerConnectionDelegate : NSObject <RTC_OBJC_TYPE(RTCPeerConnectionDelegate)>

@property (weak) TLPeerConnection *peerConnection;

- (nonnull instancetype)initWithPeerConnection:(nonnull TLPeerConnection *)peerConnection;

@end

//
// Implementation: TLPeerConnectionRTCPeerConnectionDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerConnectionRTCPeerConnectionDelegate"

@implementation TLPeerConnectionRTCPeerConnectionDelegate

- (nonnull instancetype)initWithPeerConnection:(nonnull TLPeerConnection *)peerConnection {
    DDLogVerbose(@"%@ initWithPeerConnection: %@", LOG_TAG, peerConnection);
    
    self = [super init];
    
    _peerConnection = peerConnection;
    return self;
}

- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection didChangeSignalingState:(RTCSignalingState)signalingState {
    DDLogVerbose(@"%@ peerConnection: %@ didChangeSignalingState: %ld", LOG_TAG, peerConnection, (long)signalingState);
    
    [self.peerConnection onSignalingChangeInternalWithSignalingState:signalingState];
}

- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)iceConnectionState {
    DDLogVerbose(@"%@ peerConnection: %@ didChangeIceConnectionState: %ld", LOG_TAG, peerConnection, (long)iceConnectionState);
    
    [self.peerConnection onIceConnectionChangeInternalWithIceConnectionState:iceConnectionState];
}

- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    DDLogVerbose(@"%@ peerConnection: %@ didChangeIceGatheringState: %ld", LOG_TAG, peerConnection, (long)newState);
}

- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection didGenerateIceCandidate:(RTC_OBJC_TYPE(RTCIceCandidate *))candidate {
    DDLogVerbose(@"%@ peerConnection: %@ didGenerateIceCandidate: %@", LOG_TAG, peerConnection, candidate);
    
    [self.peerConnection onIceCandidateInternalWithIceCandidate:candidate];
}

- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection didRemoveIceCandidates:(NSArray<RTC_OBJC_TYPE(RTCIceCandidate) *> *)candidates {
    DDLogVerbose(@"%@ peerConnection: %@ didRemoveIceCandidates: %@", LOG_TAG, peerConnection, candidates);

    [self.peerConnection onIceCandidateRemovedInternalWithIceCandidate:candidates];
}

/// Called when a receiver and its track are created.
- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection didAddReceiver:(RTC_OBJC_TYPE(RTCRtpReceiver) *)rtpReceiver streams:(NSArray<RTC_OBJC_TYPE(RTCMediaStream) *> *)mediaStreams {
    DDLogVerbose(@"%@ peerConnection: %@ didAddReceiver: %@", LOG_TAG, peerConnection, rtpReceiver);

    [self.peerConnection onAddReceiverWithReceiver:rtpReceiver streams:mediaStreams];
}

/// Called when the receiver and its track are removed.
- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection
     didRemoveReceiver:(RTC_OBJC_TYPE(RTCRtpReceiver) *)rtpReceiver {
    DDLogVerbose(@"%@ peerConnection: %@ didRemoveReceiver: %@", LOG_TAG, peerConnection, rtpReceiver);

    [self.peerConnection onRemoveRemoteTrackWithTrackId:rtpReceiver.receiverId];
}

- (void)peerConnectionShouldNegotiate:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection {
    DDLogVerbose(@"%@ peerConnectionShouldNegotiate: %@", LOG_TAG, peerConnection);
    
    [self.peerConnection onRenegotiationNeededInternal];
}

- (void)peerConnection:(RTC_OBJC_TYPE(RTCPeerConnection) *)peerConnection didOpenDataChannel:(RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel {
    DDLogVerbose(@"%@ peerConnection: %@ didOpenDataChannel: %@", LOG_TAG, peerConnection, dataChannel);
    
    [self.peerConnection onDataChannelInternalWithDataChannel:dataChannel];
}

@end

//
// Interface: TLPeerConnectionRTCDataChannelDelegate
//

@interface TLPeerConnectionRTCDataChannelDelegate : NSObject <RTC_OBJC_TYPE(RTCDataChannelDelegate)>

@property (weak) TLPeerConnection *peerConnection;

- (nonnull instancetype)initWithPeerConnection:(nonnull TLPeerConnection *)peerConnection;

@end

//
// Implementation: TLPeerConnectionRTCDataChannelDelegate
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerConnectionRTCDataChannelDelegate"

@implementation TLPeerConnectionRTCDataChannelDelegate

- (nonnull instancetype)initWithPeerConnection:(nonnull TLPeerConnection *)peerConnection {
    DDLogVerbose(@"%@ initWithPeerConnection: %@", LOG_TAG, peerConnection);
    
    self = [super init];
    
    _peerConnection = peerConnection;
    return self;
}

- (void)dataChannelDidChangeState:(RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel {
    DDLogVerbose(@"%@ dataChannelDidChangeState: %@", LOG_TAG, dataChannel);
    
    [self.peerConnection onDataChannelStateChangeInternalWithDataChannel:dataChannel];
}

- (void)dataChannel:(RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel didReceiveMessageWithBuffer:(RTC_OBJC_TYPE(RTCDataBuffer) *)buffer {
    DDLogVerbose(@"%@ dataChannel: %@ didReceiveMessageWithBuffer: %@", LOG_TAG, dataChannel, buffer);
    
    [self.peerConnection onDataChannelMessageWithDataChannel:dataChannel buffer:buffer];
}

- (void)dataChannel:(RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel didChangeBufferedAmount:(uint64_t)amount {
    DDLogVerbose(@"%@ dataChannel: %@ didChangeBufferedAmount: %lld", LOG_TAG, dataChannel, amount);
}

@end

//
// Implementation: TLPeerConnection
//

#undef LOG_TAG
#define LOG_TAG @"TLPeerConnection"

@implementation TLPeerConnection

- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService sessionId:(nonnull NSUUID *)sessionId sessionKeyPair:(nullable id<TLSessionKeyPair>)sessionKeyPair peerId:(nonnull NSString *)peerId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent*)notificationContent configuration:(nonnull TLBaseServiceImplConfiguration *)configuration delegate:(nonnull id<TLPeerConnectionDelegate>)delegate {
    DDLogVerbose(@"%@ initWithPeerConnectionService: %@ peerId: %@ offer: %@ offerToReceive: %@ notificationContent: %@ configuration: %@", LOG_TAG, peerConnectionService, peerId, offer, offerToReceive, notificationContent, configuration);
    
    self = [super init];
    
    _uuid = sessionId;
    _keyPair = sessionKeyPair;
    _peerConnectionService = peerConnectionService;
    _executorQueue = _peerConnectionService.executorQueue;
    _twinlife = [_peerConnectionService twinlife];
    _peerCallService = [_twinlife getPeerCallService];
    _peerId = peerId;
    _defaultStreamLabel = [[NSUUID UUID] UUIDString];
    _notificationContent = notificationContent;
    _initiator = YES;
    _offer = offer;
    _offerToReceive = offerToReceive;
    _configuration = configuration;
    _delegate = delegate;
    _initialized = NO;
    _terminated = NO;

    // Prevent re-negotiation due to the creation of the data-channel or setup of WebRTC connection.
    _renegotiationNeeded = 1;
    _iceRemoteCandidates = nil; // on purpose
    _audioSourceOn = NO;
    _videoSourceOn = NO;
    _dataSourceOn = NO;
    _outDataFrames = [[NSMutableArray alloc] init];
    _dataChannelState = RTCDataChannelStateClosed;
    _statsReport = nil;
    _startTimestamp = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    _remoteIceCandidatesCount = 0;
    _localIceCandidatesCount = 0;
    _ignoreOffer = NO;
    _isSettingRemoteAnswerPending = NO;
    _state = RTCIceConnectionStateDisconnected;
    _peerMajorVersion = 1;
    _peerMinorVersion = 0;
    _statCounters = (int*) calloc(TLPeerConnectionServiceStatTypeIqLast, sizeof(int));
    _pendingCandidates = [[TLTransportCandidateList alloc] init];

    // Setup timer to flush the ICE candidates.
    _flushCandidatesActive = NO;
    _flushCandidatesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _executorQueue);
    
    __weak TLPeerConnection *weakSelf = self;
    dispatch_source_set_event_handler(_flushCandidatesTimer, ^{
        __strong TLPeerConnection *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf flushCandidates];
        }
    });

    _peerConnectionRTCPeerConnectionDelegate = [[TLPeerConnectionRTCPeerConnectionDelegate alloc] initWithPeerConnection:self];
    _peerConnectionRTCDataChannelDelegate = [[TLPeerConnectionRTCDataChannelDelegate alloc] initWithPeerConnection:self];

    return self;
}

- (nonnull instancetype)initWithPeerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService sessionId:(nonnull NSUUID *)sessionId peerId:(nonnull NSString *)peerId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive configuration:(nonnull TLBaseServiceImplConfiguration *)configuration sdp:(nonnull TLSdp *)sdp {
    DDLogVerbose(@"%@ initWithPeerConnectionService: %@ sessionId: %@ peerId: %@ offer: %@ offerToReceive: %@ configuration: %@ sdp: %@", LOG_TAG, peerConnectionService, sessionId, peerId, offer, offerToReceive, configuration, sdp);
    
    self = [super init];
    
    _uuid = sessionId;
    _peerConnectionService = peerConnectionService;
    _executorQueue = _peerConnectionService.executorQueue;
    _twinlife = [_peerConnectionService twinlife];
    _peerCallService = [_twinlife getPeerCallService];
    _peerId = peerId;
    _defaultStreamLabel = [[NSUUID UUID] UUIDString];
    _initiator = NO;
    _peerOfferToReceive = offerToReceive;
    _notificationContent = nil;
    _configuration = configuration;
    if ([sdp isEncrypted]) {
        _pendingSdp = [[NSMutableArray alloc] initWithObjects:sdp, nil];
    } else {
        _remoteSessionDescription = [[RTC_OBJC_TYPE(RTCSessionDescription) alloc] initWithType:RTCSdpTypeOffer sdp:[sdp sdp]];
    }
    _initialized = NO;
    _terminated = NO;

    // Prevent re-negotiation due to the creation of the data-channel or setup of WebRTC connection.
    _renegotiationNeeded = 1;
    _iceRemoteCandidates = [[NSMutableArray alloc] init];
    _audioSourceOn = NO;
    _videoSourceOn = NO;
    _dataSourceOn = NO;
    _outDataFrames = [[NSMutableArray alloc] init];
    _dataChannelState = RTCDataChannelStateClosed;
    _statsReport = nil;
    _startTimestamp = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    _remoteIceCandidatesCount = 0;
    _localIceCandidatesCount = 0;
    _ignoreOffer = NO;
    _isSettingRemoteAnswerPending = NO;
    _state = RTCIceConnectionStateDisconnected;
    _peerMajorVersion = 1;
    _peerMinorVersion = 0;
    _statCounters = (int*) calloc(TLPeerConnectionServiceStatTypeIqLast, sizeof(int));
    _pendingCandidates = [[TLTransportCandidateList alloc] init];

    // Setup timer to flush the ICE candidates.
    _flushCandidatesActive = NO;
    _flushCandidatesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _executorQueue);
    __weak TLPeerConnection *weakSelf = self;
    dispatch_source_set_event_handler(_flushCandidatesTimer, ^{
        __strong TLPeerConnection *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf flushCandidates];
        }
    });

    _peerConnectionRTCPeerConnectionDelegate = [[TLPeerConnectionRTCPeerConnectionDelegate alloc] initWithPeerConnection:self];
    _peerConnectionRTCDataChannelDelegate = [[TLPeerConnectionRTCDataChannelDelegate alloc] initWithPeerConnection:self];
    self.peerOffer = offer;
    return self;
}

- (void)setPeerOffer:(nullable TLOffer *)offer {
    DDLogVerbose(@"%@ setPeerOffer: %@", LOG_TAG, offer);

    _peerOffer = offer;
    TLVersion *peerVersion = offer.version;
    if (peerVersion) {
        _peerMajorVersion = peerVersion.major;
        _peerMinorVersion = peerVersion.minor;
    } else {
        _peerMajorVersion = 1;
        _peerMinorVersion = 0;
    }
}

/**
 * Returns True if the peer supports removing track when we mute the audio/video.
 *
 * This is supported starting with peer connection service 1.3.0.
 *
 * @return true if removing track on mute is supported.
 */
- (BOOL)hasRemoveTrackOnMute {

    return self.peerMajorVersion > 1 || (self.peerMajorVersion == 1 && self.peerMinorVersion > 2);
}

- (void)createIncomingPeerConnectionWithConfiguration:(nonnull RTC_OBJC_TYPE(RTCConfiguration) *)configuration sessionDescription:(nullable RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createIncomingPeerConnectionWithConfiguration: %@ sessionDescription: %@", LOG_TAG, configuration, sessionDescription);
    DDLogInfo(@"%@ create-incoming for %@", LOG_TAG, self.uuid);

    self.delegate = delegate;
    dispatch_async(self.executorQueue, ^{
        if (sessionDescription) {
            self.remoteSessionDescription = sessionDescription;
        }
        if ([self createPeerConnectionInternalWithConfiguration:configuration dataChannelDelegate:dataChannelDelegate]) {
            block(TLBaseServiceErrorCodeSuccess, self.uuid);
        } else {
            block(TLBaseServiceErrorCodeWebrtcError, nil);
        }
    });
}

- (void)createOutgoingPeerConnectionWithConfiguration:(nonnull RTC_OBJC_TYPE(RTCConfiguration) *)configuration dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block {
    DDLogVerbose(@"%@ createOutgoingPeerConnectionWithConfiguration: %@", LOG_TAG, configuration);
    DDLogInfo(@"%@ create-outgoing for %@", LOG_TAG, self.uuid);

    dispatch_async(self.executorQueue, ^{
        if ([self createPeerConnectionInternalWithConfiguration:configuration dataChannelDelegate:dataChannelDelegate]) {
            block(TLBaseServiceErrorCodeSuccess, self.uuid);
        } else {
            block(TLBaseServiceErrorCodeWebrtcError, nil);
        }
    });
}

- (void)initSourcesWithAudioOn:(BOOL)audioOn videoOn:(BOOL)videoOn {
    DDLogVerbose(@"%@ initSourcesWithAudioOn %@ videoOn: %@", LOG_TAG, audioOn ? @"YES" : @"NO", videoOn ? @"YES" : @"NO");
    DDLogInfo(@"%@ init-sources for %@ audio: %@ video: %@", LOG_TAG, self.uuid, audioOn ? @"YES" : @"NO", videoOn ? @"YES" : @"NO");

    dispatch_async(self.executorQueue, ^{
        if (![self initSourcesInternalWithAudioOn:audioOn videoOn:videoOn]) {
            [self terminatePeerConnectionInternalWithTerminateReason:TLPeerConnectionServiceTerminateReasonGeneralError notifyPeer:YES];
        }
    });
}

- (TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatus {
    DDLogVerbose(@"%@ sdpEncryptionStatus", LOG_TAG);

    // For an incomine P2P, we could have a null keypair but encrypted SDPs
    // which are queued until we know the decryption keys.
    @synchronized (self) {
        if (self.keyPair) {
            return [self.keyPair needRenew] ? TLPeerConnectionServiceSdpEncryptionStatusEncryptedNeedRenew : TLPeerConnectionServiceSdpEncryptionStatusEncrypted;
        } else {
            return self.pendingSdp ? TLPeerConnectionServiceSdpEncryptionStatusEncrypted : TLPeerConnectionServiceSdpEncryptionStatusNone;
        }
    }
}

- (BOOL)queueWithSdp:(nonnull TLSdp *)sdp {
    DDLogVerbose(@"%@ queueWithSdp: %@", LOG_TAG, sdp);

    @synchronized (self) {
        if (self.keyPair) {
            return NO;
        }
        if (!self.pendingSdp) {
            self.pendingSdp = [[NSMutableArray alloc] init];
        }
        [self.pendingSdp addObject:sdp];
        return YES;
    }
}

- (nullable NSArray<TLSdp *> *)configureSessionKey:(nonnull id<TLSessionKeyPair>)sessionKeyPair {
    DDLogVerbose(@"%@ configureSessionKey: %@", LOG_TAG, sessionKeyPair);

    NSArray<TLSdp *> *result;
    @synchronized (self) {
        result = self.pendingSdp;
        self.pendingSdp = nil;
        self.keyPair = sessionKeyPair;
    }
    return result;
}

- (void)setAudioDirection:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setAudioDirection: %ld", LOG_TAG, (long)direction);
    
    dispatch_async(self.executorQueue, ^{
        [self setAudioDirectionInternalWithDirection:direction];
    });
}

- (void)setVideoDirection:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setVideoDirection: %ld", LOG_TAG, (long)direction);
    
    dispatch_async(self.executorQueue, ^{
        [self setVideoDirectionInternalWithDirection:direction];
    });
}

- (void)acceptRemoteDescription:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription {
    DDLogVerbose(@"%@ acceptRemoteDescription: %@", LOG_TAG, sessionDescription);
    DDLogInfo(@"%@ peer accept-remote for %@", LOG_TAG, self.uuid);

    dispatch_async(self.executorQueue, ^{
        [self acceptRemoteDescriptionInternalWithSessionDescription:sessionDescription];
    });
}

- (void)updateRemoteDescription:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription {
    DDLogVerbose(@"%@ updateRemoteDescription: %@", LOG_TAG, sessionDescription);
    DDLogInfo(@"%@ peer update-remote for %@", LOG_TAG, self.uuid);

    dispatch_async(self.executorQueue, ^{
        [self updateRemoteDescriptionInternalWithSessionDescription:sessionDescription];
    });
}

- (void)addIceCandidates:(nonnull NSArray<TLTransportCandidate *> *)candidates {
    DDLogVerbose(@"%@ addIceCandidates: %@", LOG_TAG, candidates);
    DDLogInfo(@"%@ peer transport-info for %@ (%d)", LOG_TAG, self.uuid, (int)candidates.count);

#if DEBUG_ICE == 1
    for (TLTransportCandidate *c in candidates) {
        DDLogInfo(@"%@ PEER-ICE for %@: %@", LOG_TAG, self.uuid, c.sdp);
    }
#endif

    dispatch_async(self.executorQueue, ^{
        [self addIceCandidateInternalWithIceCandidates:candidates];
    });
}

- (void)sendMessageWithData:(NSMutableData *)data statType:(TLPeerConnectionServiceStatType)statType {
    DDLogVerbose(@"%@ sendMessageWithData: %@ statType: %u", LOG_TAG, data, statType);
    
    dispatch_async(self.executorQueue, ^{
        [self sendMessageInternalWithData:data statType:statType];
    });
}

- (void)sendPacketWithIQ:(nonnull TLBinaryPacketIQ *)iq statType:(TLPeerConnectionServiceStatType)statType {
    DDLogVerbose(@"%@ sendPacketWithIQ: %@ statType: %u", LOG_TAG, iq, statType);
    
    dispatch_async(self.executorQueue, ^{
        @try {
            NSMutableData *data = [iq serializePaddingWithSerializerFactory:self.twinlife.serializerFactory withLeadingPadding:self.leadingPadding];
            [self sendMessageInternalWithData:data statType:statType];

        } @catch (NSException *exception) {
            DDLogError(@"%@ sendPacketWithIQ: %@ exception: %@", LOG_TAG, iq, exception);
            self.statCounters[TLPeerConnectionServiceStatTypeSerializeErrorCount]++;
        }
    });
}

- (void)incrementStatWithStatType:(TLPeerConnectionServiceStatType)statType {
    DDLogVerbose(@"%@ incrementStatWithStatType: %u", LOG_TAG, statType);
    
    switch (statType) {
        case TLPeerConnectionServiceStatTypeIqReceiveSetCount:
        case TLPeerConnectionServiceStatTypeIqReceiveErrorCount:
        case TLPeerConnectionServiceStatTypeIqReceiveResultCount:
        case TLPeerConnectionServiceStatTypeSdpSendClearCount:
        case TLPeerConnectionServiceStatTypeSdpSendEncryptedCount:
        case TLPeerConnectionServiceStatTypeSdpReceiveClearCount:
        case TLPeerConnectionServiceStatTypeSdpReceiveEncryptedCount:
        case TLPeerConnectionServiceStatTypeSerializeErrorCount:
            // Must protect access to statCounters because the instance could have been deleted
            // while we receive SDPs.
            @synchronized (self) {
                if (self.statCounters) {
                    self.statCounters[statType]++;
                }
            }
            break;
            
        default:
            // Other counters are incremented by sendMessageInternalWithData().
            break;
    }
}

- (void)terminatePeerConnectionWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason notifyPeer:(BOOL)notifyPeer {
    DDLogVerbose(@"%@ terminatePeerConnectionWithTerminateReason: %d notifiyPeer: %@", LOG_TAG, terminateReason, notifyPeer ? @"YES" : @"NO");
    DDLogInfo(@"%@ terminate for %@ with %d", LOG_TAG, self.uuid, terminateReason);

    dispatch_async(self.executorQueue, ^{
        [self terminatePeerConnectionInternalWithTerminateReason:terminateReason notifyPeer:notifyPeer];
    });
}

- (void)sendDeviceRinging {
    [self.peerCallService deviceRingingWithSessionId:self.uuid to: self.peerId];
}

- (void)sessionPing {
    DDLogVerbose(@"%@ sessionPing", LOG_TAG);
    
    if (atomic_load(&_terminated)) {
        return;
    }

    if ([self canPing]) {
        [self.peerCallService sessionPingWithSessionId:self.uuid to:self.peerId withBlock:^(TLBaseServiceErrorCode errorCode, NSNumber *requestId) {
            if (errorCode != TLBaseServiceErrorCodeSuccess && errorCode != TLBaseServiceErrorCodeTwinlifeOffline) {
                [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonTimeout notifyPeer:NO];
            }
        }];
    }
}

- (void)onTwinlifeSuspend {
    DDLogVerbose(@"%@ onTwinlifeSuspend", LOG_TAG);
    
    if (atomic_load(&_terminated)) {
        return;
    }
    
    dispatch_async(self.executorQueue, ^{
        TLPeerConnectionServiceTerminateReason terminateReason = (self.connectedTimestamp > 0 ? TLPeerConnectionServiceTerminateReasonDisconnected : TLPeerConnectionServiceTerminateReasonTimeout);
        [self terminatePeerConnectionInternalWithTerminateReason:terminateReason notifyPeer:YES];
    });
}

#pragma mark - Private methods

- (BOOL)createPeerConnectionInternalWithConfiguration:(nonnull RTC_OBJC_TYPE(RTCConfiguration) *)configuration dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate {
    DDLogVerbose(@"%@ createPeerConnectionInternalWithConfiguration: %@", LOG_TAG, configuration);
    
    NSAssert([self.peerConnectionService isExecutorQueue], @"must be executed from the P2P executor Queue");

    // It is possible that the TLPeerConnection was released before creation of the WebRTC instance.
    if (atomic_load(&_terminated)) {
        return NO;
    }

    // Use a data only peer connection factory if this is a data-channel only connection.
    // We avoid the creation and initialization of audio threads, audio devices, codecs and WebRTC media engine.
    // However, if the media aware peer connection factory is available, we are going to use it.
    RTC_OBJC_TYPE(RTCPeerConnectionFactory) *peerConnectionFactory;
    self.withMedia = (self.offer.audio || self.offer.video || self.offer.videoBell);
    peerConnectionFactory = [self.peerConnectionService getPeerConnectionFactoryWithMedia:self.withMedia];
    self.peerConnectionFactory = peerConnectionFactory;

    NSDictionary *optionalConstraints = @{
        @"DtlsSrtpKeyAgreement" : @"YES"
    };
    RTC_OBJC_TYPE(RTCMediaConstraints) *mediaConstraints = [[RTC_OBJC_TYPE(RTCMediaConstraints) alloc] initWithMandatoryConstraints:nil optionalConstraints:optionalConstraints];
    self.peerConnection = [peerConnectionFactory peerConnectionWithConfiguration:configuration constraints:mediaConstraints delegate:self.peerConnectionRTCPeerConnectionDelegate];
    if (!self.peerConnection) {
        [self.twinlife assertionWithAssertPoint:[TLPeerConnectionAssertPoint CREATE_PEER_CONNECTION], [TLAssertValue initWithPeerConnectionId:self.uuid], nil];
        return NO;
    }

    if (self.remoteSessionDescription) {
        RTC_OBJC_TYPE(RTCSessionDescription) *updatedSessionDescription = [self updateCodecsWithSdp:self.remoteSessionDescription];
        self.remoteSessionDescription = nil;
        __weak typeof(self) weakSelf = self;
        [self.peerConnection setRemoteDescription:updatedSessionDescription completionHandler:^(NSError *error) {
            __strong typeof(self) strongSelf = weakSelf;
            [strongSelf onSetRemoteSessionDescriptionInternalWithError:error];
        }];
    }

    _Bool expect = NO;
    if (!atomic_load(&_initialized) && atomic_compare_exchange_strong(&_flushCandidatesActive, &expect, YES)) {
        dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_source_set_timer(self.flushCandidatesTimer, tt, DISPATCH_TIME_FOREVER, 0);
        dispatch_resume(self.flushCandidatesTimer);
    }
    
    if (dataChannelDelegate) {
        TLPeerConnectionDataChannelConfiguration *dataChannelConfiguration = [dataChannelDelegate configurationWithPeerConnectionId:self.uuid sdpEncryptionStatus:[self sdpEncryptionStatus]];
        self.leadingPadding = dataChannelConfiguration.leadingPadding;
        self.dataChannelDelegate = dataChannelDelegate;

        NSMutableString* label = [NSMutableString stringWithCapacity:1024];
        [label appendFormat:@"%@.%@", DATA_CHANNEL_LABEL, dataChannelConfiguration.version];
        RTC_OBJC_TYPE(RTCDataChannelConfiguration) *configuration = [[RTC_OBJC_TYPE(RTCDataChannelConfiguration) alloc] init];
        self.outDataChannel = [self.peerConnection dataChannelForLabel:label configuration:configuration];
        if (!self.outDataChannel) {
            [self.twinlife assertionWithAssertPoint:[TLPeerConnectionAssertPoint CREATE_DATA_CHANNEL], [TLAssertValue initWithPeerConnectionId:self.uuid], nil];
            return NO;
        }
        self.outDataChannel.delegate = self.peerConnectionRTCDataChannelDelegate;
        self.dataSourceOn = YES;

        // If this is a data-channel only WebRTC connection, start the offer or answer immediately.
        // For the audio/video, this will be done at the first call to initSources().
        if (!self.withMedia) {
            if (self.initiator) {
                [self createOfferInternal];
            } else {
                [self createAnswerInternal];
            }
        }
    }

    DDLogInfo(@"%@ peer-connection created for %@", LOG_TAG, self.uuid);

    return YES;
}

- (BOOL)initSourcesInternalWithAudioOn:(BOOL)audioOn videoOn:(BOOL)videoOn {
    DDLogVerbose(@"%@ initSourcesInternalWithAudioOn %@ videoOn: %@", LOG_TAG, audioOn ? @"YES" : @"NO", videoOn ? @"YES" : @"NO");

    NSAssert([self.peerConnectionService isExecutorQueue], @"must be executed from the P2P executor Queue");

    RTC_OBJC_TYPE(RTCPeerConnection) *peerConnection = self.peerConnection;
    if (!peerConnection) {
        return NO;
    }
    

    // !initialized means we're initiating a new P2P connection. If we're muted, we still need to create an audiotrack, otherwise the new peer's
    BOOL updateAudio = self.audioSourceOn != audioOn || (audioOn && !self.audioTrack);
    BOOL updateVideo = self.videoSourceOn != videoOn || (videoOn && !self.videoTrack);
    
    self.audioSourceOn = audioOn;
    self.videoSourceOn = videoOn;

    NSMutableArray<NSString *> *streamIds = [[NSMutableArray alloc] init];
    [streamIds addObject:@"media"];

    // Block and track WebRTC observer calls to peerConnectionShouldNegotiate() while we update
    // the audio/video tracks.  The counter will be incremented from the WebRTC signaling thread
    // while we do the setDirection(), we handle the renegotation at the end if it was necessary.
    atomic_store(&_renegotiationNeeded, 1);

    if (updateAudio) {
        if (self.audioSourceOn) {
            self.audioTrack = [self.peerConnectionFactory audioTrackWithTrackId:[[NSUUID UUID] UUIDString]];
            if (!self.audioTrack) {
                self.statCounters[TLPeerConnectionServiceStatTypeAudioTrackErrorCount]++;
                [self.twinlife assertionWithAssertPoint:[TLPeerConnectionAssertPoint CREATE_AUDIO_TRACK], [TLAssertValue initWithPeerConnectionId:self.uuid], nil];
                return NO;
            }
                
            // Enable the audio track only when we are connected.
            if (self.state == RTCIceConnectionStateConnected || self.state == RTCIceConnectionStateCompleted) {
                self.audioTrack.isEnabled = YES;
            }
            
            RTC_OBJC_TYPE(RTCRtpSender) *audioTrackSender = nil;

            // The audio is turned ON: find a transceiver for Audio which is active and use it.
            for (RTC_OBJC_TYPE(RTCRtpTransceiver) *transceiver in [self.peerConnection transceivers]) {
                if (![transceiver isStopped] && [transceiver mediaType] == RTCRtpMediaTypeAudio && [transceiver direction] != RTCRtpTransceiverDirectionSendRecv) {
                    RTC_OBJC_TYPE(RTCRtpSender) *sender = [transceiver sender];

                    sender.track = self.audioTrack;
                    [transceiver setDirection:RTCRtpTransceiverDirectionSendRecv error:nil];
                    audioTrackSender = sender;
                    break;
                }
            }

            // When no RtpTransceiver was found, use addTrack to add the new track.
            if (!audioTrackSender) {
                audioTrackSender = [self.peerConnection addTrack:self.audioTrack streamIds:streamIds];
            }

            id<TLPeerConnectionDelegate> delegate = self.delegate;
            if (delegate) {
                dispatch_async(self.executorQueue, ^{
                    if (self.audioTrack) {
                        [delegate onAddLocalAudioTrackWithPeerConnectionId:self.uuid sender:audioTrackSender audioTrack:self.audioTrack];
                    }
                });
            }
            
        } else {
            self.audioTrack.isEnabled = NO;
            self.audioTrack = nil;
            
            // The audio is turned OFF and we have an audio track: clear the tracks with audio
            // and set the transceiver to the inactive state (but keep it).
            for (RTC_OBJC_TYPE(RTCRtpTransceiver) *transceiver in [self.peerConnection transceivers]) {
                if (![transceiver isStopped] && [transceiver mediaType] == RTCRtpMediaTypeAudio && [transceiver direction] == RTCRtpTransceiverDirectionSendRecv) {
                    RTC_OBJC_TYPE(RTCRtpSender) *sender = [transceiver sender];
                    sender.track = nil;
                    [transceiver setDirection:RTCRtpTransceiverDirectionRecvOnly error:nil];
                }
            }
        }
    } else if (!atomic_load(&_initialized) && self.offer.audio) {
        // If we add a participant while muted, we need to make sure to create an audio transceiver otherwise
        // we won't receive the peer's audio.
        RTC_OBJC_TYPE(RTCRtpTransceiver) *transceiver = [self.peerConnection addTransceiverOfType:RTCRtpMediaTypeAudio];
        if (transceiver) {
            [transceiver setDirection:RTCRtpTransceiverDirectionRecvOnly error:nil];
        }
    }
    
    if (updateVideo) {
        
        if (self.videoSourceOn) {
            self.videoTrack = [self.peerConnectionService createVideoTrackWithPeerConnectionFactory:self.peerConnectionFactory];
            if (!self.videoTrack) {
                self.statCounters[TLPeerConnectionServiceStatTypeVideoTrackErrorCount]++;
                [self.twinlife assertionWithAssertPoint:[TLPeerConnectionAssertPoint CREATE_VIDEO_TRACK], [TLAssertValue initWithPeerConnectionId:self.uuid], nil];
                return NO;
            }
            
            RTC_OBJC_TYPE(RTCRtpSender) *videoTrackSender = nil;

            // The video is turned ON: find a transceiver for Video which is active and use it.
            for (RTC_OBJC_TYPE(RTCRtpTransceiver) *transceiver in [self.peerConnection transceivers]) {
                if (![transceiver isStopped] && [transceiver mediaType] == RTCRtpMediaTypeVideo && [transceiver direction] != RTCRtpTransceiverDirectionSendRecv) {
                    RTC_OBJC_TYPE(RTCRtpSender) *sender = [transceiver sender];
                    
                    sender.track = self.videoTrack;
                    [transceiver setDirection:RTCRtpTransceiverDirectionSendRecv error:nil];
                    videoTrackSender = sender;
                    break;
                }
            }

            // When no RtpTransceiver was found, use addTrack to add the new track.
            if (!videoTrackSender) {
                [self.peerConnection addTrack:self.videoTrack streamIds:streamIds];
            }

        } else {

            // The video is turned OFF and we have a video track: clear the tracks with video
            // and set the transceiver to the inactive state (but keep it).
            for (RTC_OBJC_TYPE(RTCRtpTransceiver) *transceiver in [self.peerConnection transceivers]) {
                if (![transceiver isStopped] && [transceiver mediaType] == RTCRtpMediaTypeVideo && [transceiver direction] == RTCRtpTransceiverDirectionSendRecv) {
                    RTC_OBJC_TYPE(RTCRtpSender) *sender = [transceiver sender];
                    sender.track = nil;
                    [transceiver setDirection:RTCRtpTransceiverDirectionRecvOnly error:nil];
                }
            }
                        
            [self.peerConnectionService releaseVideoTrack:self.videoTrack];
            self.videoTrack = nil;
        }
    }

    if (!atomic_load(&_initialized)) {
        if (self.initiator) {
            [self createOfferInternal];
        } else {
            [self createAnswerInternal];
        }
    } else {
        [self checkRenegotiationWithCounter:1];
    }
    return YES;
}

- (void)checkRenegotiationWithCounter:(int)counter {
    DDLogInfo(@"%@ checkRenegotiationWithCounter: %@ counter: %d renegotiationNeeded: %d", LOG_TAG, self.uuid, counter, atomic_load(&_renegotiationNeeded));

    // Handle renegotiation only when:
    // - we have sent the session-initiate,
    // - the WebRTC observer peerConnectionShouldNegotiate() was called.
    int updatedCounter = atomic_fetch_sub(&_renegotiationNeeded, counter) - counter;
    if (updatedCounter > 0) {
        // We can handle the renegotiation only if there is nothing in progress.
        // Check and update the pending counter as it will be used to decrement
        // the renegotationNeeded when we have sent our session-update.
        int expect = 0;
        if (atomic_compare_exchange_strong(&_renegotationPending, &expect, updatedCounter)) {
            [self doRenegotiationInternal];
        } else {
            DDLogError(@"%@ renegotation for %@ in progress: %d", LOG_TAG, self.uuid, atomic_load(&_renegotationPending));
        }
    }
}

- (void)setAudioDirectionInternalWithDirection:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setAudioDirectionInternalWithDirection: %ld", LOG_TAG, (long)direction);

    if (atomic_load(&_terminated)) {
        return;
    }

    [self initSourcesWithAudioOn:(direction == RTCRtpTransceiverDirectionSendRecv) videoOn:self.videoSourceOn];
}

- (void)setVideoDirectionInternalWithDirection:(RTCRtpTransceiverDirection)direction {
    DDLogVerbose(@"%@ setVideoDirectionInternalWithDirection: %ld", LOG_TAG, (long)direction);
    
    if (atomic_load(&_terminated)) {
        return;
    }

    [self initSourcesWithAudioOn:self.audioSourceOn videoOn:(direction == RTCRtpTransceiverDirectionSendRecv)];
}

- (void)acceptRemoteDescriptionInternalWithSessionDescription:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription {
    DDLogVerbose(@"%@ acceptRemoteDescriptionInternalWithSessionDescription: %@", LOG_TAG, [sessionDescription.sdp stringByReplacingOccurrencesOfString:@"\r" withString:@""]);

    NSAssert([self.peerConnectionService isExecutorQueue], @"must be executed from the P2P executor Queue");

    if (atomic_load(&_terminated) || !self.peerConnection) {
        return;
    }

    if (self.acceptedTimestamp == 0) {
        self.acceptedTimestamp = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    }
    atomic_store(&_renegotiationNeeded, 1);

    RTC_OBJC_TYPE(RTCSessionDescription) *updatedSessionDescription = [self updateCodecsWithSdp:sessionDescription];
        
    __weak typeof(self) weakSelf = self;
    [self.peerConnection setRemoteDescription:updatedSessionDescription completionHandler:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf onSetRemoteSessionDescriptionInternalWithError:error];
    }];

    id<TLPeerConnectionDelegate> delegate = self.delegate;
    if (delegate) {
        dispatch_async(self.executorQueue, ^{
            [delegate onAcceptPeerConnectionWithPeerConnectionId:self.uuid offer:self.peerOffer];
        });
    }
}

- (void)updateRemoteDescriptionInternalWithSessionDescription:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription {
    DDLogVerbose(@"%@ updateRemoteDescriptionInternalWithSessionDescription: %@", LOG_TAG, [sessionDescription.sdp stringByReplacingOccurrencesOfString:@"\r" withString:@""]);
    
    NSAssert([self.peerConnectionService isExecutorQueue], @"must be executed from the P2P executor Queue");

    if (atomic_load(&_terminated)) {
        return;
    }

    // See https://w3c.github.io/webrtc-pc/#perfect-negotiation-example
    // An offer may come in while we are busy processing SRD(answer).
    // In this case, we will be in "stable" by the time the offer is processed
    // so it is safe to chain it on our Operations Chain now.
    RTCSignalingState state = [self.peerConnection signalingState];
    BOOL isOffer = sessionDescription.type == RTCSdpTypeOffer;
    BOOL readyForOffer = atomic_load(&_renegotationPending) == 0 && (state == RTCSignalingStateStable || self.isSettingRemoteAnswerPending);
    BOOL offerCollision = isOffer && !readyForOffer;

    self.ignoreOffer = !self.initiator && offerCollision;
    if (self.ignoreOffer) {

        DDLogInfo(@"%@ ignore offer sdp state=%ld", LOG_TAG, (long) state);

        return;
    }

    atomic_store(&_renegotiationNeeded, 1);
    RTC_OBJC_TYPE(RTCSessionDescription) *updatedSessionDescription = [self updateCodecsWithSdp:sessionDescription];

    self.isSettingRemoteAnswerPending = sessionDescription.type == RTCSdpTypeAnswer;
    __weak typeof(self) weakSelf = self;
    [self.peerConnection setRemoteDescription:updatedSessionDescription completionHandler:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;

        if (!strongSelf) {
            
            return;
        }

        strongSelf.isSettingRemoteAnswerPending = NO;

        // Create the answer even if this failed.
        if (isOffer) {
            // We can handle this renegotiation immediately but we must increment the pending counter
            // so that it is taken into account by checkRenegotiationWithCounter().
            atomic_fetch_add(&strongSelf->_renegotationPending, 1);

            [strongSelf createAnswerInternal];
        }
    }];
}

- (void)onSetRemoteSessionDescriptionInternalWithError:(nullable NSError *)error {
    DDLogVerbose(@"%@ onSetRemoteSessionDescriptionInternalWithError: %@", LOG_TAG, error);
    
    self.isSettingRemoteAnswerPending = NO;
    if (error) {
        DDLogError(@"Failed to create Session Description with error: %@", error.description);
        return;
    }
    
    // WebRTC accepts ICE candidates only when it has both the local description
    // and the remote description.  If we call addIceCandidates too early, they are dropped.
    if (!atomic_load(&_initialized)) {
        return;
    }
    NSMutableArray<TLTransportCandidate *> *iceRemoteCandidates;
    @synchronized(self) {
        iceRemoteCandidates = self.iceRemoteCandidates;
        self.iceRemoteCandidates = nil;
    }
    
    if (iceRemoteCandidates) {
        [self addIceCandidates:iceRemoteCandidates];
    }
}

- (void)addIceCandidateInternalWithIceCandidates:(nonnull NSArray<TLTransportCandidate *> *)candidates {
    DDLogVerbose(@"%@ addIceCandidateInternalWithIceCandidates: %@", LOG_TAG, candidates);

    // Protect the addObject in case another thread calls onSetRemoteSessionDescriptionInternalWithError.
    @synchronized(self) {
        if (self.iceRemoteCandidates) {
            [self.iceRemoteCandidates addObjectsFromArray:candidates];
            return;
        }
    }

    NSUUID *sessionId = self.uuid;
    NSMutableArray<RTC_OBJC_TYPE(RTCIceCandidate) *> *removeList = nil;
    for (TLTransportCandidate *candidate in candidates) {
        RTC_OBJC_TYPE(RTCIceCandidate) *iceCandidate = [[RTC_OBJC_TYPE(RTCIceCandidate) alloc] initWithSdp:candidate.sdp sdpMLineIndex:candidate.ident sdpMid:candidate.label];
        if (!candidate.removed) {
            atomic_fetch_add(&_remoteIceCandidatesCount, 1);
            [self.peerConnection addIceCandidate:iceCandidate completionHandler:^(NSError *error) {
                if (error) {
                    DDLogError(@"Failed to add IceCandidate: %@ in %@ with error: %@", iceCandidate, sessionId, error.description);
                }
            }];
        } else {
            if (!removeList) {
                removeList = [[NSMutableArray alloc] init];
            }
            atomic_fetch_sub(&_remoteIceCandidatesCount, 1);
            [removeList addObject:iceCandidate];
        }
    }
    if (removeList) {
        [self.peerConnection removeIceCandidates:removeList];
    }
}

- (void)sendMessageInternalWithData:(nonnull NSMutableData *)data statType:(TLPeerConnectionServiceStatType)statType {
    DDLogVerbose(@"%@ sendMessageInternalWithData: %@ statType: %u", LOG_TAG, data, statType);
    
    NSAssert([self.peerConnectionService isExecutorQueue], @"must be executed from the P2P executor Queue");

    // Don't try sending the message if the P2P connection is terminated (stats are cleared).
    if (atomic_load(&_terminated)) {
        return;
    }

    if (self.leadingPadding) {
        if (data.length <= MAX_FRAME_SIZE) {
            uint8_t value = OP_BINARY | (uint8_t) (FLAG_FIN << 4);
            [data replaceBytesInRange:NSMakeRange(0, sizeof(int8_t)) withBytes:&value];
            if ([self.outDataChannel sendData:[[RTC_OBJC_TYPE(RTCDataBuffer) alloc] initWithData:data isBinary:YES]]) {
                self.statCounters[statType]++;
            } else {
                self.statCounters[TLPeerConnectionServiceStatTypeSendErrorCount]++;
                if (self.statCounters[TLPeerConnectionServiceStatTypeFirstSendError] == 0) {
                    self.statCounters[TLPeerConnectionServiceStatTypeFirstSendError] = statType + 1;
                    self.statCounters[TLPeerConnectionServiceStatTypeFirstSendErrorTime] = (int) NS_TO_MSEC(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - self.connectedTimestamp);
                }
            }
        } else {
            NSMutableData *frame = [[NSMutableData alloc] initWithCapacity:MAX_FRAME_SIZE];
            uint8_t value = OP_BINARY;
            [frame appendBytes:&value length:1];
            [frame appendData:[data subdataWithRange:NSMakeRange(1, MAX_FRAME_SIZE - 1)]];
            if ([self.outDataChannel sendData:[[RTC_OBJC_TYPE(RTCDataBuffer) alloc] initWithData:frame isBinary:YES]]) {
                self.statCounters[statType]++;
            } else {
                self.statCounters[TLPeerConnectionServiceStatTypeSendErrorCount]++;
                if (self.statCounters[TLPeerConnectionServiceStatTypeFirstSendError] == 0) {
                    self.statCounters[TLPeerConnectionServiceStatTypeFirstSendError] = statType + 1;
                    self.statCounters[TLPeerConnectionServiceStatTypeFirstSendErrorTime] = (int) NS_TO_MSEC(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - self.connectedTimestamp);
                }
            }
            
            NSUInteger start = MAX_FRAME_SIZE;
            while (start < data.length) {
                NSUInteger length = MIN(MAX_FRAME_SIZE - 1, data.length - start);
                frame = [[NSMutableData alloc] initWithCapacity:length + 1];
                if (start + length < data.length) {
                    value = OP_CONTINUATION;
                    [frame appendBytes:&value length:1];
                } else {
                    value = OP_CONTINUATION | (uint8_t) (FLAG_FIN << 4);
                    [frame appendBytes:&value length:1];
                }
                [frame appendData:[data subdataWithRange:NSMakeRange(start, length)]];
                if (![self.outDataChannel sendData:[[RTC_OBJC_TYPE(RTCDataBuffer) alloc] initWithData:frame isBinary:YES]]) {
                    self.statCounters[TLPeerConnectionServiceStatTypeSendErrorCount]++;
                }
                start += length;
            }
        }
    } else {
        if ([self.outDataChannel sendData:[[RTC_OBJC_TYPE(RTCDataBuffer) alloc] initWithData:data isBinary:YES]]) {
            self.statCounters[statType]++;
        } else {
            self.statCounters[TLPeerConnectionServiceStatTypeSendErrorCount]++;
            if (self.statCounters[TLPeerConnectionServiceStatTypeFirstSendError] == 0) {
                self.statCounters[TLPeerConnectionServiceStatTypeFirstSendError] = statType + 1;
                self.statCounters[TLPeerConnectionServiceStatTypeFirstSendErrorTime] = (int) NS_TO_MSEC(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - self.connectedTimestamp);
            }
        }
    }
}

- (void)createAnswerInternal {
    DDLogVerbose(@"%@ createAnswerInternal", LOG_TAG);
    DDLogInfo(@"%@ creating-answer for %@", LOG_TAG, self.uuid);

    if (self.acceptedTimestamp == 0) {
        self.acceptedTimestamp = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
    }

    // Create the answer by setting the local description and let Web-RTC define the correct answer.
    __weak typeof(self) weakSelf = self;
    [self.peerConnection setLocalDescriptionWithCompletionHandler:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [strongSelf onSetLocalDescriptionWithSessionDescription:nil error:error];
    }];
}

- (void)createOfferInternal {
    DDLogVerbose(@"%@ createOfferInternal", LOG_TAG);
    DDLogInfo(@"%@ creating-offer for %@", LOG_TAG, self.uuid);

    NSMutableDictionary *mandatoryConstraints = [[NSMutableDictionary alloc] init];
    if (self.offerToReceive.video && self.videoTrack) {
        mandatoryConstraints[@"OfferToReceiveVideo"] = @"YES";
    }
    
    if (self.offerToReceive.audio && self.audioTrack) {
        mandatoryConstraints[@"OfferToReceiveAudio"] = @"YES";
    }
    
    RTC_OBJC_TYPE(RTCMediaConstraints) *mediaConstraints = [[RTC_OBJC_TYPE(RTCMediaConstraints) alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
    __weak typeof(self) weakSelf = self;
    [self.peerConnection offerForConstraints:mediaConstraints completionHandler:^(RTC_OBJC_TYPE(RTCSessionDescription) *sessionDescription, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        [strongSelf onCreateOfferWithSessionDescription:sessionDescription error:error];
    }];
}

- (void)onSetLocalDescriptionWithSessionDescription:(nullable RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription error:(nullable NSError *)error {
    DDLogVerbose(@"%@ onSetLocalDescriptionWithSessionDescription: %@ error: %@", LOG_TAG, [sessionDescription.sdp stringByReplacingOccurrencesOfString:@"\r" withString:@""], error);
    
    if (atomic_load(&_terminated)) {
        return;
    }
    
    if (error) {
        DDLogError(@"Failed to create Session Description with error: %@", error.description);
        return;
    }
    
    // Get the local session description and filter the codecs before sending the SDP to the peer.
    if (!sessionDescription) {
        sessionDescription = [self.peerConnection localDescription];
        sessionDescription = [self updateCodecsWithSdp:sessionDescription];
    }
    
    TLSdp *sdp = [[TLSdp alloc] initWithSdp:sessionDescription.sdp];
    _Bool expect = NO;
    if (atomic_compare_exchange_strong(&_initialized, &expect, YES)) {
        atomic_store(&_renegotiationNeeded, 0);
        if (sessionDescription.type == RTCSdpTypeAnswer) {
            DDLogInfo(@"%@ sending session-accept for %@", LOG_TAG, self.uuid);
            
            [self.peerConnectionService sessionAcceptWithPeerConnection:self sdp:sdp offer:self.offer offerToReceive:self.offerToReceive maxReceivedFrameSize:self.configuration.maxReceivedFrameSize maxReceivedFrameRate:self.configuration.maxReceivedFrameRate withBlock:^(TLBaseServiceErrorCode errorCode, NSNumber *requestId) {
                [self onSendServerWithErrorCode:errorCode requestId:requestId];
            }];
            
            // If we have some peer ICE candidates, give them to the WebRTC connection now it is ready.
            NSArray<TLTransportCandidate *> *iceRemoteCandidates;
            @synchronized(self) {
                iceRemoteCandidates = self.iceRemoteCandidates;
                self.iceRemoteCandidates = nil;
            }
            
            if (iceRemoteCandidates) {
                [self addIceCandidateInternalWithIceCandidates:iceRemoteCandidates];
            }
            
        } else {
            DDLogInfo(@"%@ sending session-initiate for %@", LOG_TAG, self.uuid);
            
            [self.peerConnectionService sessionInitiateWithPeerConnection:self sdp:sdp offer:self.offer offerToReceive:self.offerToReceive notificationContent:self.notificationContent withBlock:^(TLBaseServiceErrorCode errorCode, NSNumber *requestId) {
                
                // An ITEM_NOT_FOUND on the session-initiate means the peer was revoked.
                if (errorCode == TLBaseServiceErrorCodeItemNotFound) {
                    [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonRevoked notifyPeer:NO];
                    return;
                }
                
                [self onSendServerWithErrorCode:errorCode requestId:requestId];
            }];
        }
    } else {
        DDLogInfo(@"%@ sending session-update for %@", LOG_TAG, self.uuid);
        
        [self.peerConnectionService sessionUpdateWithPeerConnection:self type:sessionDescription.type sdp:sdp withBlock:^(TLBaseServiceErrorCode errorCode, NSNumber *requestId) {
            [self onSendServerWithErrorCode:errorCode requestId:requestId];
        }];

        // Now we can decrement the renegotiation counter and handle a possible deferred renegotiation.
        int pendingCounter = atomic_exchange(&_renegotationPending, 0);
        [self checkRenegotiationWithCounter:pendingCounter];
    }
}

- (void)onSendServerWithErrorCode:(TLBaseServiceErrorCode)errorCode requestId:(NSNumber *)requestId {
    DDLogVerbose(@"%@ onSendServerWithErrorCode: %d requestId: %@", LOG_TAG, errorCode, requestId);

    switch (errorCode) {
        case TLBaseServiceErrorCodeQueued:
        case TLBaseServiceErrorCodeSuccess:
            if (atomic_load(&_flushCandidatesActive)) {
                int64_t flushDelay;
                if (errorCode == TLBaseServiceErrorCodeSuccess) {
                    flushDelay = 300 * NSEC_PER_MSEC;
                } else {
                    flushDelay = self.audioSourceOn || self.videoSourceOn ? 2000 * NSEC_PER_MSEC : 700 * NSEC_PER_MSEC;
                }
                dispatch_time_t tt = dispatch_time(DISPATCH_TIME_NOW, flushDelay);

                // We can call dispatch_source_set_timer() only from the executor's thread
                // because it could be released if the P2P connection is terminated.
                __weak TLPeerConnection *weakSelf = self;
                dispatch_async(self.executorQueue, ^{
                    TLPeerConnection *strongSelf = weakSelf;
                    if (strongSelf && !atomic_load(&strongSelf->_terminated) && atomic_load(&strongSelf->_flushCandidatesActive) && strongSelf.flushCandidatesTimer) {
                        dispatch_source_set_timer(strongSelf.flushCandidatesTimer, tt, DISPATCH_TIME_FOREVER, 0);
                        DDLogInfo(@"%@ increased delay for %@ to %lld", LOG_TAG, strongSelf.uuid, flushDelay);
                    }
                });
            }
            break;

        case TLBaseServiceErrorCodeQueuedNoWakeup:
            // If this is a data only P2P session and we have no wait to wakeup the peer, cancel this P2P session
            if (!self.audioSourceOn && !self.videoSourceOn && self.dataSourceOn) {
                [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonCancel notifyPeer:YES];
            }
            break;

        case TLBaseServiceErrorCodeNoPermission:
        case TLBaseServiceErrorCodeNotAuthorizedOperation:
        case TLBaseServiceErrorCodeFeatureNotSupportedByPeer:
            [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonNotAuthorized notifyPeer:NO];
            break;

        case TLBaseServiceErrorCodeItemNotFound:
            [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonCancel notifyPeer:NO];
            break;

        case TLBaseServiceErrorCodeExpired:
            [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonTimeout notifyPeer:NO];
            break;

        case TLBaseServiceErrorCodeTimeoutError:
        case TLBaseServiceErrorCodeTwinlifeOffline:
            [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonConnectivityError notifyPeer:NO];
            break;

        default:
            [self terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonGeneralError notifyPeer:NO];
            break;
    }
}

- (void)onCreateOfferWithSessionDescription:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription error:(nullable NSError *)error {
    DDLogVerbose(@"%@ onCreateOfferWithSessionDescription: %@ error: %@", LOG_TAG, sessionDescription, error);

    if (atomic_load(&_terminated)) {
        return;
    }

    if (error) {
        DDLogError(@"Failed to create Session Description with error: %@", error.description);
        return;
    }

    // Filter the codecs before sending the SDP to the peer.
    RTC_OBJC_TYPE(RTCSessionDescription) *updatedSessionDescription = [self updateCodecsWithSdp:sessionDescription];

    __weak typeof(self) weakSelf = self;
    [self.peerConnection setLocalDescription:updatedSessionDescription completionHandler:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;

        if (!strongSelf) {
            return;
        }

        [strongSelf onSetLocalDescriptionWithSessionDescription:updatedSessionDescription error:error];
    }];
}

- (void)onRenegotiationNeededInternal {
    DDLogInfo(@"%@ onRenegotiationNeededInternal %@ renegotiationNeeded: %d", LOG_TAG, self.uuid, atomic_load(&_renegotiationNeeded));

    // Check that we are allowed to make the renegotiation and update the counter to track the request.
    int previous = atomic_fetch_add(&_renegotiationNeeded, 1);
    if (previous > 0) {
        return;
    }

    // We can handle this renegotiation immediately but before we must check and update the pending counter
    // as it will be used to decrement the renegotationNeeded when we have sent our session-update.
    int expect = 0;
    if (atomic_compare_exchange_strong(&_renegotationPending, &expect, 1)) {
        [self doRenegotiationInternal];
    }
}

- (void)doRenegotiationInternal {
    DDLogVerbose(@"%@ doRenegotiationInternal", LOG_TAG);
    
    // Called from the signaling thread
    if (atomic_load(&_terminated)) {
        return;
    }
    
    DDLogInfo(@"%@ doing-renegotiation for %@", LOG_TAG, self.uuid);

    __weak typeof(self) weakSelf = self;
    [self.peerConnection setLocalDescriptionWithCompletionHandler:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {

            return;
        }

        [strongSelf onSetLocalDescriptionWithSessionDescription:nil error:error];
    }];
}

- (BOOL)canPing {
    DDLogVerbose(@"%@ canPing", LOG_TAG);

    if (!self.offer.audio && !self.offer.video) {

        return NO;
    }

    if (self.initiator) {
        
        return YES;
    }

    NSRange range = [self.peerId rangeOfString:@"/"];
    return range.location != NSNotFound ? YES : NO;
}

- (void)terminatePeerConnectionInternalWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason notifyPeer:(BOOL)notifyPeer {
    DDLogVerbose(@"%@ terminatePeerConnectionInternalWithTerminateReason: %d notifiyPeer: %@", LOG_TAG, terminateReason, notifyPeer ? @"YES" : @"NO");
    
    NSAssert([self.peerConnectionService isExecutorQueue], @"must be executed from the P2P executor Queue");

    _Bool expect = NO;
    if (!atomic_compare_exchange_strong(&_terminated, &expect, YES)) {
        return;
    }

    // Avoid retaining self for the last dispatch_async().
    NSUUID *sessionId = self.uuid;
    if (notifyPeer) {
        DDLogInfo(@"%@ sending session-terminate for %@ with %d", LOG_TAG, sessionId, terminateReason);
        [self.peerCallService sessionTerminateWithSessionId:sessionId to:self.peerId reason:terminateReason];
    }

    // Clear the WebRTC delegate as soon as we are terminate to make sure the signaling thread
    // will not call us while we are closing (it will not harm due to the atomic_load(&_terminated) tests).
    if (self.peerConnection) {
        self.peerConnection.delegate = nil;

        DDLogInfo(@"%@ getting-stats for %@", LOG_TAG, self.uuid);

        [self.peerConnection statisticsWithCompletionHandler:^(RTC_OBJC_TYPE(RTCStatisticsReport) *report) {
            dispatch_async(self.executorQueue, ^{
                self.statsReport = report;
                
                [self disposeInternal];
            });
        }];
    } else {
        [self disposeInternal];
    }
    
    [self.peerConnectionService onTerminatePeerConnectionWithPeerConnectionId:sessionId terminateReason:terminateReason];

    id<TLPeerConnectionDelegate> delegate = self.delegate;
    if (delegate) {
        dispatch_async(self.executorQueue, ^{
            [delegate onTerminatePeerConnectionWithPeerConnectionId:sessionId terminateReason:terminateReason];
        });
    }
}

#pragma mark - WebRTC delegate

// WebRTC delegate methods are called from the WebRTC signaling thread.

- (void)onSignalingChangeInternalWithSignalingState:(RTCSignalingState)signalingState {
    DDLogVerbose(@"%@ onSignalingChangeInternalWithSignalingState: %ld", LOG_TAG, (long)signalingState);
    
    if (atomic_load(&_terminated)) {
        return;
    }
    
    if (signalingState == RTCSignalingStateClosed) {
        dispatch_async(self.executorQueue, ^{
            [self terminatePeerConnectionInternalWithTerminateReason:TLPeerConnectionServiceTerminateReasonConnectivityError notifyPeer:YES];
        });
    }
}

- (void)onIceConnectionChangeInternalWithIceConnectionState:(RTCIceConnectionState)iceConnectionState {
    DDLogVerbose(@"%@ onIceConnectionChangeInternalWithIceConnectionState: %ld", LOG_TAG, (long)iceConnectionState);
    
    if (atomic_load(&_terminated)) {
        return;
    }
    DDLogInfo(@"%@ connection-state for %@ is %ld", LOG_TAG, self.uuid, (long)iceConnectionState);

    self.state = iceConnectionState;

    id<TLPeerConnectionDelegate> delegate = self.delegate;
    __weak typeof(self) weakSelf = self;
    switch (iceConnectionState) {
        case RTCIceConnectionStateNew:
            if (delegate) {
                dispatch_async(self.executorQueue, ^{
                    __strong typeof(self) strongSelf = weakSelf;
                    if (strongSelf) {
                        [delegate onChangeConnectionStateWithPeerConnectionId:strongSelf.uuid state:TLPeerConnectionServiceConnectionStateConnecting];
                    }
                });
            }
            break;
            
        case RTCIceConnectionStateChecking:
            if (delegate) {
                dispatch_async(self.executorQueue, ^{
                    __strong typeof(self) strongSelf = weakSelf;
                    if (strongSelf) {
                        [delegate onChangeConnectionStateWithPeerConnectionId:strongSelf.uuid state:TLPeerConnectionServiceConnectionStateChecking];
                    }
                });
            }
            break;
            
        case RTCIceConnectionStateConnected:
            if (self.connectedTimestamp == 0) {
                self.connectedTimestamp = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
            }
            if (delegate) {
                dispatch_async(self.executorQueue, ^{
                    __strong typeof(self) strongSelf = weakSelf;
                    if (strongSelf) {
                        [delegate onChangeConnectionStateWithPeerConnectionId:strongSelf.uuid state:TLPeerConnectionServiceConnectionStateConnected];
                    }
                });
            }

            // Now that we are connected, enable the audio and video tracks unless they are muted.
            if (self.audioTrack) {
                self.audioTrack.isEnabled = self.audioSourceOn;
            }
            if (self.videoTrack) {
                self.videoTrack.isEnabled = self.videoSourceOn;
            }
            break;
            
        case RTCIceConnectionStateDisconnected:
        case RTCIceConnectionStateFailed: {
            if (self.connectedTimestamp > 0) {
                __uint64_t now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
                if (self.restartIceTimestamp + 15L * NSEC_PER_SEC < now) {
                    // Trigger the ICE restart in 2.5 (audio/video) or 5.0 (data) seconds in case it was a transient disconnect.
                    // We must be careful that the P2P connection could have been terminated and released.
                    int64_t delay = (self.withMedia ? RESTART_ICE_DELAY * NSEC_PER_MSEC : RESTART_DATA_ICE_DELAY * NSEC_PER_MSEC);
                    DDLogInfo(@"%@ dispatch restart-ice for %@ in %ld", LOG_TAG, self.uuid, (long)delay);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), self.executorQueue, ^{
                        __strong typeof(self) strongSelf = weakSelf;
                        if (strongSelf) {
                            [strongSelf restartIce];
                        }
                    });
                    return;
                }
            }
            dispatch_async(self.executorQueue, ^{
                __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf) {
                    TLPeerConnectionServiceTerminateReason terminateReason = iceConnectionState == RTCIceConnectionStateDisconnected ? TLPeerConnectionServiceTerminateReasonDisconnected : TLPeerConnectionServiceTerminateReasonConnectivityError;
                    [strongSelf terminatePeerConnectionInternalWithTerminateReason:terminateReason notifyPeer:YES];
                }
            });
            break;
        }

        case RTCIceConnectionStateClosed: {
            // The ICE agent for this RTCPeerConnection has shut down and is no longer handling requests.
            // Not really an error but some proper shut down.
            dispatch_async(self.executorQueue, ^{
                __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf terminatePeerConnectionInternalWithTerminateReason:TLPeerConnectionServiceTerminateReasonDisconnected notifyPeer:YES];
                }
            });
            break;
        }

        default:
            break;
    }
}

- (void)onIceCandidateInternalWithIceCandidate:(nonnull RTC_OBJC_TYPE(RTCIceCandidate) *)candidate {
    DDLogVerbose(@"%@ onIceCandidateInternalWithIceCandidate: %@", LOG_TAG, candidate);
    DDLogInfo(@"%@ ICE: %@", LOG_TAG, candidate.sdp);

    if (atomic_load(&_terminated)) {
        return;
    }

    [self.pendingCandidates addCandidateWithId:candidate.sdpMLineIndex label:candidate.sdpMid sdp:candidate.sdp];

    // Check if we must flush after having added the ICE:
    // - we must be initialized,
    // - the flush timer must be inactive (NO)
    atomic_fetch_add(&_localIceCandidatesCount, 1);
    BOOL needFlush = !atomic_load(&_flushCandidatesActive) && atomic_load(&_initialized);
    if (needFlush) {
        [self flushCandidates];
    }
}

- (void)onIceCandidateRemovedInternalWithIceCandidate:(NSArray<RTC_OBJC_TYPE(RTCIceCandidate) *> *)candidates {
    DDLogVerbose(@"%@ onIceCandidateRemovedInternalWithIceCandidate: %@", LOG_TAG, candidates);

    if (atomic_load(&_terminated)) {
        return;
    }

    for (RTC_OBJC_TYPE(RTCIceCandidate) *candidate in candidates) {
        [self.pendingCandidates removeCandidateWithId:candidate.sdpMLineIndex label:candidate.sdpMid sdp:candidate.sdp];
    }

    // Check if we must flush after having added the ICE.
    // - we must be initialized,
    // - the flush timer must be inactive (NO)
    atomic_fetch_sub(&_localIceCandidatesCount, (int) candidates.count);
    BOOL needFlush = !atomic_load(&_flushCandidatesActive) && atomic_load(&_initialized);
    if (needFlush) {
        [self flushCandidates];
    }
}

- (void)onAddReceiverWithReceiver:(RTC_OBJC_TYPE(RTCRtpReceiver) *)rtpReceiver streams:(NSArray<RTC_OBJC_TYPE(RTCMediaStream) *> *)mediaStreams {
    DDLogVerbose(@"%@ onAddReceiverWithReceiver: %@", LOG_TAG, rtpReceiver);

    if (atomic_load(&_terminated)) {
        return;
    }

    RTC_OBJC_TYPE(RTCMediaStreamTrack) *track = [rtpReceiver track];
    id<TLPeerConnectionDelegate> delegate = self.delegate;
    if (delegate) {
        dispatch_async(self.executorQueue, ^{
            [delegate onAddRemoteTrackWithPeerConnectionId:self.uuid mediaTrack:track];
        });
    }
}

- (void)onRemoveRemoteTrackWithTrackId:(nonnull NSString *)trackId {
    DDLogVerbose(@"%@ onRemoveRemoteTrackWithTrackId: %@", LOG_TAG, trackId);

    if (atomic_load(&_terminated)) {
        return;
    }

    id<TLPeerConnectionDelegate> delegate = self.delegate;
    if (delegate) {
        dispatch_async(self.executorQueue, ^{
            [delegate onRemoveRemoteTrackWithPeerConnectionId:self.uuid trackId:trackId];
        });
    }
}

- (void)onDataChannelInternalWithDataChannel:(nonnull RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel {
    DDLogVerbose(@"%@ onDataChannelInternalWithDataChannel: %@", LOG_TAG, dataChannel);

    if (atomic_load(&_terminated)) {
        return;
    }

    self.inDataChannel = dataChannel;
    NSString *label = dataChannel.label;
    NSRange range = [label rangeOfString:@"."];
    if (range.location == NSNotFound) {
        self.inDataChannelExtension = nil;
    } else {
        self.inDataChannelExtension = [label substringFromIndex:range.location + 1];
    }
    self.inDataChannel.delegate = self.peerConnectionRTCDataChannelDelegate;
    if (self.dataChannelState == RTCDataChannelStateOpen && self.dataChannelDelegate) {
        [self.dataChannelDelegate onDataChannelOpenWithPeerConnectionId:self.uuid peerVersion:self.inDataChannelExtension leadingPadding:self.leadingPadding];
    }
}

- (void)onDataChannelStateChangeInternalWithDataChannel:(nonnull RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel {
    DDLogVerbose(@"%@ onDataChannelStateChangeInternalWithDataChannel: %@", LOG_TAG, dataChannel);

    if (atomic_load(&_terminated)) {
        return;
    }

    if (dataChannel.readyState == self.dataChannelState) {
        return;
    }
    self.dataChannelState = dataChannel.readyState;
    
    if (self.dataChannelState == RTCDataChannelStateOpen) {
        if (self.inDataChannel && self.dataChannelDelegate) {
            [self.dataChannelDelegate onDataChannelOpenWithPeerConnectionId:self.uuid peerVersion:self.inDataChannelExtension leadingPadding:self.leadingPadding];
        }
    } else if (self.dataChannelState == RTCDataChannelStateClosed && self.dataChannelDelegate) {
        [self.dataChannelDelegate onDataChannelClosedWithPeerConnectionId:self.uuid];
    }
}

- (void)onDataChannelMessageWithDataChannel:(nonnull RTC_OBJC_TYPE(RTCDataChannel) *)dataChannel buffer:(nonnull RTC_OBJC_TYPE(RTCDataBuffer) *)buffer {
    DDLogVerbose(@"%@ onDataChannelMessageWithDataChannel: %@ buffer: %@", LOG_TAG, dataChannel, buffer);
    
    if (!self.leadingPadding) {
        self.statCounters[TLPeerConnectionServiceStatTypeIqReceiveCount]++;
        if (self.dataChannelDelegate) {
            [self.dataChannelDelegate onDataChannelMessageWithPeerConnectionId:self.uuid data:buffer.data leadingPadding:NO];
        }
        return;
    }

    if (buffer.data.length < 1) {
        return;
    }
    uint8_t b = 0;
    [buffer.data getBytes:&b range:NSMakeRange(0, sizeof(uint8_t))];
    uint8_t opcode = (uint8_t)(b & 0xf);
    uint8_t flags = (uint8_t)(0xf & (b >> 4));
    if (opcode == OP_BINARY) {
        NSData *frame = [buffer.data subdataWithRange:NSMakeRange(1, buffer.data.length - 1)];
        if (flags == FLAG_FIN) {
            self.statCounters[TLPeerConnectionServiceStatTypeIqReceiveCount]++;
            if (self.dataChannelDelegate) {
                [self.dataChannelDelegate onDataChannelMessageWithPeerConnectionId:self.uuid data:frame leadingPadding:YES];
            }
        } else {
            [self.outDataFrames removeAllObjects];
            [self.outDataFrames addObject:frame];
        }
    } else if (opcode == OP_CONTINUATION) {
        NSData *frame = [buffer.data subdataWithRange:NSMakeRange(1, buffer.data.length - 1)];
        [self.outDataFrames addObject:frame];
        
        if (flags == FLAG_FIN) {
            int length = 0;
            for (NSData *lFrame in self.outDataFrames) {
                length += lFrame.length;
            }
            NSMutableData *data = [[NSMutableData alloc] initWithCapacity:length];
            for (NSData *lFrame in self.outDataFrames) {
                [data appendData:lFrame];
            }
            [self.outDataFrames removeAllObjects];
            self.statCounters[TLPeerConnectionServiceStatTypeIqReceiveCount]++;
            if (self.dataChannelDelegate) {
                [self.dataChannelDelegate onDataChannelMessageWithPeerConnectionId:self.uuid data:data leadingPadding:YES];
            }
        }
    }
}

#pragma mark - Internal methods

- (void)flushCandidates {
    DDLogVerbose(@"%@: flushCandidates", LOG_TAG);

    if (atomic_load(&_terminated)) {
        return;
    }

    // Invalidate the timer the first time flushCandidates is called.
    _Bool expect = YES;
    if (atomic_compare_exchange_strong(&_flushCandidatesActive, &expect, NO)) {
        dispatch_source_cancel(self.flushCandidatesTimer);
        self.flushCandidatesTimer = nil;
    }
    if ([self.pendingCandidates isFlushed]) {
        return;
    }

    [self.peerConnectionService transportInfoWithPeerConnection:self candidates:self.pendingCandidates withBlock:^(TLBaseServiceErrorCode errorCode, NSNumber *requestId) {
        if (errorCode == TLBaseServiceErrorCodeSuccess) {
            [self.pendingCandidates removeWithRequestId:[requestId longLongValue]];
        } else if (errorCode == TLBaseServiceErrorCodeTwinlifeOffline || errorCode == TLBaseServiceErrorCodeTimeoutError) {
            [self.pendingCandidates cancelWithRequestId:[requestId longLongValue]];
        } else {
            if (requestId != nil) {
                [self.pendingCandidates removeWithRequestId:[requestId longLongValue]];
            }
                
            [self onSendServerWithErrorCode:errorCode requestId:requestId];
        }
    }];
}

- (void)restartIce {
    DDLogVerbose(@"%@: restartIce", LOG_TAG);
    
    if (atomic_load(&_terminated)) {
        return;
    }
    
    @synchronized(self) {
        if (!self.peerConnection) {
            return;
        }
        if (self.state != RTCIceConnectionStateDisconnected && self.state != RTCIceConnectionStateFailed) {
            return;
        }
    }
    self.restartIceTimestamp = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

    DDLogInfo(@"%@ restart-ice for %@ in state %ld", LOG_TAG, self.uuid, (long)self.state);

    // Allow and trigger renegotiation.
    atomic_store(&_renegotiationNeeded, 0);
    [self.peerConnection restartIce];

    // Give 5s to recover or fail.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5000 * NSEC_PER_MSEC), self.executorQueue, ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            if (atomic_load(&strongSelf->_terminated)) {
                return;
            }
            
            @synchronized(self) {
                if (strongSelf.state == RTCIceConnectionStateConnected) {
                    return;
                }
            }
            [strongSelf terminatePeerConnectionWithTerminateReason:TLPeerConnectionServiceTerminateReasonDisconnected notifyPeer:YES];
        }
    });
}

- (NSString *)getAudioReport {
    DDLogVerbose(@"%@: getAudioReport", LOG_TAG);
    
    NSMutableString *report = [NSMutableString stringWithCapacity:1024];
    NSMutableString *audioLocal = nil;
    NSMutableString *audioRemote = nil;
    
    [report appendFormat:@"%d:hard:hard", AUDIO_REPORT_VERSION];
    for (id key in self.statsReport.statistics) {
        RTC_OBJC_TYPE(RTCStatistics) *stats = [self.statsReport.statistics objectForKey:key];
        
        id value = stats.values[@"kind"];
        if (stats.type && value && [value isEqualToString:@"audio"]) {
            if ([stats.type isEqualToString:@"inbound-rtp"]) {
                // See https://www.w3.org/TR/webrtc-stats/#inboundrtpstats-dict*
                id totalSamplesReceived = stats.values[@"totalSamplesReceived"];
                id totalSamplesDuration = stats.values[@"totalSamplesDuration"];
                id totalAudioEnergy = stats.values[@"totalAudioEnergy"];
                id jitterBufferDelay = stats.values[@"jitterBufferDelay"];
                id audioLevel = stats.values[@"audioLevel"];
                id concealedSamples = stats.values[@"concealedSamples"];
                id concealmentEvents = stats.values[@"concealmentEvents"];
                id silentConcealedSamples = stats.values[@"silentConcealedSamples"];
                audioRemote = [NSMutableString stringWithCapacity:128];
                
                if (jitterBufferDelay && totalSamplesReceived) {
                    double audioJitter = [jitterBufferDelay doubleValue] / [totalSamplesReceived doubleValue];
                    [audioRemote appendFormat:@"%.3f:", audioJitter];
                } else {
                    [audioRemote appendString:@"0.0:"];
                }
                if (totalAudioEnergy) {
                    [audioRemote appendFormat:@"%.3f:", [totalAudioEnergy doubleValue]];
                } else {
                    [audioRemote appendString:@"0:"];
                }
                if (totalSamplesDuration) {
                    [audioRemote appendFormat:@"%.3f:", [totalSamplesDuration doubleValue]];
                } else {
                    [audioRemote appendString:@"0:"];
                }
                if (audioLevel) {
                    [audioRemote appendFormat:@"%.3f:", [audioLevel doubleValue]];
                } else {
                    [audioRemote appendString:@"0:"];
                }
                if (concealmentEvents) {
                    [audioRemote appendFormat:@"%ld:", [concealmentEvents longValue]];
                } else {
                    [audioRemote appendString:@"0:"];
                }
                if (concealedSamples) {
                    [audioRemote appendFormat:@"%ld:", [concealedSamples longValue]];
                } else {
                    [audioRemote appendString:@"0:"];
                }
                if (silentConcealedSamples) {
                    [audioRemote appendFormat:@"%ld:", [silentConcealedSamples longValue]];
                } else {
                    [audioRemote appendString:@"0:"];
                }
               
            } else if ([stats.type isEqualToString:@"outbound-rtp"]) {
                // WebRTC 79 introduced the mediaSourceId and we have to look at that object to retrieve the local info.
                // See https://www.w3.org/TR/webrtc-stats/#outboundrtpstats-dict*
                value = stats.values[@"mediaSourceId"];
                if (value) {
                    stats = [self.statsReport.statistics objectForKey:value];
                    if (stats) {
                        id totalSamplesDuration = stats.values[@"totalSamplesDuration"];
                        id totalAudioEnergy = stats.values[@"totalAudioEnergy"];
                        audioLocal = [NSMutableString stringWithCapacity:128];
                        
                        if (totalAudioEnergy) {
                            [audioLocal appendFormat:@"%.3f:", [totalAudioEnergy doubleValue]];
                        } else {
                            [audioLocal appendString:@"0:"];
                        }
                        
                        if (totalSamplesDuration) {
                            [audioLocal appendFormat:@"%.3f:", [totalSamplesDuration doubleValue]];
                        } else {
                            [audioLocal appendString:@"0:"];
                        }
                    }
                }
            }
        }
    }
    if (audioLocal) {
        [report appendString:@":audio-send:"];
        [report appendString:audioLocal];
    }
    if (audioRemote) {
        [report appendString:@":audio-recv:"];
        [report appendString:audioRemote];
    }
    return report;
}

- (NSString *)getVideoReport {
    DDLogVerbose(@"%@: getVideoReport", LOG_TAG);
    
    NSMutableString *report = [NSMutableString stringWithCapacity:1024];
    NSMutableString *videoLocal = nil;
    NSMutableString *videoRemote = nil;
    
    [report appendFormat:@"%d", VIDEO_REPORT_VERSION];
    for (id key in self.statsReport.statistics) {
        RTC_OBJC_TYPE(RTCStatistics) *stats = [self.statsReport.statistics objectForKey:key];
        
        id value = stats.values[@"kind"];
        if (stats.type && value && [value isEqualToString:@"video"]) {
            id frameWidth = stats.values[@"frameWidth"];
            id frameHeight = stats.values[@"frameHeight"];
            if ([stats.type isEqualToString:@"inbound-rtp"]) {
                // See https://www.w3.org/TR/webrtc-stats/#inboundrtpstats-dict*
                id framesReceived = stats.values[@"framesReceived"];
                id framesDecoded = stats.values[@"framesDecoded"];
                id framesDropped = stats.values[@"framesDropped"];
                id keyFramesDecoded = stats.values[@"keyFramesDecoded"];
                id freezeCount = stats.values[@"freezeCount"];
                id totalFreezesDuration = stats.values[@"totalFreezesDuration"];
                videoRemote = [NSMutableString stringWithCapacity:128];
                
                if (frameWidth) {
                    [videoRemote appendFormat:@"%ld:", [frameWidth longValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
                if (frameHeight) {
                    [videoRemote appendFormat:@"%ld:", [frameHeight longValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
                if (framesReceived) {
                    [videoRemote appendFormat:@"%ld:", [framesReceived longValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
                if (framesDecoded) {
                    [videoRemote appendFormat:@"%ld:", [framesDecoded longValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
                if (framesDropped) {
                    [videoRemote appendFormat:@"%ld:", [framesDropped longValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
                if (keyFramesDecoded) {
                    [videoRemote appendFormat:@"%ld:", [keyFramesDecoded longValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
                if (freezeCount) {
                    [videoRemote appendFormat:@"%ld:", [freezeCount longValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
                if (totalFreezesDuration) {
                    [videoRemote appendFormat:@"%.3f:", [totalFreezesDuration doubleValue]];
                } else {
                    [videoRemote appendString:@"0:"];
                }
              
            } else if ([stats.type isEqualToString:@"outbound-rtp"]) {
                // See https://www.w3.org/TR/webrtc-stats/#outboundrtpstats-dict*
                videoLocal = [NSMutableString stringWithCapacity:128];
                
                if (frameWidth) {
                    [videoLocal appendFormat:@"%ld:", [frameWidth longValue]];
                } else {
                    [videoLocal appendString:@"0:"];
                }
                if (frameHeight) {
                    [videoLocal appendFormat:@"%ld:", [frameHeight longValue]];
                } else {
                    [videoLocal appendString:@"0:"];
                }
                
                id framesSent = stats.values[@"framesSent"];
                if (framesSent) {
                    [videoLocal appendFormat:@"%ld:", [framesSent longValue]];
                } else {
                    [videoLocal appendString:@"0:"];
                }
            }
        }
    }
    if (videoLocal) {
        [report appendString:@":video-send:"];
        [report appendString:videoLocal];
    }
    if (videoRemote) {
        [report appendString:@":video-recv:"];
        [report appendString:videoRemote];
    }
    return report;
}

- (NSString *)getStatsReport {
    DDLogVerbose(@"%@: getStatsReport", LOG_TAG);
    
    NSMutableString *report = [NSMutableString stringWithCapacity:1024];
    
    [report appendFormat:@"%d::duration:", STATS_REPORT_VERSION];
    if (self.connectedTimestamp != 0) {
        [report appendFormat:@"%lld:", NS_TO_SEC(self.stopTimestamp - self.connectedTimestamp + 999999999)];
    } else {
        [report appendString:@"0:"];
    }
    
    for (id key in self.statsReport.statistics) {
        RTC_OBJC_TYPE(RTCStatistics) *stats = [self.statsReport.statistics objectForKey:key];
        
        if (!stats.type) {
            continue;
        }
        if ([stats.type isEqualToString:@"transport"]) {
            long bytesSent = 0;
            long bytesReceived = 0;
            
            id value = stats.values[@"bytesSent"];
            if (value) {
                bytesSent = [value intValue];
            }
            
            value = stats.values[@"bytesReceived"];
            if (value) {
                bytesReceived = [value intValue];
            }
            if (bytesSent > 0 || bytesReceived > 0) {
                [report appendFormat:@":transport:%ld", bytesSent];
                [report appendFormat:@":%ld:", bytesReceived];
                [report appendString:[self getCandidatesWithPairId:(NSString *)stats.values[@"selectedCandidatePairId"]]];
                [report appendString:@":"];
            }
            
        } else if ([stats.type isEqualToString:@"inbound-rtp"]) {
            id value = stats.values[@"kind"];
            if (value && [value isEqualToString:@"audio"]) {
                NSString* codecId = [self getCodecWithCodecId:stats.values[@"codecId"]];
                if (codecId) {
                    [report appendString:@":inbound-rtp:"];
                    [report appendString:codecId];
                    
                    value = stats.values[@"bytesReceived"];
                    [report appendFormat:@":%@:", value ? value : @"0"];
                    
                    value = stats.values[@"packetsReceived"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                    
                    value = stats.values[@"packetsLost"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                }
                
            } else if (value && [value isEqualToString:@"video"]) {
                NSString* codecId = [self getCodecWithCodecId:stats.values[@"codecId"]];
                if (codecId) {
                    [report appendString:@":inbound-rtp:"];
                    [report appendString:codecId];
                    
                    value = stats.values[@"bytesReceived"];
                    [report appendFormat:@":%@:", value ? value : @"0"];
                    
                    value = stats.values[@"packetsReceived"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                    
                    value = stats.values[@"packetsLost"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                    
                    value = stats.values[@"framesDecoded"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                }
            }
            
        } else if ([stats.type isEqualToString:@"outbound-rtp"]) {
            id value = stats.values[@"kind"];
            if (value && [value isEqualToString:@"audio"]) {
                NSString* codecId = [self getCodecWithCodecId:stats.values[@"codecId"]];
                if (codecId) {
                    [report appendString:@":outbound-rtp:"];
                    [report appendString:codecId];
                    
                    value = stats.values[@"bytesSent"];
                    [report appendFormat:@":%@:", value ? value : @"0"];
                    
                    value = stats.values[@"packetsSent"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                }
                
            } else if (value && [value isEqualToString:@"video"]) {
                NSString* codecId = [self getCodecWithCodecId:stats.values[@"codecId"]];
                if (codecId) {
                    [report appendString:@":outbound-rtp:"];
                    [report appendString:codecId];
                    
                    value = stats.values[@"bytesSent"];
                    [report appendFormat:@":%@:", value ? value : @"0"];
                    
                    value = stats.values[@"packetsSent"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                    
                    value = stats.values[@"framesEncoded"];
                    [report appendFormat:@"%@:", value ? value : @"0"];
                }
            }
            
        } else if ([stats.type isEqualToString:@"data-channel"]) {
            
            id value = stats.values[@"bytesSent"];
            [report appendFormat:@":data-channel:%@:", value ? value : @"0"];
            
            value = stats.values[@"bytesReceived"];
            [report appendFormat:@"%@:", value ? value : @"0"];
            
            value = stats.values[@"messagesReceived"];
            [report appendFormat:@"%@:", value ? value : @"0"];
            
            value = stats.values[@"messagesSent"];
            [report appendFormat:@"%@:", value ? value : @"0"];
        }
    }
    return report;
}

- (NSString *)getCandidatesWithPairId:(NSString *)pairId {
    DDLogVerbose(@"%@: getCandidatesWithPairId: %@", LOG_TAG, pairId);
    
    if (pairId) {
        RTC_OBJC_TYPE(RTCStatistics) *stats = [self.statsReport.statistics objectForKey:pairId];
        if (stats) {
            NSString *localNetworkType = @"-";
            NSString *localProtocol = @"-";
            NSString *localCandidateType = @"-";
            NSString *remoteProtocol = @"-";
            NSString *remoteCandidateType = @"-";
            self.selectedCandidateStats = stats;
            id localId = stats.values[@"localCandidateId"];
            if (localId) {
                RTC_OBJC_TYPE(RTCStatistics) *localStats = [self.statsReport.statistics objectForKey:localId];
                if (localStats) {
                    id value = localStats.values[@"networkType"];
                    if (value) {
                        localNetworkType = (NSString *)value;
                    }
                    
                    value = localStats.values[@"protocol"];
                    if (value) {
                        localProtocol = (NSString *)value;
                    }
                    
                    value = localStats.values[@"candidateType"];
                    if (value) {
                        localCandidateType = (NSString *)value;
                        if ([localCandidateType isEqualToString:@"relay"]) {
                            value = localStats.values[@"relayProtocol"];
                            if (value) {
                                localProtocol = (NSString *)value;
                            }
                        }
                    }
                }
            }
            id remoteId = stats.values[@"remoteCandidateId"];
            if (remoteId) {
                RTC_OBJC_TYPE(RTCStatistics) *remoteStats = [self.statsReport.statistics objectForKey:remoteId];
                if (remoteStats) {
                    id value = remoteStats.values[@"protocol"];
                    if (value) {
                        remoteProtocol = (NSString *)value;
                    }
                    
                    value = remoteStats.values[@"candidateType"];
                    if (value) {
                        remoteCandidateType = (NSString *)value;
                    }
                }
            }
            
            NSMutableString *report = [NSMutableString stringWithCapacity:128];
            
            [report appendString:localNetworkType];
            [report appendString:@":"];
            [report appendString:localProtocol];
            [report appendString:@":"];
            [report appendString:localCandidateType];
            [report appendString:@":"];
            [report appendString:remoteProtocol];
            [report appendString:@":"];
            [report appendString:remoteCandidateType];
            return report;
        }
    }
    return @"-:-:-:-:-";
}

- (NSString *)getCodecWithCodecId:(id)codecId {
    DDLogVerbose(@"%@: getCodecWithCodecId: %@", LOG_TAG, codecId);
    
    if (codecId) {
        RTC_OBJC_TYPE(RTCStatistics) *stats = [self.statsReport.statistics objectForKey:codecId];
        
        if (stats) {
            id mimeType = stats.values[@"mimeType"];
            id clockRate = stats.values[@"clockRate"];
            
            NSMutableString *report = [NSMutableString stringWithCapacity:128];
            [report appendFormat:@"%@", mimeType ? mimeType : @""];
            [report appendFormat:@":%@", clockRate ? clockRate : @""];
            
            return report;
        }
    }
    
    return nil;
}

- (void)disposeInternal {
    DDLogVerbose(@"%@: disposeInternal", LOG_TAG);

    NSAssert([self.peerConnectionService isExecutorQueue], @"must be executed from the P2P executor Queue");
    DDLogInfo(@"%@ closing for %@", LOG_TAG, self.uuid);

    self.stopTimestamp = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

    // Make sure to keep the lock only for a short time and do not call any WebRTC method here.
    RTC_OBJC_TYPE(RTCPeerConnection) *peerConnection;
    RTC_OBJC_TYPE(RTCPeerConnectionFactory) *peerConnectionFactory;
    RTC_OBJC_TYPE(RTCVideoTrack) *videoTrack;
    int *statCounters;
    @synchronized (self) {
        peerConnection = self.peerConnection;
        peerConnectionFactory = self.peerConnectionFactory;
        videoTrack = self.videoTrack;
        statCounters = self.statCounters;

        if (self.inDataChannel) {
            self.inDataChannel.delegate = nil;
            self.inDataChannel = nil;
        }
        if (self.outDataChannel) {
            self.outDataChannel.delegate = nil;
            self.outDataChannel = nil;
        }
 
        self.peerConnection = nil;
        self.peerConnectionFactory = nil;
        self.videoTrack = nil;
        self.statCounters = nil;
    }

    if (videoTrack) {
        [self.peerConnectionService releaseVideoTrack:videoTrack];
    }

    // Release the timer if it is active.  We must also resume it before a cancel otherwise
    // we will crash in the xref_dispose.
    if (self.flushCandidatesTimer) {
        if (!atomic_load(&_flushCandidatesActive)) {
            dispatch_resume(self.flushCandidatesTimer);
        }
        dispatch_source_cancel(self.flushCandidatesTimer);
        self.flushCandidatesTimer = nil;
    }
   
    NSString *report = [self getStatsReport];
    // Report with connection time information
    NSMutableString *connectReport = [NSMutableString stringWithCapacity:256];
    [connectReport appendFormat:@"%d::connect:", CONNECT_REPORT_VERSION];
    if (self.connectedTimestamp != 0 && self.acceptedTimestamp != 0) {
        [connectReport appendFormat:@"%lld:", NS_TO_MSEC(self.connectedTimestamp - self.acceptedTimestamp)];
    } else if (self.connectedTimestamp != 0) {
        [connectReport appendFormat:@"%lld:", NS_TO_MSEC(self.connectedTimestamp - self.startTimestamp)];
    } else {
        [connectReport appendFormat:@"%lld:", NS_TO_MSEC(self.stopTimestamp - self.startTimestamp)];
    }
    [connectReport appendString:@":accept:"];
    if (self.acceptedTimestamp != 0) {
        [connectReport appendFormat:@"%lld:", NS_TO_MSEC(self.acceptedTimestamp - self.startTimestamp)];
    } else {
        [connectReport appendString:@"0:"];
    }
    [connectReport appendFormat:@":iceRemote:%d::iceLocal:%d:", atomic_load(&_remoteIceCandidatesCount), atomic_load(&_localIceCandidatesCount)];
    RTC_OBJC_TYPE(RTCStatistics) *stats = self.selectedCandidateStats;
    if (stats) {
        id value = stats.values[@"totalRoundTripTime"];
        [connectReport appendFormat:@":rtt:%@:", value ? value : @"0"];
        
        value = stats.values[@"currentRoundTripTime"];
        [connectReport appendFormat:@"%@:", value ? value : @"0"];
        
        value = stats.values[@"requestsReceived"];
        [connectReport appendFormat:@"%@:", value ? value : @"0"];
        
        value = stats.values[@"requestsSent"];
        [connectReport appendFormat:@"%@:", value ? value : @"0"];

        value = stats.values[@"responsesReceived"];
        [connectReport appendFormat:@"%@:", value ? value : @"0"];
        
        value = stats.values[@"responsesSent"];
        [connectReport appendFormat:@"%@:", value ? value : @"0"];
        
        value = stats.values[@"consentRequestsSent"];
        [connectReport appendFormat:@"%@:", value ? value : @"0"];
        
        value = stats.values[@"packetsDiscardedOnSend"];
        [connectReport appendFormat:@"%@:", value ? value : @"0"];
        
        value = stats.values[@"bytesDiscardedOnSend"];
        [connectReport appendFormat:@"%@", value ? value : @"0"];

        id localId = stats.values[@"localCandidateId"];
        RTC_OBJC_TYPE(RTCStatistics) *localStats = [self.statsReport.statistics objectForKey:localId];
        if (localStats) {
            value = localStats.values[@"url"];
            // Note: URL is not available if this is a host <-> host connection and we are on the same network.
            if (value) {
                [connectReport appendFormat:@":%@", value];
                NSArray<RTC_OBJC_TYPE(RTCHostname) *> *hostnames = sHostnames;
                if (hostnames) {
                    for (RTC_OBJC_TYPE(RTCHostname) *host in hostnames) {
                        if ([value containsString:host.hostname]) {
                            [connectReport appendFormat:@":%@", host.ipv4];
                            break;
                        }
                    }
                }
            }
        }
    }
    
    // Report iq statistics if we were connected and it was a data channel.
    NSMutableString *iqReport = nil;
    if (self.connectedTimestamp != 0 && self.offer.data) {
        iqReport = [NSMutableString stringWithCapacity:256];
        [iqReport appendFormat:@"%d:set", IQ_REPORT_VERSION];
        for (int i = 0; i < SET_STAT_LIST_COUNT; i++) {
            [iqReport appendFormat:@":%d", statCounters[SET_STAT_LIST[i]]];
        }
        [iqReport appendFormat:@":result"];
        for (int i = 0; i < RESULT_STAT_LIST_COUNT; i++) {
            [iqReport appendFormat:@":%d", statCounters[RESULT_STAT_LIST[i]]];
        }
        [iqReport appendFormat:@":recv"];
        for (int i = 0; i < RECEIVE_STAT_LIST_COUNT; i++) {
            [iqReport appendFormat:@":%d", statCounters[RECEIVE_STAT_LIST[i]]];
        }
        [iqReport appendFormat:@":sdp"];
        for (int i = 0; i < SDP_STAT_LIST_COUNT; i++) {
            [iqReport appendFormat:@":%d", statCounters[SDP_STAT_LIST[i]]];
        }
        if (self.leadingPadding) {
            [iqReport appendString:@":P"];
        }

        BOOL hasErrors = NO;
        for (int i = 0; i < ERROR_STAT_LIST_COUNT; i++) {
            if (statCounters[ERROR_STAT_LIST[i]] > 0) {
                hasErrors = YES;
                break;
            }
        }
        if (hasErrors) {
            [iqReport appendString:@":err"];
            for (int i = 0; i < ERROR_STAT_LIST_COUNT; i++) {
                [iqReport appendFormat:@":%d", statCounters[ERROR_STAT_LIST[i]]];
            }
        }
    }

    NSString *audioReport = nil;
    if (self.audioSourceOn) {
        audioReport = [self getAudioReport];
    }
    NSString *videoReport = nil;
    if (self.videoSourceOn) {
        videoReport = [self getVideoReport];
    }
    
    free(statCounters);
    self.statsReport = nil;
    
    NSMutableDictionary* attributes = [[NSMutableDictionary alloc] initWithCapacity:5];
    [attributes setObject:[self.uuid UUIDString] forKey:PEER_CONNECTION_ID];
    [attributes setObject:(self.initiator ? OUTBOUND : INBOUND) forKey:ORIGIN];
    [attributes setObject:report forKey:STATS_REPORT];
    [attributes setObject:connectReport forKey:CONNECT_REPORT];
    if (iqReport) {
        [attributes setObject:iqReport forKey:IQ_REPORT];
    }
    if (audioReport) {
        [attributes setObject:audioReport forKey:AUDIO_REPORT];
    }
    if (videoReport) {
        [attributes setObject:videoReport forKey:VIDEO_REPORT];
    }
    [[self.twinlife getManagementService] logEventWithEventId:EVENT_ID_PEER_CONNECTION attributes:attributes flush:YES];

    [self.peerConnectionService disposeWithPeerConnection:peerConnection factory:peerConnectionFactory];
}

- (nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)updateCodecsWithSdp:(nonnull RTC_OBJC_TYPE(RTCSessionDescription) *)sessionDescription {
    DDLogVerbose(@"%@ updateCodecsWithSdp: %@", LOG_TAG, sessionDescription);
    
    NSString *filteredSdp = [TLSdp filterCodecsWithSDP:sessionDescription.sdp];
    if (filteredSdp == sessionDescription.sdp) {
        return sessionDescription;
    } else {
        DDLogVerbose(@"%@ Previous SDP: %@", LOG_TAG, sessionDescription.sdp);
        DDLogVerbose(@"%@ New SDP: %@", LOG_TAG, filteredSdp);

        return [[RTC_OBJC_TYPE(RTCSessionDescription) alloc] initWithType:sessionDescription.type sdp:filteredSdp];
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"[id:%@ peerId:%@]", self.uuid, self.peerId];
    return string;
}

@end

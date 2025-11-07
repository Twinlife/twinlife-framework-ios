/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <WebRTC/RTCMacros.h>
#import <WebRTC/RTCRtpTransceiver.h>

#import "TLBaseService.h"
#import "TLVersion.h"

#define PEER_CONNECTION_MAJOR_VERSION 2
#define PEER_CONNECTION_MINOR_VERSION 2

@protocol TLRepositoryObject;
@class TLTwincodeOutbound;
@class TLBinaryPacketIQ;

typedef enum {
    TLPeerConnectionServiceTerminateReasonBusy,
    TLPeerConnectionServiceTerminateReasonCancel,
    TLPeerConnectionServiceTerminateReasonConnectivityError,
    TLPeerConnectionServiceTerminateReasonDecline,
    TLPeerConnectionServiceTerminateReasonDisconnected,
    TLPeerConnectionServiceTerminateReasonGeneralError,
    TLPeerConnectionServiceTerminateReasonGone,
    TLPeerConnectionServiceTerminateReasonNotAuthorized,
    TLPeerConnectionServiceTerminateReasonSuccess,
    TLPeerConnectionServiceTerminateReasonRevoked,
    TLPeerConnectionServiceTerminateReasonTimeout,
    TLPeerConnectionServiceTerminateReasonTransferDone,
    TLPeerConnectionServiceTerminateReasonSchedule,
    TLPeerConnectionServiceTerminateReasonMerge,
    TLPeerConnectionServiceTerminateReasonUnknown,

    // Specific errors raised for encryption/decryption of SDPs.
    TLPeerConnectionServiceTerminateReasonNotEncrypted,
    TLPeerConnectionServiceTerminateReasonNoPublicKey,
    TLPeerConnectionServiceTerminateReasonNoPrivateKey,
    TLPeerConnectionServiceTerminateReasonNoSecretKey,
    TLPeerConnectionServiceTerminateReasonDecryptError,
    TLPeerConnectionServiceTerminateReasonEncryptError
} TLPeerConnectionServiceTerminateReason;

typedef enum {
    TLPeerConnectionServiceConnectionStateConnecting,
    TLPeerConnectionServiceConnectionStateRinging,
    TLPeerConnectionServiceConnectionStateChecking,
    TLPeerConnectionServiceConnectionStateConnected
} TLPeerConnectionServiceConnectionState;

typedef enum {
    TLPeerConnectionServiceSdpEncryptionStatusNone,
    TLPeerConnectionServiceSdpEncryptionStatusEncrypted,
    TLPeerConnectionServiceSdpEncryptionStatusEncryptedNeedRenew
} TLPeerConnectionServiceSdpEncryptionStatus;

typedef enum {
    TLPeerConnectionServiceNotificationPriorityNotDefined,
    TLPeerConnectionServiceNotificationPriorityLow,
    TLPeerConnectionServiceNotificationPriorityHigh
} TLPeerConnectionServiceNotificationPriority;

typedef enum {
    TLPeerConnectionServiceNotificationOperationNotDefined,
    TLPeerConnectionServiceNotificationOperationAudioCall,
    TLPeerConnectionServiceNotificationOperationVideoCall,
    TLPeerConnectionServiceNotificationOperationVideoBell,
    TLPeerConnectionServiceNotificationOperationPushMessage,
    TLPeerConnectionServiceNotificationOperationPushFile,
    TLPeerConnectionServiceNotificationOperationPushImage,
    TLPeerConnectionServiceNotificationOperationPushAudio,
    TLPeerConnectionServiceNotificationOperationPushVideo
} TLPeerConnectionServiceNotificationOperation;

typedef enum {
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
    TLPeerConnectionServiceStatTypeIqError,
    
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
    TLPeerConnectionServiceStatTypeIqResultSignatureInfo,

    TLPeerConnectionServiceStatTypeIqReceiveCount,
    TLPeerConnectionServiceStatTypeIqReceiveSetCount,
    TLPeerConnectionServiceStatTypeIqReceiveResultCount,
    TLPeerConnectionServiceStatTypeIqReceiveErrorCount,
    
    TLPeerConnectionServiceStatTypeSdpSendClearCount,
    TLPeerConnectionServiceStatTypeSdpSendEncryptedCount,
    TLPeerConnectionServiceStatTypeSdpReceiveClearCount,
    TLPeerConnectionServiceStatTypeSdpReceiveEncryptedCount,

    TLPeerConnectionServiceStatTypeSerializeErrorCount,
    TLPeerConnectionServiceStatTypeSendErrorCount,
    TLPeerConnectionServiceStatTypeAudioTrackErrorCount,
    TLPeerConnectionServiceStatTypeVideoTrackErrorCount,
    TLPeerConnectionServiceStatTypeFirstSendError,
    TLPeerConnectionServiceStatTypeFirstSendErrorTime,

    TLPeerConnectionServiceStatTypeIqLast
} TLPeerConnectionServiceStatType;

//
// Interface: TLOffer
//

@interface TLOffer : NSObject

@property BOOL audio;
@property BOOL video;
@property BOOL videoBell;
@property BOOL data;
@property BOOL group;
@property BOOL transfer;
@property (nullable) TLVersion *version;

- (nonnull instancetype)initWithAudio:(BOOL)audio video:(BOOL)video videoBell:(BOOL)videoBell data:(BOOL)data;

- (nonnull instancetype)initWithAudio:(BOOL)audio video:(BOOL)video videoBell:(BOOL)videoBell data:(BOOL)data group:(BOOL)group transfer:(BOOL)transfer version:(nonnull TLVersion *)version;

@end

//
// Interface: TLOfferToReceive
//

@interface TLOfferToReceive : NSObject

@property BOOL audio;
@property BOOL video;
@property BOOL data;

- (nonnull instancetype)initWithAudio:(BOOL)audio video:(BOOL)video data:(BOOL)data;

@end

//
// Interface: TLNotificationContent
//

@interface TLNotificationContent : NSObject

@property TLPeerConnectionServiceNotificationPriority priority;
@property TLPeerConnectionServiceNotificationOperation operation;
@property int timeToLive;

- (nonnull instancetype)initWithPriority:(TLPeerConnectionServiceNotificationPriority)priority operation:(TLPeerConnectionServiceNotificationOperation)operation timeToLive:(int)timeToLive;

@end

//
// Interface: TLPeerConnectionServiceConfiguration:
//

@interface TLPeerConnectionServiceConfiguration: TLBaseServiceConfiguration

@property BOOL acceptIncomingCalls;
@property BOOL enableAudioVideo;

@end

//
// Protocol: TLPeerConnectionDelegate
//

@class RTC_OBJC_TYPE(RTCMediaStream);
@class RTC_OBJC_TYPE(RTCRtpSender);
@class RTC_OBJC_TYPE(RTCVideoTrack);
@class RTC_OBJC_TYPE(RTCAudioTrack);
@class RTC_OBJC_TYPE(RTCMediaStreamTrack);
@class RTC_OBJC_TYPE(RTCDataBuffer);
@class RTC_OBJC_TYPE(RTCVideoView);

@protocol TLPeerConnectionDelegate

- (void)onAcceptPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer;

- (void)onChangeConnectionStateWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId state:(TLPeerConnectionServiceConnectionState)state;

- (void)onTerminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)onAddLocalAudioTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull RTC_OBJC_TYPE(RTCRtpSender) *)sender audioTrack:(nonnull RTC_OBJC_TYPE(RTCAudioTrack) *)audioTrack;

- (void)onAddRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId mediaTrack:(nonnull RTC_OBJC_TYPE(RTCMediaStreamTrack) *)mediaTrack;

- (void)onRemoveLocalSenderWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sender:(nonnull RTC_OBJC_TYPE(RTCRtpSender) *)sender;

- (void)onRemoveRemoteTrackWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId trackId:(nonnull NSString *)trackId;

- (void)onPeerHoldCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onPeerResumeCallWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

@end

//
// Protocol: TLPeerConnectionServiceDelegate
//

@protocol TLPeerConnectionServiceDelegate <TLBaseServiceDelegate>

@optional

- (void)onIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerId:(nonnull NSString *)peerId  offer:(nonnull TLOffer *)offer;

- (void)onTerminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)onCreateLocalVideoTrack:(nonnull RTC_OBJC_TYPE(RTCVideoTrack) *)videoTrack;

- (void)onRemoveLocalVideoTrack;

- (void)onDeviceRinging:(nonnull NSUUID *)peerConnectionId;

@end

@interface TLPeerConnectionDataChannelConfiguration : NSObject

@property (readonly, nonnull) NSString *version;
@property (readonly) BOOL leadingPadding;

- (nonnull instancetype)initWithVersion:(nonnull NSString *)version leadingPadding:(BOOL)leadingPadding;

@end

//
// Interface: TLPeerConnectionDataChannelDelegate
//

@protocol TLPeerConnectionDataChannelDelegate <NSObject>

- (nonnull TLPeerConnectionDataChannelConfiguration *)configurationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId sdpEncryptionStatus:(TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatus;

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding;

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onDataChannelMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId data:(nonnull NSData *)data leadingPadding:(BOOL)leadingPadding;

@end

//
// Interface: TLPeerConnectionService
//

@class RTC_OBJC_TYPE(RTCDataChannelInit);

@interface TLPeerConnectionService:TLBaseService

+ (nonnull NSString *)VERSION;

+ (nonnull NSData *)LEADING_PADDING;

+ (TLPeerConnectionServiceTerminateReason)toTerminateReason:(TLBaseServiceErrorCode)errorCode;

- (BOOL)isAudioVideoEnabled;

- (TLBaseServiceErrorCode)listenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId delegate:(nonnull id<TLPeerConnectionDelegate>)delegate;

- (void)createIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block;

- (void)createIncomingPeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId subject:(nonnull id<TLRepositoryObject>)subject peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block;

- (void)createOutgoingPeerConnectionWithPeerId:(nonnull NSString *)peerId offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent *)notificationContent dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block;

- (void)createOutgoingPeerConnectionWithSubject:(nonnull id<TLRepositoryObject>)subject peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound offer:(nonnull TLOffer *)offer offerToReceive:(nonnull TLOfferToReceive *)offerToReceive notificationContent:(nonnull TLNotificationContent*)notificationContent dataChannelDelegate:(nullable id<TLPeerConnectionDataChannelDelegate>)dataChannelDelegate delegate:(nonnull id<TLPeerConnectionDelegate>)delegate withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, NSUUID *_Nullable peerConnectionId))block;

- (void)initSourcesWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId audioOn:(BOOL)audioOn videoOn:(BOOL)videoOn;

- (void)terminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (nullable TLOffer *)getPeerOfferWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (nullable TLOfferToReceive *)getPeerOfferToReceiveWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (nullable NSString *)getPeerIdWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (BOOL)isTerminatedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

/// Whether the SDPs are encrypted when they are received or sent from the signaling server.
- (TLPeerConnectionServiceSdpEncryptionStatus)sdpEncryptionStatusWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)setAudioDirectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId direction:(RTCRtpTransceiverDirection)direction;

- (void)setVideoDirectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId direction:(RTCRtpTransceiverDirection)direction;

- (void)switchCameraWithFront:(BOOL)front withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode, BOOL isFronCamera))block;

- (void)sendMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId statType:(TLPeerConnectionServiceStatType)statType data:(nonnull NSMutableData *)data;

- (void)sendPacketWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId statType:(TLPeerConnectionServiceStatType)statType iq:(nonnull TLBinaryPacketIQ *)iq;

- (void)incrementStatWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId statType:(TLPeerConnectionServiceStatType)statType;

- (void)sendCallQualityWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId quality:(int)quality;

- (void)sendDeviceRingingWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

/// Return the number of P2P sessions which are created.
- (long)sessionCount;

/// Trigger a session ping on every active P2P connection.
- (void)triggerSessionPing;

@end

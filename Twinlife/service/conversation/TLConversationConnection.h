/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationService.h"
#import "TLPeerConnectionService.h"
#import "TLSerializer.h"
#import "TLBaseServiceImpl.h"

//
// Interface: TLConversationImpl ()
//

typedef enum  {
    TLConversationStateClosed,   // P2P is closed
    TLConversationStateCreating, // PeerConnection is being created
    TLConversationStateOpening,  // PeerConnection is created and is trying to connect
    TLConversationStateOpen      // PeerConnection is now opened.
} TLConversationState;

@class TLGroupConversationImpl;
@class TLDescriptor;
@class TLFileDescriptor;
@class TLSendingFileInfo;
@class TLReceivingFileInfo;
@class TLConversationImpl;
@class TLTwinlife;
@class TLBinaryPacketIQ;
@class TLConversationService;
@class TLSignatureInfoIQ;
@class TLConversationServiceOperation;

/**
 * Device state flag indicating the device is in foreground: we can keep the P2P connection opened.
 */
#define DEVICE_STATE_FOREGROUND     0x01

/**
 * Device state flag indicating the device has some pending operations: we must keep the P2P connection opened.
 */
#define DEVICE_STATE_HAS_OPERATIONS 0x02

/**
 * Device state flag indicating the device is synchronizing its secret keys with the peer.
 */
#define DEVICE_STATE_SYNCHRONIZE_KEYS 0x04

/**
 * Device state flags that we accept from the peer through the OnPush/OnSynchronize IQs.
 */
#define DEVICE_STATE_MASK (DEVICE_STATE_FOREGROUND|DEVICE_STATE_HAS_OPERATIONS|DEVICE_STATE_SYNCHRONIZE_KEYS)

/**
 * Internal device state indicating that the above two flags are valid and come from the peer device.
 */
#define DEVICE_STATE_VALID          0x10

/**
 * On high latency networks it is best to use small chunks for data transfer because we maximize the chance to
 * receive the full chunk and save it.  On low latency networks, sending bigger data chunks provides better performance.
 */
#define NETWORK_HIGH_RTT   1000
#define NETWORK_NORMAL_RTT 500
#define CHUNK_HIGH_RTT     (16 * 1024)
#define CHUNK_NORMAL_RTT   (32 * 1024)
#define CHUNK_LOW_RTT      (64 * 1024)

#define OPENING_TIMEOUT    (30) // 30s

/**
 * The size of a data chunk that we send in a single IQ:
 * - a big size does not help because if we are interrupted in the middle, the whole data chunk is lost,
 * - a small chunk is not good since it triggers more work to handle the data transfer.
 * 32K was a reasonable value but 64K gave good performance results.
 */
#define DATA_CHUNK_SIZE (64 * 1024)

/**
 * The amount of data that we allow to send before getting the peer acknowledgment:
 * - a big data window does not help because we continue sending as soon as we have some acknowledgment,
 * - a small data window is not good because we are waiting for the peer to acknowledge.
 */
#define DATA_WINDOW_SIZE (4 * DATA_CHUNK_SIZE)

static const int CONVERSATION_SERVICE_MAJOR_VERSION_2 = 2;
static const int CONVERSATION_SERVICE_MAJOR_VERSION_1 = 1;

static const int CONVERSATION_SERVICE_MINOR_VERSION_20 = 20;
static const int CONVERSATION_SERVICE_MINOR_VERSION_19 = 19;
static const int CONVERSATION_SERVICE_MINOR_VERSION_18 = 18;
static const int CONVERSATION_SERVICE_MINOR_VERSION_17 = 17;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_16 = 16;
static const int CONVERSATION_SERVICE_MINOR_VERSION_15 = 15;
static const int CONVERSATION_SERVICE_MINOR_VERSION_14 = 14;
static const int CONVERSATION_SERVICE_MINOR_VERSION_13 = 13;
static const int CONVERSATION_SERVICE_MINOR_VERSION_12 = 12;
static const int CONVERSATION_SERVICE_MINOR_VERSION_11 = 11;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_10 = 10;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_9 = 9;
static const int CONVERSATION_SERVICE_MINOR_VERSION_8 = 8;
static const int CONVERSATION_SERVICE_MINOR_VERSION_7 = 7;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_6 = 6;
static const int CONVERSATION_SERVICE_MINOR_VERSION_5 = 5;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_4 = 4;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_2 = 2;
// static const int CONVERSATION_SERVICE_MINOR_VERSION_1 = 1;
static const int CONVERSATION_SERVICE_MINOR_VERSION_0 = 0;

static const int MAX_MAJOR_VERSION = CONVERSATION_SERVICE_MAJOR_VERSION_2;

// The maximum minor number that is supported by the major version 2.
static const int MAX_MINOR_VERSION_2 = CONVERSATION_SERVICE_MINOR_VERSION_20;
static const int MAX_MINOR_VERSION_1 = CONVERSATION_SERVICE_MINOR_VERSION_0;

typedef enum {
    TLAcceptIncomingConversationStateNo,
    TLAcceptIncomingConversationStateYes,
    TLAcceptIncomingConversationStateMaybe
} TLAcceptIncomingConversationState;

@interface TLConversationConnection : NSObject

@property (readonly, nonnull) TLConversationImpl *conversation;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (readonly, nonnull) TLConversationService *conversationService;
@property BOOL withLeadingPadding;

@property int64_t accessedTime;
@property int peerMajorVersion;
@property int peerMinorVersion;
@property BOOL synchronizeKeys;

/*
 * There is a conversation state associated with each direction and we
 * also keep the peer conversation ID in both directions.
 * When one of the state becomes opened, the peerConnectionId is updated
 * to refer to the peer conversation ID that is opened and all the
 * communication operations will use it.
 */
@property TLConversationState incomingState;
@property TLConversationState outgoingState;
@property (nullable) NSUUID *incomingPeerConnectionId;
@property (nullable) NSUUID *outgoingPeerConnectionId;
@property (nullable) NSUUID *peerConnectionId;
@property int64_t startConversationTime;
@property int64_t currentOpeningRequestId;
@property int64_t peerTimeCorrection;
@property int estimatedRTT;
@property int peerDeviceState;
@property (nullable) NSMapTable<TLFileDescriptor *, TLReceivingFileInfo *> *receivingFiles;
@property (nullable) NSMapTable<TLFileDescriptor *, TLSendingFileInfo *> *sendingFiles;
 
- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation twinlife:(nonnull TLTwinlife *)twinlife incoming:(BOOL)incoming;

- (nonnull NSString *)to;

- (nonnull NSString *)from;

- (TLConversationState)state;

- (void)touch;

- (int64_t)idleTime;

- (void)setPeerVersion:(nonnull NSString *)peerVersion;

/// Check if the Peer supports the major, minor version.
- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion;

- (void)startOutgoingConversationWithRequestId:(int64_t)requestId peerConnectionId:(nonnull NSUUID *)peerConnectionId now:(int64_t)now;

/// Returns YES if we can accept an incoming P2P connection.
- (TLAcceptIncomingConversationState)canAcceptIncomingWithTimestamp:(int64_t)now;

/// Returns YES if we can start an outgoing P2P connection.
- (BOOL)canStartOutgoingWithTimestamp:(int64_t)now;

- (nullable NSUUID *)startIncomingConversationWithRequestId:(int64_t)requestId peerConnectionId:(nonnull NSUUID *)peerConnectionId now:(int64_t)now;

- (BOOL)readyForConversationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (BOOL)closeWithPeerConnectionId:(nullable NSUUID *)peerConnectionId isIncoming:(nonnull BOOL *)isIncoming;

- (nonnull TLConversationConnection *)transferConnectionWithConversation:(nonnull TLConversationImpl*)conversation twinlife:(nonnull TLTwinlife *)twinlife;

/// Compute the wall clock adjustment between the peer and our local clock.
/// This time correction is applied to times that we received from that peer.
/// We continue to send our times not-adjusted: the peer will do its own correction.
///
/// The algorithm is inspired from NTP but it is simplified:
/// - we compute the RTT between the two devices,
/// - we compute the time difference between the two devices,
/// - the difference is corrected by RTT/2.
- (void)adjustTimeWithPeerTime:(int64_t)peerTime startTime:(int64_t)startTime;

/// Compute the adjusted timestamp to convert the peer time into our local timestamp.
- (int64_t)adjustedTimeWithTimestamp:(int64_t)timestamp;

/// During a file transfer, update the estimated RTT to adjust the data chunk size.
- (void)updateEstimatedRttWithTimestamp:(int64_t)timestamp;

/// Cancel sending or receiving the file.
- (void)cancelWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor;

/// Read the next data chunk to be sent for the file.
- (nullable NSData *)readChunkWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor chunkStart:(int64_t)chunkStart chunkSize:(int)chunkSize;

/// Write the data chunk on the given file.
- (int64_t)writeChunkWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor chunkStart:(int64_t)chunkStart chunk:(nullable NSData *)chunk;

/// Returns YES if we have some file transfer in progress.
- (BOOL)isTransferingFile;

/// Get the best data chunk size for communicating with the peer.
- (int)bestChunkSize;

- (int)getMaxPeerMajorVersion;

- (int)getMaxPeerMinorVersionWithMajorVersion:(int)majorVersion;

- (void)sendPacketWithStatType:(TLPeerConnectionServiceStatType)statType iq:(nonnull TLBinaryPacketIQ *)iq;

- (void)sendMessageWithStatType:(TLPeerConnectionServiceStatType)statType data:(nonnull NSMutableData *)data;

- (BOOL)preparePushWithDescriptor:(nullable TLDescriptor*)descriptor;

- (TLBaseServiceErrorCode)operationNotSupportedWithConnection:(nonnull TLConversationConnection*)connection descriptor:(nonnull TLDescriptor *)descriptor;

- (TLBaseServiceErrorCode)deleteFileDescriptorWithConnection:(nonnull TLConversationConnection*)connection fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor operation:(nonnull TLConversationServiceOperation *)operation;

- (nullable TLDescriptor *)loadDescriptorWithId:(int64_t)descriptorId;

- (void)updateDescriptorTimestamps:(nonnull TLDescriptor *)descriptor;

- (nullable TLSignatureInfoIQ *)createSignatureWithConnection:(nonnull TLConversationConnection *)connection groupTwincodeId:(nonnull NSUUID *)groupTwincodeId;

@end

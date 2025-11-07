/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLConversationImpl.h"
#import "TLTwincodeInboundService.h"
#import "TLTwincodeOutboundService.h"
#import "TLRepositoryService.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLConversationServiceImpl.h"
#import "TLGroupConversationImpl.h"
#import "TLConversationConnection.h"
#import "TLConversationServiceImpl.h"
#import "TLConversationServiceProvider.h"
#import "TLConversationServiceScheduler.h"
#import "TLCryptoServiceImpl.h"
#import "TLUpdateDescriptorTimestampOperation.h"
#import "TLTwinlifeImpl.h"
#import "TLFileDescriptorImpl.h"
#import "TLSendingFileInfo.h"
#import "TLReceivingFileInfo.h"
#import "TLFileInfo.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static const int64_t MAX_ADJUST_TIME = 3600 * 1000; // Absolute maximum wallclock time adjustment in ms made.

//
// Implementation: TLConversationConnection
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationConnection"

@implementation TLConversationConnection

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation twinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithConversation: %@ twinlife: %@", LOG_TAG, conversation, twinlife);

    self = [super init];
    if (self) {
        _conversation = conversation;
        _serializerFactory = twinlife.serializerFactory;
        _peerConnectionService = [twinlife getPeerConnectionService];
        _conversationService = [twinlife getConversationService];
        _withLeadingPadding = YES;
    }
    return self;
}

- (int)getMaxPeerMajorVersion {
    DDLogVerbose(@"%@ getMaxPeerMajorVersion", LOG_TAG);
    
    return MIN(self.peerMajorVersion, MAX_MAJOR_VERSION);
}

- (int)getMaxPeerMinorVersionWithMajorVersion:(int)majorVersion {
    DDLogVerbose(@"%@ getMaxPeerMinorVersionWithMajorVersion: %d", LOG_TAG, majorVersion);
    
    if (majorVersion >= CONVERSATION_SERVICE_MAJOR_VERSION_2) {
        int min = MIN(self.peerMinorVersion, MAX_MINOR_VERSION_2);

        // Version 2.1..2.7 have a bug where the reply IQ indicates a major+minor that comes from the conversation
        // peer version, which means that a response can contain a 2.15 while the request contained 2.5.
        // Version 2.13 introduced a bug where a SET IQ with version 2.13 is not handled but the peer
        // which returns an error IQ (the MAX_MINOR_VERSION_2 was incorrectly set to 12 when it should be 13).
        // Version 2.14 and 2.15 introduced another bug where a response IQ with a minor 14 or 15 where ignored
        // and generate a problem report if we communicate with a ConversationService <= 2.7
        // Downgrade to 2.12 to avoid falling in these bugs.  Note: it is OK to use the 2.12 version if we use binary IQ.
        if (min >= CONVERSATION_SERVICE_MINOR_VERSION_13 && min <= CONVERSATION_SERVICE_MINOR_VERSION_15 && majorVersion == CONVERSATION_SERVICE_MAJOR_VERSION_2) {
            min = CONVERSATION_SERVICE_MINOR_VERSION_12;
        }
        return min;
    }
    
    return MIN(self.peerMinorVersion, MAX_MINOR_VERSION_1);
}

- (BOOL)preparePushWithDescriptor:(nullable TLDescriptor*)descriptor {
    DDLogVerbose(@"%@ preparePushWithDescriptor: %@", LOG_TAG, descriptor);

    if ([descriptor isExpired] || descriptor.deletedTimestamp > 0) {
        return NO;
    }
    if (descriptor.sentTimestamp <= 0) {
        descriptor.sentTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        [self.conversationService.serviceProvider updateDescriptorTimestamps:descriptor];
    }

    return YES;
}

- (TLBaseServiceErrorCode)operationNotSupportedWithConnection:(nonnull TLConversationConnection*)connection descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ operationNotSupportedWithConnection: %@", LOG_TAG, descriptor);

    if (descriptor) {
        descriptor.sentTimestamp = -1;
        descriptor.receivedTimestamp = -1;
        descriptor.readTimestamp = -1;
        [self.conversationService updateWithDescriptor:descriptor conversation:self.conversation];
    }
    [self.conversationService onErrorWithRequestId:[TLBaseService DEFAULT_REQUEST_ID] errorCode:TLBaseServiceErrorCodeFeatureNotSupportedByPeer errorParameter:[self.conversation.uuid UUIDString]];

    return TLBaseServiceErrorCodeFeatureNotSupportedByPeer;
}

- (TLBaseServiceErrorCode)deleteFileDescriptorWithConnection:(nonnull TLConversationConnection*)connection fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor operation:(nonnull TLConversationServiceOperation *)operation {
    
    [self.conversationService.scheduler removeOperation:operation];

    // File was removed, send a delete descriptor operation.
    TLConversationImpl *conversationImpl = connection.conversation;
    TLUpdateDescriptorTimestampOperation *updateDescriptorTimestampOperation = [[TLUpdateDescriptorTimestampOperation alloc] initWithConversation:conversationImpl timestampType:TLUpdateDescriptorTimestampTypeDelete descriptorId:fileDescriptor.descriptorId timestamp:fileDescriptor.deletedTimestamp];
    [self.conversationService.serviceProvider storeOperation:updateDescriptorTimestampOperation];
    [self.conversationService.scheduler addOperation:updateDescriptorTimestampOperation conversation:conversationImpl];
    return TLBaseServiceErrorCodeQueued;
}

- (nullable TLSignatureInfoIQ *)createSignatureWithConnection:(nonnull TLConversationConnection *)connection groupTwincodeId:(nonnull NSUUID *)groupTwincodeId {
    DDLogVerbose(@"%@ createSignatureWithConnection: %@ groupTwincodeId: %@", LOG_TAG, connection, groupTwincodeId);

    TLGroupConversationImpl *groupConversation = [self.conversationService.serviceProvider findGroupWithTwincodeId:groupTwincodeId];
    TLTwincodeOutbound *memberTwincode = groupConversation ? groupConversation.subject.twincodeOutbound : nil;
    TLTwincodeOutbound *peerTwincode = connection.conversation.peerTwincodeOutbound;
    return memberTwincode && peerTwincode ? [[self.conversationService.twinlife getCryptoService] getSignatureInfoIQWithTwincode:memberTwincode peerTwincode:peerTwincode renew:NO] : nil;
}

- (nullable TLDescriptor *)loadDescriptorWithId:(int64_t)descriptorId {
    
    return [self.conversationService.serviceProvider loadDescriptorWithId:descriptorId];
}

- (void)updateDescriptorTimestamps:(nonnull TLDescriptor *)descriptor {
    
    [self.conversationService.serviceProvider updateDescriptorTimestamps:descriptor];
}

#pragma - mark PeerConnection

- (BOOL)canStartOutgoingWithTimestamp:(int64_t)now {
    DDLogVerbose(@"%@ canStartOutgoingWithTimestamp %lld", LOG_TAG, now);

    if (self.outgoingState != TLConversationStateClosed) {
        return NO;
    }

    // We must not have an incoming P2P connection active or being setup.
    // (except if that incoming P2P is older than 30s)
    switch (self.incomingState) {
        case TLConversationStateOpen:
            return NO;
            
        case TLConversationStateOpening:
            if (self.startConversationTime + OPENING_TIMEOUT * MSEC_PER_SEC > now) {
                return NO;
            }
            // Fallback to creating state.

        case TLConversationStateClosed:
        default:
            self.outgoingState = TLConversationStateCreating;
            return YES;
    }
}

- (void)startOutgoingConversationWithRequestId:(int64_t)requestId peerConnectionId:(nonnull NSUUID *)peerConnectionId now:(int64_t)now {
    DDLogVerbose(@"%@ startOutgoingConversationWithRequestId %lld peerConnectionId: %@", LOG_TAG, requestId, peerConnectionId);
    
    self.outgoingState = TLConversationStateOpening;
    self.outgoingPeerConnectionId = peerConnectionId;
    self.currentOpeningRequestId = requestId;
    self.startConversationTime = now;
}

- (TLAcceptIncomingConversationState)canAcceptIncomingWithTimestamp:(int64_t)now {
    DDLogVerbose(@"%@ canAcceptIncomingWithTimestamp %lld", LOG_TAG, now);
    
    // If one of the IN/OUT connection is opened, we are busy.
    if (self.outgoingState == TLConversationStateOpen || self.outgoingState == TLConversationStateCreating
        || self.incomingState == TLConversationStateOpen || self.incomingState == TLConversationStateCreating) {
        return TLAcceptIncomingConversationStateNo;
    }
    
    // IN and OUT are not opened and they were created more than 20s ago, they are dead.
    if (self.startConversationTime + OPENING_TIMEOUT * MSEC_PER_SEC < now || self.outgoingState == TLConversationStateClosed) {
        self.incomingState = TLConversationStateCreating;
        return TLAcceptIncomingConversationStateYes;
    }

    return TLAcceptIncomingConversationStateMaybe;
}

- (nullable NSUUID *)startIncomingConversationWithRequestId:(int64_t)requestId peerConnectionId:(nonnull NSUUID *)peerConnectionId now:(int64_t)now {
    DDLogVerbose(@"%@ startIncomingConversationWithRequestId %lld peerConnectionId: %@", LOG_TAG, requestId, peerConnectionId);
    
    NSUUID *result = self.incomingPeerConnectionId;
    self.incomingState = TLConversationStateCreating;
    self.incomingPeerConnectionId = peerConnectionId;
    self.currentOpeningRequestId = requestId;
    self.startConversationTime = now;
    return result;
}

- (BOOL)readyForConversationWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {
    DDLogVerbose(@"%@ readyForConversationWithPeerConnectionId: %@", LOG_TAG, peerConnectionId);

    if ([peerConnectionId isEqual:self.incomingPeerConnectionId]) {
        self.incomingState = TLConversationStateOpen;

    } else if ([peerConnectionId isEqual:self.outgoingPeerConnectionId]) {
        self.outgoingState = TLConversationStateOpen;

    } else {
        return NO;
    }

    // Setup the first access time.
    self.accessedTime = [[NSDate date] timeIntervalSince1970] * 1000;
    self.peerConnectionId = peerConnectionId;
    self.peerDeviceState = 0;
    self.peerTimeCorrection = 0;

    if (ddLogLevel & DDLogFlagInfo) {
        int64_t delta = self.accessedTime - self.startConversationTime;

        DDLogInfo(@"%@ P2P conversation established in %llu ms", LOG_TAG, delta);
    }
    return YES;
}

- (BOOL)closeWithPeerConnectionId:(nullable NSUUID *)peerConnectionId isIncoming:(nonnull BOOL *)isIncoming {
    DDLogVerbose(@"%@ closeWithPeerConnectionId: %@ isIncoming: %d", LOG_TAG, peerConnectionId, *isIncoming);
    
    if (!peerConnectionId) {
        // Creation of PeerConnection failed.
        if (*isIncoming) {
            self.incomingState = TLConversationStateClosed;
        } else {
            self.outgoingState = TLConversationStateClosed;
        }
    } else if ([peerConnectionId isEqual:self.incomingPeerConnectionId]) {
        self.incomingState = TLConversationStateClosed;
        self.incomingPeerConnectionId = nil;
        *isIncoming = YES;
    } else if ([peerConnectionId isEqual:self.outgoingPeerConnectionId]) {
        self.outgoingState = TLConversationStateClosed;
        self.outgoingPeerConnectionId = nil;
        *isIncoming = NO;
    }
    if (self.incomingState != TLConversationStateClosed || self.outgoingState != TLConversationStateClosed) {
        return NO;
    }

    self.peerDeviceState = 0;
    self.peerConnectionId = nil;
    self.startConversationTime = 0;
    [self.conversation closeConnection];
    return YES;
}

- (nonnull TLConversationConnection *)transferConnectionWithConversation:(nonnull TLConversationImpl*)conversation twinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ transferConnectionWithConversation: %@", LOG_TAG, conversation);

    TLConversationConnection *result = [[TLConversationConnection alloc] initWithConversation:conversation twinlife:twinlife];
    result.incomingState = self.incomingState;
    result.outgoingState = self.outgoingState;
    result.accessedTime = self.accessedTime;
    result.incomingPeerConnectionId = self.incomingPeerConnectionId;
    result.peerConnectionId = self.peerConnectionId;
    result.peerMajorVersion = self.peerMajorVersion;
    result.peerMinorVersion = self.peerMinorVersion;
    result.peerTimeCorrection = self.peerTimeCorrection;
    result.peerDeviceState = self.peerDeviceState;
    result.withLeadingPadding = self.withLeadingPadding;
    
    self.incomingState = TLConversationStateClosed;
    self.outgoingState = TLConversationStateClosed;
    self.incomingPeerConnectionId = nil;
    self.peerConnectionId = nil;
    self.currentOpeningRequestId = 0;
    return result;
}

- (NSString *)to {
    
    return [self.conversation to];
}

- (nonnull NSString *)from {

    return [self.conversation from];
}

- (void)touch {
    
    self.accessedTime = [[NSDate date] timeIntervalSince1970] * 1000;
}

- (TLConversationState)state {
    
    if (self.incomingState == TLConversationStateClosed && self.outgoingState != TLConversationStateClosed) {
        return self.outgoingState;
    } else {
        return self.incomingState;
    }
}

- (int64_t)idleTime {
    
    return [[NSDate date] timeIntervalSince1970] * 1000 - self.accessedTime;
}

- (void)setPeerVersion:(NSString *)peerVersion {
    
    if (peerVersion) {
        NSString *value = peerVersion;
        NSRange range = [value rangeOfString:@"."];
        if (range.location != NSNotFound) {
            NSUInteger index = range.location;
            if (index > 0) {
                self.peerMajorVersion = [[value substringWithRange:NSMakeRange(0, index)] intValue];
                value = [value substringFromIndex:index + 1];
                range = [value rangeOfString:@"."];
                if (range.location != NSNotFound) {
                    index = range.location;
                    if (index > 0) {
                        self.peerMinorVersion = [[value substringWithRange:NSMakeRange(0, index)] intValue];
                    }
                }
            }
        }
    }
}

- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    if (self.peerMajorVersion < majorVersion) {
        return NO;
    }
    
    if (self.peerMajorVersion > majorVersion) {
        return YES;
    }
    
    return self.peerMinorVersion >= minorVersion;
}

- (void)adjustTimeWithPeerTime:(int64_t)peerTime startTime:(int64_t)startTime {

    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;

    // Compute the propagation time: RTT (ignore excessive values).
    int64_t tp = (now - startTime);
    if (tp < 0 || tp > 60000) {
        return;
    }

    // Compute the time correction.
    int64_t tc = (peerTime - (startTime + (tp / 2)));
    if (tc > MAX_ADJUST_TIME) {
        tc = MAX_ADJUST_TIME;
    } else if (tc < -MAX_ADJUST_TIME) {
        tc = -MAX_ADJUST_TIME;
    }

    self.peerTimeCorrection = -tc;
    self.estimatedRTT = (int)tp;
}

- (void)updateEstimatedRttWithTimestamp:(int64_t)timestamp {
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;

    // Compute the propagation time: RTT (ignore excessive values).
    int64_t tp = (now - timestamp);
    if (tp < 0 || tp > 60000) {
        return;
    }

    // Compute mean with previous RTT.
    self.estimatedRTT = (self.estimatedRTT + (int)tp) / 2;
}

- (int64_t)adjustedTimeWithTimestamp:(int64_t)timestamp {
    
    if (timestamp <= 0) {
        return timestamp;
    } else {
        return timestamp + self.peerTimeCorrection;
    }
}

- (void)cancelWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor {
    DDLogVerbose(@"%@ cancelWithFileDescriptor: %@", LOG_TAG, fileDescriptor);

    if (self.sendingFiles) {
        TLSendingFileInfo *sendingFile = [self.sendingFiles objectForKey:fileDescriptor];
        if (sendingFile) {
            [sendingFile cancel];
            [self.sendingFiles removeObjectForKey:fileDescriptor];
        }
    }

    if (self.receivingFiles) {
        TLReceivingFileInfo *receivingFile = [self.receivingFiles objectForKey:fileDescriptor];
        if (receivingFile) {
            [receivingFile cancel];
            [self.receivingFiles removeObjectForKey:fileDescriptor];
        }
    }
}

- (nullable NSData *)readChunkWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor chunkStart:(int64_t)chunkStart chunkSize:(int)chunkSize {
    DDLogVerbose(@"%@ readChunkWithFileDescriptor: %@ chunkStart: %lld chunkSize: %d", LOG_TAG, fileDescriptor, chunkStart, chunkSize);

    if (!self.sendingFiles) {
        self.sendingFiles = [NSMapTable strongToStrongObjectsMapTable];
    }

    TLSendingFileInfo *sendingFile = [self.sendingFiles objectForKey:fileDescriptor];
    @try {
        if (!sendingFile) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *path = [fileDescriptor getPathWithFileManager:fileManager];
            
            TLFileInfo *fileInfo = [[TLFileInfo alloc] initWithFileId:1 path:path size:fileDescriptor.length date:0];
            
            sendingFile = [[TLSendingFileInfo alloc] initWithPath:path fileInfo:fileInfo];
            [self.sendingFiles setObject:sendingFile forKey:fileDescriptor];
        }

        return [sendingFile readChunkWithSize:chunkSize position:chunkStart];

    } @catch(NSException *lException) {
        [self cancelWithFileDescriptor:fileDescriptor];
        return nil;
    }
}

- (int64_t)writeChunkWithFileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor chunkStart:(int64_t)chunkStart chunk:(nullable NSData *)chunk {
    DDLogVerbose(@"%@ writeChunkWithFileDescriptor: %@ chunkStart: %lld", LOG_TAG, fileDescriptor, chunkStart);

    if (!self.receivingFiles) {
        self.receivingFiles = [NSMapTable strongToStrongObjectsMapTable];
    }

    TLReceivingFileInfo *receivingFile = [self.receivingFiles objectForKey:fileDescriptor];
    @try {
        if (!receivingFile) {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *path = [fileDescriptor getPathWithFileManager:fileManager];
            receivingFile = [[TLReceivingFileInfo alloc] initWithPath:path];
            [self.receivingFiles setObject:receivingFile forKey:fileDescriptor];

            if (!chunk) {
                [receivingFile seekToFileOffset:LONG_MAX];
                return [receivingFile position];
            } else {
                [receivingFile seekToFileOffset:chunkStart];
            }
        }

        if (!chunk) {
            return [receivingFile length];
        }

        int64_t position = [receivingFile writeChunkWithData:chunk];
        if (position == [fileDescriptor length]) {
            [receivingFile close];
            [self.receivingFiles removeObjectForKey:fileDescriptor];
        }

        return position;
    } @catch(NSException *lException) {
        [self cancelWithFileDescriptor:fileDescriptor];
        return -1L;
    }
}

- (BOOL)isTransferingFile {
    DDLogVerbose(@"%@ isTransferingFile", LOG_TAG);

    if (self.receivingFiles && self.receivingFiles.count > 0) {
        return YES;
    }
    if (self.sendingFiles && self.sendingFiles.count > 0) {
        return YES;
    }
    return NO;
}

- (int)bestChunkSize {
    DDLogVerbose(@"%@ bestChunkSize", LOG_TAG);

    if (self.estimatedRTT > NETWORK_HIGH_RTT) {
        return CHUNK_HIGH_RTT;
    }
    if (self.estimatedRTT > NETWORK_NORMAL_RTT) {
        return CHUNK_NORMAL_RTT;
    }
    return CHUNK_LOW_RTT;
}

- (void)sendPacketWithStatType:(TLPeerConnectionServiceStatType)statType iq:(nonnull TLBinaryPacketIQ *)iq {
    DDLogVerbose(@"%@ sendPacketWithStatType: %d iq: %@", LOG_TAG, statType, iq);

    [self.peerConnectionService sendPacketWithPeerConnectionId:self.peerConnectionId statType:statType iq:iq];
}

- (void)sendMessageWithStatType:(TLPeerConnectionServiceStatType)statType data:(nonnull NSMutableData *)data {
    DDLogVerbose(@"%@ sendMessageWithStatType: %d iq: %@", LOG_TAG, statType, data);

    [self.peerConnectionService sendMessageWithPeerConnectionId:self.peerConnectionId statType:statType data:data];
}

#pragma - mark NSObject

- (BOOL)isEqual:(nullable id)object {
    
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLConversationConnection class]]) {
        return NO;
    }
    TLConversationConnection* connection = (TLConversationConnection *)object;
    return [self.conversation isEqual:connection.conversation];
}

- (NSUInteger)hash {

    return [self.conversation hash];
}

- (void)appendTo:(nonnull NSMutableString*)string {
    
    [string appendFormat:@" accessedTime: %lld", self.accessedTime];
    [string appendFormat:@" startConversationTime: %lld", self.startConversationTime];
    [string appendFormat:@" peerMajorVersion: %d", self.peerMajorVersion];
    [string appendFormat:@" peerMinorVersion: %d\n", self.peerMinorVersion];
    [string appendFormat:@" incomingState: %u", self.incomingState];
    [string appendFormat:@" outgoingState: %u", self.outgoingState];
    [string appendFormat:@" incomingPeerConnectionId: %@", [self.incomingPeerConnectionId UUIDString]];
    [string appendFormat:@" outgoingPeerConnectionId: %@", [self.outgoingPeerConnectionId UUIDString]];
    [string appendFormat:@" peerConnectionId: %@", [self.peerConnectionId UUIDString]];
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversation["];
    [self appendTo:string];
    [string appendString:@"]"];
    return string;
}

@end

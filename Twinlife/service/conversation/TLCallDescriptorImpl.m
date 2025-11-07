/*
 *  Copyright (c) 2020-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLCallDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2020/01/24
 *
 * {
 *  "schemaId":"ca15db2f-beda-40a3-84d9-7c3fee25dc5d",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"CallDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"video", "type":"boolean"]},
 *   {"name":"incoming", "type":"boolean"},
 *   {"name":"accepted", "type":"boolean"},
 *   {"name":"duration", "type":"long"},
 *   {"name":"terminateReason", "type": ["null", "busy", "cancel", "connectivity_error", "decline", "disconnected",
 *       "general_error", "gone", "not_authorized", "success", "revoked", "timeout", "unkown"]}
 *  ]
 * }
 * </pre>
 */

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLCallDescriptor
//

@interface TLCallDescriptor ()

@property BOOL isCallTerminated;
@property BOOL isCallAccepted;
@property int64_t callDuration;
@property TLPeerConnectionServiceTerminateReason callTerminateReason;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor video:(BOOL)video incomingCall:(BOOL)incomingCall acceptedCall:(BOOL)acceptedCall duration:(int64_t)duration isTerminated:(BOOL)isTerminated terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

@end

//
// Implementation: TLCallDescriptorSerializer_1
//

static NSUUID *CALL_DESCRIPTOR_SCHEMA_ID = nil;
static const int CALL_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLSerializer *CALL_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLCallDescriptorSerializer_1"

@implementation TLCallDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLCallDescriptor.SCHEMA_ID schemaVersion:TLCallDescriptor.SCHEMA_VERSION_1 class:[TLCallDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(nonnull NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLCallDescriptor *callDescriptor = (TLCallDescriptor *)object;
    [encoder writeBoolean:callDescriptor.isVideo];
    [encoder writeBoolean:callDescriptor.isIncoming];
    [encoder writeBoolean:callDescriptor.isCallAccepted];
    [encoder writeLong:callDescriptor.callDuration];
    if (!callDescriptor.isCallTerminated) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:[TLCallDescriptor fromTerminateReason:callDescriptor.callTerminateReason]];
    }
}

- (nullable NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    BOOL video = [decoder readBoolean];
    BOOL incomingCall = [decoder readBoolean];
    BOOL acceptedCall = [decoder readBoolean];
    BOOL isTerminated = YES;
    int64_t duration = [decoder readLong];
    TLPeerConnectionServiceTerminateReason terminateReason;

    int value = [decoder readEnum];
    if (value == 0) {
        isTerminated = NO;
        terminateReason = TLPeerConnectionServiceTerminateReasonUnknown;
    } else {
        terminateReason = [TLCallDescriptor toTerminateReason:value];
    }

    return [[TLCallDescriptor alloc] initWithDescriptor:descriptor video:video incomingCall:incomingCall acceptedCall:acceptedCall duration:duration isTerminated:isTerminated terminateReason:terminateReason];
}

@end

//
// Implementation: TLCallDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLCallDescriptor"

@implementation TLCallDescriptor

+ (void)initialize {
    
    CALL_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"ca15db2f-beda-40a3-84d9-7c3fee25dc5d"];
    CALL_DESCRIPTOR_SERIALIZER_1 = [[TLCallDescriptorSerializer_1 alloc] init];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return CALL_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_1 {
    
    return CALL_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (nonnull TLSerializer *)SERIALIZER_1 {
    
    return CALL_DESCRIPTOR_SERIALIZER_1;
}

+ (TLPeerConnectionServiceTerminateReason)toTerminateReason:(int)value {
    switch (value) {
        case 0:
            return TLPeerConnectionServiceTerminateReasonUnknown;
        case 1:
            return TLPeerConnectionServiceTerminateReasonBusy;
        case 2:
            return TLPeerConnectionServiceTerminateReasonCancel;
        case 3:
            return TLPeerConnectionServiceTerminateReasonConnectivityError;
        case 4:
            return TLPeerConnectionServiceTerminateReasonCancel;
        case 5:
            return TLPeerConnectionServiceTerminateReasonDisconnected;
        case 6:
            return TLPeerConnectionServiceTerminateReasonGeneralError;
        case 7:
            return TLPeerConnectionServiceTerminateReasonGone;
        case 8:
            return TLPeerConnectionServiceTerminateReasonNotAuthorized;
        case 9:
            return TLPeerConnectionServiceTerminateReasonSuccess;
        case 10:
            return TLPeerConnectionServiceTerminateReasonRevoked;
        case 11:
            return TLPeerConnectionServiceTerminateReasonTimeout;
        case 12:
            return TLPeerConnectionServiceTerminateReasonUnknown;
        case 13:
            return TLPeerConnectionServiceTerminateReasonTransferDone;
        case 14:
            return TLPeerConnectionServiceTerminateReasonSchedule;
        case 15:
            return TLPeerConnectionServiceTerminateReasonMerge;
        case 16:
            return TLPeerConnectionServiceTerminateReasonNoPrivateKey;
        case 17:
            return TLPeerConnectionServiceTerminateReasonNoSecretKey;
        case 18:
            return TLPeerConnectionServiceTerminateReasonDecryptError;
        case 19:
            return TLPeerConnectionServiceTerminateReasonEncryptError;
        default:
            return TLPeerConnectionServiceTerminateReasonUnknown;
    }
}

+ (int)fromTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    switch (terminateReason) {
        case TLPeerConnectionServiceTerminateReasonBusy:
            return 1;
        case TLPeerConnectionServiceTerminateReasonCancel:
            return 2;
        case TLPeerConnectionServiceTerminateReasonConnectivityError:
            return 3;
        case TLPeerConnectionServiceTerminateReasonDecline:
            return 4;
        case TLPeerConnectionServiceTerminateReasonDisconnected:
            return 5;
        case TLPeerConnectionServiceTerminateReasonGeneralError:
            return 6;
        case TLPeerConnectionServiceTerminateReasonGone:
            return 7;
        case TLPeerConnectionServiceTerminateReasonNotAuthorized:
            return 8;
        case TLPeerConnectionServiceTerminateReasonSuccess:
            return 9;
        case TLPeerConnectionServiceTerminateReasonRevoked:
            return 10;
        case TLPeerConnectionServiceTerminateReasonTimeout:
            return 11;
        case TLPeerConnectionServiceTerminateReasonUnknown:
            return 12;
        case TLPeerConnectionServiceTerminateReasonTransferDone:
            return 13;
        case TLPeerConnectionServiceTerminateReasonSchedule:
            return 14;
        case TLPeerConnectionServiceTerminateReasonMerge:
            return 15;
        case TLPeerConnectionServiceTerminateReasonNoPrivateKey:
            return 16;
        case TLPeerConnectionServiceTerminateReasonNoSecretKey:
            return 17;
        case TLPeerConnectionServiceTerminateReasonEncryptError:
            return 18;
        case TLPeerConnectionServiceTerminateReasonDecryptError:
            return 19;
        default:
            return 0;
    }
}

#pragma mark - NSObject

- (nonnull NSString *)description {
    
    NSMutableString *string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLCallDescriptor\n"];
    [self appendTo:string];
    [string appendFormat:@" video:          %d\n", self.isVideo];
    [string appendFormat:@" incomingCall:   %d\n", self.isIncoming];
    [string appendFormat:@" acceptedCall:   %d\n", self.isCallAccepted];
    [string appendFormat:@" terminatedCall: %d\n", self.isCallTerminated];
    [string appendFormat:@" terminatReason: %d@\n", self.terminateReason];
    [string appendFormat:@" duration:       %lld\n", self.callDuration];
    return string;
}

#pragma mark - TLDescriptor ()

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeCallDescriptor;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
}

- (int)flags {
    int result = self.isVideo ? DESCRIPTOR_FLAG_VIDEO : 0;
    result |= self.isIncoming ? DESCRIPTOR_FLAG_INCOMING_CALL : 0;
    result |= self.isCallAccepted ? DESCRIPTOR_FLAG_ACCEPTED_CALL : 0;
    
    return result;
}

- (int64_t)value {
    
    return self.duration;
}

#pragma mark - TLCallDescriptor ()

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId video:(BOOL)video incomingCall:(BOOL)incomingCall {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld video: %d incomingCall: %d", LOG_TAG, descriptorId, conversationId, video, incomingCall);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil expireTimeout:0];
    
    if (self) {
        _isVideo = video;
        _isIncoming = incomingCall;
        _callDuration = 0;
        _isCallTerminated = NO;
        _isCallAccepted = NO;
        _callTerminateReason = TLPeerConnectionServiceTerminateReasonUnknown;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor video:(BOOL)video incomingCall:(BOOL)incomingCall acceptedCall:(BOOL)acceptedCall duration:(int64_t)duration isTerminated:(BOOL)isTerminated terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    DDLogVerbose(@"%@ initWithinitWithDescriptor: %@ video: %d incomingCall: %d acceptedCall: %d duration: %lld isTerminated: %d terminateReason: %d", LOG_TAG, descriptor, video, incomingCall, acceptedCall, duration, isTerminated, terminateReason);
    
    self = [super initWithDescriptor:descriptor];
    
    if (self) {
        _isVideo = video;
        _isIncoming = incomingCall;
        _callDuration = duration;
        _isCallTerminated = isTerminated;
        _isCallAccepted = acceptedCall;
        _callTerminateReason = terminateReason;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content duration:(int64_t)duration {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@", LOG_TAG, descriptorId, conversationId, creationDate, flags, content);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    if(self) {
        NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];

        int value = (int) [TLDescriptor extractLongWithArgs:args position:0 defaultValue:0];
        if (value == 0) {
            _callTerminateReason = TLPeerConnectionServiceTerminateReasonUnknown;
            _isCallTerminated = NO;
        } else {
            _callTerminateReason = [TLCallDescriptor toTerminateReason:value];
            _isCallTerminated = YES;
        }
        _callDuration = duration;
        _isVideo = (flags & DESCRIPTOR_FLAG_VIDEO) != 0;
        _isIncoming = (flags & DESCRIPTOR_FLAG_INCOMING_CALL) != 0;
        _isCallAccepted = (flags & DESCRIPTOR_FLAG_ACCEPTED_CALL) != 0;
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    if (!self.isCallTerminated) {
        return @"0";
    }
    int value = [TLCallDescriptor fromTerminateReason:self.callTerminateReason];
    return [NSString stringWithFormat:@"%d", value];
}

- (BOOL)isAccepted {
    
    return self.isCallAccepted;
}

- (BOOL)isTerminated {
    
    return self.isCallTerminated;
}

- (long)duration {

    return (long) self.callDuration;
}

- (TLPeerConnectionServiceTerminateReason)terminateReason {
    
    return self.callTerminateReason;
}

- (void) setAccepted {
    
    self.isCallAccepted = YES;
    self.readTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
}

- (void) setTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    
    self.isCallTerminated = YES;
    self.callTerminateReason = terminateReason;

    if (self.readTimestamp > 0) {
        self.callDuration = [[NSDate date] timeIntervalSince1970] * 1000 - self.readTimestamp;
    } else {
        self.callDuration = 0;
    }
}

@end

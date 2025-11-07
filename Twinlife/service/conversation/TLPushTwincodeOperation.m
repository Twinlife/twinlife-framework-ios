/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLPushTwincodeOperation.h"
#import "TLPushTwincodeIQ.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLPushTwincodeOperation"

//
// Implementation: TLPushTwincodeOperationSerializer
//

static NSUUID *PUSH_TWINCODE_OPERATION_SCHEMA_ID = nil;
static int PUSH_TWINCODE_OPERATION_SCHEMA_VERSION = 1;

//
// Implementation: TLPushTwincodeOperation
//

@implementation TLPushTwincodeOperation

+ (void)initialize {
    
    PUSH_TWINCODE_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"c8ac4c45-525c-44d4-bf44-f542c9928a7a"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return PUSH_TWINCODE_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_TWINCODE_OPERATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation twincodeDescriptor:(nonnull TLTwincodeDescriptor *)twincodeDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushTwincode descriptor:twincodeDescriptor];
    if (self) {
        _twincodeDescriptor = twincodeDescriptor;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {
    
    return [super initWithId:id type:TLConversationServiceOperationTypePushTwincode conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLTwincodeDescriptor *twincodeDescriptor = self.twincodeDescriptor;
    if (!twincodeDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLTwincodeDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        twincodeDescriptor = (TLTwincodeDescriptor *)descriptor;
        self.twincodeDescriptor = twincodeDescriptor;
    }
    if (![connection preparePushWithDescriptor:twincodeDescriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];

    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_18]) {
        TLPushTwincodeIQ *pushTwincodeIQ = [[TLPushTwincodeIQ alloc] initWithSerializer:[TLPushTwincodeIQ SERIALIZER_3] requestId:requestId twincodeDescriptor:twincodeDescriptor];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushTwincode iq:pushTwincodeIQ];
        return TLBaseServiceErrorCodeQueued;

    } else if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_12]) {
        TLPushTwincodeIQ *pushTwincodeIQ = [[TLPushTwincodeIQ alloc] initWithSerializer:[TLPushTwincodeIQ SERIALIZER_2] requestId:requestId twincodeDescriptor:twincodeDescriptor];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushTwincode iq:pushTwincodeIQ];
        return TLBaseServiceErrorCodeQueued;

    } else if (!twincodeDescriptor.sendTo && !twincodeDescriptor.replyTo && twincodeDescriptor.expireTimeout == 0) {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
    
        TLConversationServicePushTwincodeIQ *pushTwincodeIQ = [[TLConversationServicePushTwincodeIQ alloc] initWithFrom:connection.from to:connection.to requestId:[TLTwinlife newRequestId] majorVersion:majorVersion minorVersion:minorVersion twincodeDescriptor:twincodeDescriptor];
    
        NSMutableData *data = [pushTwincodeIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetPushTwincode data:data];
        return TLBaseServiceErrorCodeQueued;

    } else {
        return [connection operationNotSupportedWithConnection:connection descriptor:twincodeDescriptor];
    }
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushTwincodeOperation\n"];
    [self appendTo:string];
    return string;
}

@end

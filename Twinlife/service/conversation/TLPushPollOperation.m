/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLPollDescriptorImpl.h"
#import "TLPushPollOperation.h"
#import "TLPushPollIQ.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLPushPollOperation"

/*
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"6c08dca7-4eb0-4eae-a01e-56456eef5a74",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushPollOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.Operation"
 *  "fields":
 *  [
 *   {"name":"twincodeOutboundId", "type":"UUID"}
 *   {"name":"sequenceId", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLPushPollOperationSerializer
//

static NSUUID *PUSH_POLL_OPERATION_SCHEMA_ID = nil;
static int PUSH_POLL_OPERATION_SCHEMA_VERSION = 1;

//
// Implementation: TLPushPollOperation
//

@implementation TLPushPollOperation

+ (void)initialize {
    
    PUSH_POLL_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"6c08dca7-4eb0-4eae-a01e-56456eef5a74"];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return PUSH_POLL_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_POLL_OPERATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation pollDescriptor:(nonnull TLPollDescriptor *)pollDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushPoll descriptor:pollDescriptor];
    if (self) {
        _pollDescriptor = pollDescriptor;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {

    return [super initWithId:id type:TLConversationServiceOperationTypePushPoll conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLPollDescriptor *pollDescriptor = self.pollDescriptor;
    
    if (!pollDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLPollDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        pollDescriptor = (TLPollDescriptor *)descriptor;
        self.pollDescriptor = pollDescriptor;
    }
    if (![connection preparePushWithDescriptor:pollDescriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_21]) {
        TLPushPollIQ *pushPollIQ = [[TLPushPollIQ alloc] initWithSerializer:[TLPushPollIQ SERIALIZER_1] requestId:requestId pollDescriptor:pollDescriptor];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushPoll iq:pushPollIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        
        // Peer doesn't support polls.
        return [connection operationNotSupportedWithConnection:connection descriptor:pollDescriptor];
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushPollOperation\n"];
    [self appendTo:string];
    return string;
}

@end

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
#import "TLContactShareDescriptorImpl.h"
#import "TLAnswerContactShareOperation.h"
#import "TLAnswerContactShareIQ.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLAnswerContactShareOperation"

/*
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"9cee2613-e251-4b4f-9d71-f70b961f39ac",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AnswerContactShareOperation",
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

static NSUUID *ANSWER_CONTACT_SHARE_OPERATION_SCHEMA_ID = nil;
static int ANSWER_CONTACT_SHARE_OPERATION_SCHEMA_VERSION = 1;

//
// Implementation: TLAnswerContactShareOperation
//

@implementation TLAnswerContactShareOperation

+ (void)initialize {
    
    ANSWER_CONTACT_SHARE_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"9cee2613-e251-4b4f-9d71-f70b961f39ac"];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return ANSWER_CONTACT_SHARE_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return ANSWER_CONTACT_SHARE_OPERATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation contactShareDescriptor:(nonnull TLContactShareDescriptor *)contactShareDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypeAnswerContactShare descriptor:contactShareDescriptor];
    if (self) {
        _contactShareDescriptor = contactShareDescriptor;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {

    return [super initWithId:id type:TLConversationServiceOperationTypePushPoll conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLContactShareDescriptor *contactShareDescriptor = self.contactShareDescriptor;
    
    if (!contactShareDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLContactShareDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        contactShareDescriptor = (TLContactShareDescriptor *)descriptor;
        self.contactShareDescriptor = contactShareDescriptor;
    }
    if (![connection preparePushWithDescriptor:contactShareDescriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_21]) {
        TLInvitationDescriptorStatusType status = contactShareDescriptor.status;
        BOOL autoAnswer = contactShareDescriptor.autoAnswer;
        NSUUID *invitationTwincodeOutboundId  = contactShareDescriptor.invitationTwincodeOutboundId;
        NSString *invitationTwincodeOutboundPubkey = contactShareDescriptor.invitationTwincodeOutboundPubkey;
        
        TLAnswerContactShareIQ *answerContactShareIQ = [[TLAnswerContactShareIQ alloc] initWithSerializer:[TLAnswerContactShareIQ SERIALIZER_1] requestId:requestId contactShareDescriptorId:contactShareDescriptor.descriptorId status:status autoAnswer:autoAnswer invitationTwincodeOutboundId:invitationTwincodeOutboundId invitationTwincodeOutboundPubkey:invitationTwincodeOutboundPubkey];
        
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushPoll iq:answerContactShareIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        
        // Peer doesn't support contact sharing.
        return [connection operationNotSupportedWithConnection:connection descriptor:contactShareDescriptor];
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLAnswerContactShareOperation\n"];
    [self appendTo:string];
    return string;
}

@end

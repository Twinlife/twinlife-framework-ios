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
#import "TLPushContactShareOperation.h"
#import "TLPushContactShareIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLImageServiceProvider.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLPusContactShareOperation"

/*
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"af8329f4-0955-42a9-be95-bb5f66a77240",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushContactShareOperation",
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
// Implementation: TLPusContactShareOperationSerializer
//

static NSUUID *PUSH_CONTACT_SHARE_OPERATION_SCHEMA_ID = nil;
static int PUSH_CONTACT_SHARE_OPERATION_SCHEMA_VERSION = 1;

//
// Implementation: TLPushContactShareOperation
//

@implementation TLPushContactShareOperation

+ (void)initialize {
    
    PUSH_CONTACT_SHARE_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"af8329f4-0955-42a9-be95-bb5f66a77240"];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return PUSH_CONTACT_SHARE_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_CONTACT_SHARE_OPERATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation contactShareDescriptor:(nonnull TLContactShareDescriptor *)contactShareDescriptor avatar:(nonnull NSData *)avatar{
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushContactShare descriptor:contactShareDescriptor];
    if (self) {
        _contactShareDescriptor = contactShareDescriptor;
    
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {

    return [super initWithId:id type:TLConversationServiceOperationTypePushContactShare conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLContactShareDescriptor *contactShareDescriptor = self.contactShareDescriptor;
    NSData *avatar = self.avatar;
    
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
    
    if (!avatar) {
        avatar = [self.contactShareDescriptor loadAvatarData];
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_22]) {
        TLPushContactShareIQ *pushContactShareIQ = [[TLPushContactShareIQ alloc] initWithSerializer:[TLPushContactShareIQ SERIALIZER_1] requestId:requestId contactShareDescriptor:contactShareDescriptor avatar:avatar];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushContactShare iq:pushContactShareIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        
        // Peer doesn't support polls.
        return [connection operationNotSupportedWithConnection:connection descriptor:contactShareDescriptor];
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPusContactShareOperation\n"];
    [self appendTo:string];
    return string;
}

@end

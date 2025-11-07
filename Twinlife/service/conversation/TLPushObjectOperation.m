/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLObjectDescriptorImpl.h"
#import "TLPushObjectOperation.h"
#import "TLPushObjectIQ.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLPushObjectOperation"

/**
 * <pre>
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"50c7142b-bc18-4592-89fc-eaecf55ac38d",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PushObjectOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.Operation"
 *  "fields":
 *  [
 *   {"name":"twincodeOutboundId", "type":"UUID"}
 *   {"name":"sequenceId", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLPushObjectOperationSerializer
//

static NSUUID *PUSH_OBJECT_OPERATION_SCHEMA_ID = nil;
static int PUSH_OBJECT_OPERATION_SCHEMA_VERSION = 1;

//
// Implementation: TLPushObjectOperation
//

@implementation TLPushObjectOperation

+ (void)initialize {
    
    PUSH_OBJECT_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"50c7142b-bc18-4592-89fc-eaecf55ac38d"];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return PUSH_OBJECT_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_OBJECT_OPERATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation objectDescriptor:(nonnull TLObjectDescriptor *)objectDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushObject descriptor:objectDescriptor];
    if (self) {
        _objectDescriptor = objectDescriptor;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {

    return [super initWithId:id type:TLConversationServiceOperationTypePushObject conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLObjectDescriptor *objectDescriptor = self.objectDescriptor;
    if (!objectDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLObjectDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        objectDescriptor = (TLObjectDescriptor *)descriptor;
        self.objectDescriptor = objectDescriptor;
    }
    if (![connection preparePushWithDescriptor:objectDescriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_12]) {
        TLPushObjectIQ *pushObjectIQ = [[TLPushObjectIQ alloc] initWithSerializer:[TLPushObjectIQ SERIALIZER_5] requestId:requestId objectDescriptor:objectDescriptor];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushObject iq:pushObjectIQ];
        return TLBaseServiceErrorCodeQueued;

    } else if (!objectDescriptor.sendTo && !objectDescriptor.replyTo && objectDescriptor.expireTimeout == 0) {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
    
        TLConversationServicePushObjectIQ *pushObjectIQ = [[TLConversationServicePushObjectIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion objectDescriptor:objectDescriptor];
    
        NSMutableData *data = [pushObjectIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetPushObject data:data];
        return TLBaseServiceErrorCodeQueued;

    } else {
        return [connection operationNotSupportedWithConnection:connection descriptor:objectDescriptor];
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushObjectOperation\n"];
    [self appendTo:string];
    return string;
}

@end

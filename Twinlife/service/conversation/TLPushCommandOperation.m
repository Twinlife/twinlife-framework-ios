/*
 *  Copyright (c) 2020-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLPushCommandOperation.h"
#import "TLPushTransientIQ.h"
#import "TLTransientObjectDescriptorImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLBinaryEncoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLPushTransientObjectOperation"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

//
// Implementation: TLPushCommandOperationSerializer
//

static NSUUID *PUSH_COMMAND_OPERATION_SCHEMA_ID = nil;
static int PUSH_COMMAND_OPERATION_SCHEMA_VERSION = 1;
static TLSerializer *PUSH_COMMAND_OPERATION_SERIALIZER = nil;

//
// Implementation: TLPushCommandOperation
//

@implementation TLPushCommandOperation

+ (void)initialize {
    
    PUSH_COMMAND_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"9272bc23-20b6-4069-9a4c-e81f8daaca82"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return PUSH_COMMAND_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_COMMAND_OPERATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation commandDescriptor:(nonnull TLTransientObjectDescriptor *)commandDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushCommand descriptor:nil];
    if (self) {
        _commandDescriptor = commandDescriptor;
    }
    return self;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLTransientObjectDescriptor *commandDescriptor = self.commandDescriptor;
    commandDescriptor.sentTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_17]) {
        TLPushTransientIQ *pushTransientObjectIQ = [[TLPushTransientIQ alloc] initWithSerializer:[TLPushTransientIQ SERIALIZER_3] requestId:requestId transientObjectDescriptor:commandDescriptor flags:0];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushTransient iq:pushTransientObjectIQ];
    } else {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
        
        TLConversationServicePushTransientObjectIQ *pushTransientObjectIQ = [[TLConversationServicePushTransientObjectIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion transientObjectDescriptor:commandDescriptor];
        
        NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
        [[TLConversationServicePushTransientObjectIQ SERIALIZER] serializeWithSerializerFactory:connection.serializerFactory encoder:binaryEncoder object:pushTransientObjectIQ];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetPushTransient data:data];
    }

    return TLBaseServiceErrorCodeQueued;
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushCommandOperation\n"];
    [self appendTo:string];
    [string appendFormat:@" commandDescriptor: %@\n", self.commandDescriptor];
    return string;
}

@end

/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLPushTransientObjectOperation.h"
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
// Implementation: TLPushTransientObjectOperation
//

@implementation TLPushTransientObjectOperation

- (instancetype)initWithConversation:(TLConversationImpl *)conversation transientObjectDescriptor:(TLTransientObjectDescriptor *)transientObjectDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushTransientObject descriptor:nil];
    
    if(self) {
        _transientObjectDescriptor = transientObjectDescriptor;
    }
    return self;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLTransientObjectDescriptor *transientObjectDescriptor = self.transientObjectDescriptor;
    transientObjectDescriptor.sentTimestamp = [[NSDate date] timeIntervalSince1970] * 1000;
    int64_t requestId = [TLTwinlife newRequestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_17]) {
        TLPushTransientIQ *pushTransientObjectIQ = [[TLPushTransientIQ alloc] initWithSerializer:[TLPushTransientIQ SERIALIZER_3] requestId:requestId transientObjectDescriptor:transientObjectDescriptor flags:0];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushTransient iq:pushTransientObjectIQ];
    } else {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
        
        TLConversationServicePushTransientObjectIQ *pushTransientObjectIQ = [[TLConversationServicePushTransientObjectIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion transientObjectDescriptor:transientObjectDescriptor];
        
        NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
        TLBinaryEncoder *binaryEncoder = [[TLBinaryEncoder alloc] initWithData:data];
        [binaryEncoder writeFixedWithData:[TLPeerConnectionService LEADING_PADDING] start:0 length:(int32_t)[[TLPeerConnectionService LEADING_PADDING] length]];
        [[TLConversationServicePushTransientObjectIQ SERIALIZER] serializeWithSerializerFactory:connection.serializerFactory encoder:binaryEncoder object:pushTransientObjectIQ];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetPushTransient data:data];
    }

    // The PushTransientOperation has no acknowledge: we must remove the operation now.
    return TLBaseServiceErrorCodeSuccess;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushTransientObjectOperation\n"];
    [self appendTo:string];
    [string appendFormat:@" transientObjectDescriptor: %@\n", self.transientObjectDescriptor];
    return string;
}

@end

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
#import "TLGeolocationDescriptorImpl.h"
#import "TLPushGeolocationOperation.h"
#import "TLPushGeolocationIQ.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLPushGeolocationOperation"

static NSUUID *PUSH_GEOLOCATION_OPERATION_SCHEMA_ID = nil;
static int PUSH_GEOLOCATION_OPERATION_SCHEMA_VERSION = 1;

//
// Implementation: TLPushGeolocationOperation
//

@implementation TLPushGeolocationOperation

+ (void)initialize {
    
    PUSH_GEOLOCATION_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"705be6f2-c157-4f75-8325-e0e70bd04312"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return PUSH_GEOLOCATION_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return PUSH_GEOLOCATION_OPERATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation geolocationDescriptor:(nonnull TLGeolocationDescriptor *)geolocationDescriptor {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushGeolocation descriptor:geolocationDescriptor];
    if (self) {
        _geolocationDescriptor = geolocationDescriptor;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {

    return [super initWithId:id type:TLConversationServiceOperationTypePushGeolocation conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);
    
    TLGeolocationDescriptor *geolocationDescriptor = self.geolocationDescriptor;
    if (!geolocationDescriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLGeolocationDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        geolocationDescriptor = (TLGeolocationDescriptor *)descriptor;
        self.geolocationDescriptor = geolocationDescriptor;
    }
    if (![connection preparePushWithDescriptor:geolocationDescriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }
    
    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];

    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_12]) {
        TLPushGeolocationIQ *pushGeolocationIQ = [[TLPushGeolocationIQ alloc] initWithSerializer:[TLPushGeolocationIQ SERIALIZER_2] requestId:requestId geolocationDescriptor:geolocationDescriptor];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetPushGeolocation iq:pushGeolocationIQ];
        return TLBaseServiceErrorCodeQueued;

    } else if (!geolocationDescriptor.sendTo && !geolocationDescriptor.replyTo && geolocationDescriptor.expireTimeout == 0) {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
        
        TLConversationServicePushGeolocationIQ *pushGeolocationIQ = [[TLConversationServicePushGeolocationIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion geolocationDescriptor:geolocationDescriptor];
        
        NSMutableData *data = [pushGeolocationIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetPushGeolocation data:data];
        return TLBaseServiceErrorCodeQueued;

    } else {
        return [connection operationNotSupportedWithConnection:connection descriptor:geolocationDescriptor];
    }
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPushGeolocationOperation\n"];
    [self appendTo:string];
    return string;
}

@end

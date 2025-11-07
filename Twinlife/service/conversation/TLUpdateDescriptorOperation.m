/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationConnection.h"
#import "TLConversationServiceIQ.h"
#import "TLObjectDescriptorImpl.h"
#import "TLFileDescriptorImpl.h"
#import "TLUpdateDescriptorOperation.h"
#import "TLUpdateDescriptorIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define SERIALIZER_BUFFER_DEFAULT_SIZE 256

/*
 * TLUpdateDescriptorOperation
 *
 * <pre>
 * Schema version 1
 *  Date: 2025/05/21
 *
 * {
 *  "schemaVersion":"1",
 *  "type":"record",
 *  "name":"TLUpdateDescriptorOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "fields":
 *  [
 *   {"name":"updateFlags", "type":"int"}
 *  ]
 * }
 */

#undef LOG_TAG
#define LOG_TAG @"TLUpdateDescriptorOperation"

//
// Implementation: TLUpdateDescriptorOperation
//

@implementation TLUpdateDescriptorOperation

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation descriptor:(nonnull TLDescriptor *)descriptor updateFlags:(int)updateFlags {
    
    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypePushObject descriptor:descriptor];
    if (self) {
        _descriptorImpl = descriptor;
        _updateFlags = updateFlags;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content {

    self = [super initWithId:id type:TLConversationServiceOperationTypePushObject conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
    if (self) {
        int updateFlags = 0;
        if (content) {
            TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
            
            int schemaVersion = [decoder readInt];
            if (schemaVersion == 1) {
                updateFlags = [decoder readInt];
            }
        }
        _updateFlags = updateFlags;
    }
    return self;
}

- (nullable NSData *)serialize {
    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *encoder = [[TLBinaryEncoder alloc] initWithData:content];

    [encoder writeInt:1];
    [encoder writeInt:self.updateFlags];
    return content;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    TLDescriptor *descriptor = self.descriptorImpl;
    if (!descriptor) {
        TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];
        if (!descriptor || ![descriptor isKindOfClass:[TLObjectDescriptor class]]) {
            return TLBaseServiceErrorCodeExpired;
        }
        self.descriptorImpl = descriptor;
    }
    if (![connection preparePushWithDescriptor:descriptor]) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_20]) {

        NSString *message;
        NSNumber *copyAllowed;
        NSNumber *expireTimeout;
        if ([descriptor isKindOfClass:[TLObjectDescriptor class]]) {
            TLObjectDescriptor *objectDescriptor = (TLObjectDescriptor *)descriptor;

            message = (self.updateFlags & TL_UPDATE_MESSAGE) ? objectDescriptor.message : nil;
            copyAllowed = (self.updateFlags & TL_UPDATE_COPY_ALLOWED) ? [NSNumber numberWithBool:objectDescriptor.copyAllowed] : nil;
            expireTimeout = (self.updateFlags & TL_UPDATE_EXPIRATION) ? [NSNumber numberWithLongLong:objectDescriptor.expireTimeout] : nil;

        } else if ([descriptor isKindOfClass:[TLFileDescriptor class]]) {
            TLFileDescriptor *fileDescriptor = (TLFileDescriptor *)descriptor;

            copyAllowed = (self.updateFlags & TL_UPDATE_COPY_ALLOWED) ? [NSNumber numberWithBool:fileDescriptor.copyAllowed] : nil;
            expireTimeout = (self.updateFlags & TL_UPDATE_EXPIRATION) ? [NSNumber numberWithLongLong:fileDescriptor.expireTimeout] : nil;

        } else {
            return TLBaseServiceErrorCodeBadRequest;
        }

        TLUpdateDescriptorIQ *updateDescriptorIQ = [[TLUpdateDescriptorIQ alloc] initWithSerializer:[TLUpdateDescriptorIQ SERIALIZER_1] requestId:requestId descriptorId:descriptor.descriptorId updatedTimestamp:descriptor.updatedTimestamp message:message copyAllowed:copyAllowed expiredTimeout:expireTimeout];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetUpdateObject iq:updateDescriptorIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        return TLBaseServiceErrorCodeFeatureNotSupportedByPeer;
    }
}

+ (int)buildFlagsWithMessage:(nullable NSString *)message copyAllowed:(nullable NSNumber *)copyAllowed expireTimeout:(nullable NSNumber *)expireTimeout {
    
    return (message ? TL_UPDATE_MESSAGE : 0)
    | (copyAllowed != nil ? TL_UPDATE_COPY_ALLOWED : 0)
    | (expireTimeout != nil && expireTimeout.longLongValue != 0 ? TL_UPDATE_EXPIRATION : 0);
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLUpdateDescriptorOperation\n"];
    [self appendTo:string];
    return string;
}

@end

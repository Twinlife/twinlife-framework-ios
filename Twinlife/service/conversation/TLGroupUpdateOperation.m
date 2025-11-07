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
#import "TLGroupUpdateOperation.h"
#import "TLUpdatePermissionsIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLGroupUpdateOperation"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 128

//
// Implementation: TLGroupUpdateOperation
//

@implementation TLGroupUpdateOperation

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions {

    self = [super initWithConversation:conversation type:TLConversationServiceOperationTypeUpdateGroupMember groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
    if (self) {
        _permissions = 0;
    }
    return self;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type groupTwincodeId:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions publicKey:(nullable NSString *)publicKey signedOffTwincodeId:(nullable NSUUID *)signedOffTwincodeId signature:(nullable NSString *)signature {
    
    self = [super initWithConversation:conversation type:type groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
    if (self) {
        _permissions = permissions;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content {
    
    NSUUID *groupTwincodeId = nil;
    NSUUID *memberTwincodeId = nil;
    if (self) {
        if (content) {
            TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
            
            int schemaVersion = [decoder readInt];
            if (schemaVersion <= GROUP_OPERATION_SCHEMA_VERSION_2) {
                groupTwincodeId = [decoder readUUID];
                memberTwincodeId = [decoder readUUID];
            }
        }
    }

    return [super initWithId:id type:type conversationId:conversationId creationDate:creationDate descriptorId:descriptorId groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId];
}

- (nullable NSData *)serialize {

    return [TLGroupOperation serializeOperation:self.groupTwincodeId memberTwincodeId:self.memberTwincodeId permissions:self.permissions publicKey:nil signedOffTwincodeId:nil signature:nil];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    NSUUID *groupTwincodeId = self.groupTwincodeId;
    NSUUID *memberTwincodeId = self.memberTwincodeId;
    if (!groupTwincodeId || !memberTwincodeId) {
        return TLBaseServiceErrorCodeExpired;
    }

    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];
    if ([connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_17]) {
        TLUpdatePermissionsIQ *updatePermissionsIQ = [[TLUpdatePermissionsIQ alloc] initWithSerializer:[TLUpdatePermissionsIQ SERIALIZER_2] requestId:requestId groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId permissions:self.permissions];
        [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetUpdateGroupMember iq:updatePermissionsIQ];
        return TLBaseServiceErrorCodeQueued;

    } else {
        int majorVersion = [connection getMaxPeerMajorVersion];
        int minorVersion = [connection getMaxPeerMinorVersionWithMajorVersion:majorVersion];
        
        TLConversationServiceUpdateGroupMemberIQ *updateGroupMemberIQ = [[TLConversationServiceUpdateGroupMemberIQ alloc] initWithFrom:connection.from to:connection.to requestId:requestId majorVersion:majorVersion minorVersion:minorVersion groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId permissions:self.permissions];
        
        NSMutableData *data = [updateGroupMemberIQ serializeWithSerializerFactory:connection.serializerFactory];
        [connection sendMessageWithStatType:TLPeerConnectionServiceStatTypeIqSetUpdateGroupMember data:data];
        return TLBaseServiceErrorCodeQueued;
    }
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLGroupUpdateOperation"];
    [self appendTo:string];
    return string;
}

@end

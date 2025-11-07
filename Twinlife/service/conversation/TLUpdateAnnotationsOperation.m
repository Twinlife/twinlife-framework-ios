/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>

#import "TLConversationImpl.h"
#import "TLConversationServiceImpl.h"
#import "TLDescriptorImpl.h"
#import "TLUpdateAnnotationsOperation.h"
#import "TLUpdateAnnotationsIQ.h"
#import "TLTwinlifeImpl.h"
#import "TLConversationServiceProvider.h"
#import "TLConversationConnection.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
//static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLUpdateAnnotationsOperation"

//
// Implementation: TLUpdateAnnotationsOperationSerializer
//

static NSUUID *UPDATE_ANNOTATIONS_OPERATION_SCHEMA_ID = nil;
static const int UPDATE_ANNOTATIONS_OPERATION_SCHEMA_VERSION_1 = 1;

//
// Implementation: TLUpdateAnnotationsOperation
//

@implementation TLUpdateAnnotationsOperation

+ (void)initialize {
    
    UPDATE_ANNOTATIONS_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"dc513717-c843-40e8-8b04-0d8016052935"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return UPDATE_ANNOTATIONS_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_1 {
    
    return UPDATE_ANNOTATIONS_OPERATION_SCHEMA_VERSION_1;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation descriptorId:(nonnull TLDescriptorId *)descriptorId {

    return [super initWithConversation:conversation type:TLConversationServiceOperationTypeUpdateAnnotations descriptorId:descriptorId.id];
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {

    return [super initWithId:id type:TLConversationServiceOperationTypeUpdateAnnotations conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    DDLogVerbose(@"%@ executeWithConnection: %@", LOG_TAG, connection);

    if (![connection isSupportedWithMajorVersion:CONVERSATION_SERVICE_MAJOR_VERSION_2 minorVersion:CONVERSATION_SERVICE_MINOR_VERSION_14]) {
        return TLBaseServiceErrorCodeExpired;
    }

    TLDescriptor *descriptor = [connection loadDescriptorWithId:self.descriptor];

    // For this version, we only send our own annotations.  They are all associated with the same twincode.
    int64_t requestId = [TLTwinlife newRequestId];
    [self updateWithRequestId:requestId];

    TLConversationImpl *conversation = connection.conversation;
    NSMutableArray<TLDescriptorAnnotation *> *list = [connection.conversationService.serviceProvider loadLocalAnnotationsWithDescriptorId:descriptor.descriptorId conversation:[conversation mainConversation]];
    NSMutableDictionary<NSUUID *, NSMutableArray<TLDescriptorAnnotation *> *> *annotations = [[NSMutableDictionary alloc] initWithCapacity:1];
    [annotations setObject:list forKey:conversation.twincodeOutboundId];

    TLUpdateAnnotationsIQ *updateAnnotationsIQ = [[TLUpdateAnnotationsIQ alloc] initWithSerializer:[TLUpdateAnnotationsIQ SERIALIZER_1] requestId:requestId descriptorId:descriptor.descriptorId updateType:TLUpdateAnnotationsUpdateTypeSet annotations:annotations];

    [connection sendPacketWithStatType:TLPeerConnectionServiceStatTypeIqSetUpdateObject iq:updateAnnotationsIQ];
    return TLBaseServiceErrorCodeQueued;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLUpdateAnnotationsOperation\n"];
    [self appendTo:string];
    return string;
}

@end

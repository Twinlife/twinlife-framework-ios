/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"
#import "TLConversationService.h"

#import "TLConversationImpl.h"
#import "TLConversationServiceImpl.h"
#import "TLConversationConnection.h"

//
// Implementation: TLConversationServiceOperation
//

@implementation TLConversationServiceOperation

+ (int64_t)NO_REQUEST_ID {
    
    return OPERATION_NO_REQUEST_ID;
}

- (instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type descriptor:(nullable TLDescriptor *)descriptor {
    
    self = [super init];
    if (self) {
        _id = 0;
        _type = type;
        _descriptor = descriptor ? descriptor.descriptorId.id : 0;
        _conversationId = conversation.identifier;
        _timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        _requestId = OPERATION_NO_REQUEST_ID;
    }
    return self;
}

- (instancetype)initWithConversationId:(nonnull TLDatabaseIdentifier *)conversationId type:(TLConversationServiceOperationType)type descriptor:(nullable TLDescriptor *)descriptor {
    
    self = [super init];
    if (self) {
        _id = 0;
        _type = type;
        _descriptor = descriptor ? descriptor.descriptorId.id : 0;
        _conversationId = conversationId;
        _timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        _requestId = OPERATION_NO_REQUEST_ID;
    }
    return self;
}

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type descriptorId:(int64_t)descriptorId {
    
    self = [super init];
    if (self) {
        _id = 0;
        _type = type;
        _descriptor = descriptorId;
        _conversationId = conversation.identifier;
        _timestamp = [[NSDate date] timeIntervalSince1970] * 1000;
        _requestId = OPERATION_NO_REQUEST_ID;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId {

    self = [super init];
    if (self) {
        _id = id;
        _conversationId = conversationId;
        _type = type;
        _timestamp = creationDate;
        _descriptor = descriptorId;
        _requestId = OPERATION_NO_REQUEST_ID;
    }
    return self;
}

- (NSComparisonResult)compareWithOperation:(nonnull TLConversationServiceOperation *)operation {

    if (self.type == operation.type) {
        // Order by operation id when types are identical.
        if (self.id == operation.id) {
            return NSOrderedSame;
        }
        return self.id < operation.id ? NSOrderedAscending : NSOrderedDescending;
    }

    // Put invoke operations first (before synchronize).
    if (self.type >= TLConversationServiceOperationTypeInvokeJoinGroup) {
        return NSOrderedAscending;
    }
    if (operation.type >= TLConversationServiceOperationTypeInvokeJoinGroup) {
        return NSOrderedDescending;
    }

    // Put Synchronize operation first.
    if (self.type == TLConversationServiceOperationTypeSynchronizeConversation) {
        return NSOrderedAscending;
    }
    if (operation.type == TLConversationServiceOperationTypeSynchronizeConversation) {
        return NSOrderedDescending;
    }


    // Put file operations last but not after a reset conversation.
    if (self.type == TLConversationServiceOperationTypePushFile && operation.type != TLConversationServiceOperationTypeResetConversation) {
        return NSOrderedDescending;
    }
    if (self.type != TLConversationServiceOperationTypeResetConversation && operation.type == TLConversationServiceOperationTypePushFile) {
        return NSOrderedAscending;
    }

    // Types are different but of equivalent, order by operation id.
    if (self.id == operation.id) {
        return NSOrderedSame;
    }
    return self.id < operation.id ? NSOrderedAscending : NSOrderedDescending;
}

- (void)updateWithRequestId:(int64_t)requestId {
    
    self.requestId = requestId;
}

- (nullable NSData *)serialize {
    
    return nil;
}

- (BOOL)canExecuteWithConversation:(nonnull TLConversationImpl *)conversation {
    
    return self.requestId == OPERATION_NO_REQUEST_ID
    && (self.type >= TLConversationServiceOperationTypeInvokeJoinGroup
        || [conversation isOpened]);
}

- (BOOL)isInvokeTwincode {
    
    return self.type >= TLConversationServiceOperationTypeInvokeJoinGroup;
}

- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection {
    
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)executeInvokeWithConversation:(nonnull TLConversationImpl *)conversationImpl conversationService:(nonnull TLConversationService *)conversationService {
    
    return TLBaseServiceErrorCodeSuccess;
}

- (void)appendTo:(NSMutableString*)string {
    
    [string appendFormat:@" id:             %lld\n", self.id];
    [string appendFormat:@" type:           %u\n", self.type];
    [string appendFormat:@" conversationId: %@\n", self.conversationId];
    [string appendFormat:@" timestamp:      %lld\n", self.timestamp];
    [string appendFormat:@" requestId:      %lld\n", self.requestId];
    [string appendFormat:@" descriptor:     %lld\n", self.descriptor];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversationServiceOperation\n"];
    [self appendTo:string];
    return string;
}

@end

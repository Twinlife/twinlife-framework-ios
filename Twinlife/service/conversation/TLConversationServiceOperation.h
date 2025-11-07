/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSerializer.h"
#import "TLBaseService.h"

typedef enum {
    TLConversationServiceOperationTypeResetConversation,
    TLConversationServiceOperationTypeSynchronizeConversation,
    TLConversationServiceOperationTypePushObject,
    TLConversationServiceOperationTypePushTransientObject,
    TLConversationServiceOperationTypePushFile,
    TLConversationServiceOperationTypeUpdateDescriptorTimestamp,
    TLConversationServiceOperationTypeInviteGroup,
    TLConversationServiceOperationTypeWithdrawInviteGroup,
    TLConversationServiceOperationTypeJoinGroup,
    TLConversationServiceOperationTypeLeaveGroup,
    TLConversationServiceOperationTypeUpdateGroupMember,
    TLConversationServiceOperationTypePushGeolocation,
    TLConversationServiceOperationTypePushTwincode,
    TLConversationServiceOperationTypePushCommand,
    TLConversationServiceOperationTypeUpdateAnnotations,
    TLConversationServiceOperationTypeUpdateObject,

    // Operations that don't need the P2P connection to be opened.
    TLConversationServiceOperationTypeInvokeJoinGroup,
    TLConversationServiceOperationTypeInvokeLeaveGroup,
    TLConversationServiceOperationTypeInvokeAddMember
} TLConversationServiceOperationType;

static const int64_t OPERATION_NO_REQUEST_ID = -1L;

@class TLConversationImpl;
@class TLDescriptorId;
@class TLDatabaseIdentifier;
@class TLDescriptor;
@class TLConversationConnection;
@class TLConversationService;

//
// Interface: TLConversationServiceOperation
//

@interface TLConversationServiceOperation : NSObject

@property int64_t id;
@property (readonly) TLConversationServiceOperationType type;
@property (readonly, nonnull) TLDatabaseIdentifier *conversationId;
@property (readonly) int64_t timestamp;
@property (readonly) int64_t descriptor;
@property int64_t requestId;

+ (int64_t)NO_REQUEST_ID;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type descriptor:(nullable TLDescriptor *)descriptor;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type descriptorId:(int64_t)descriptorId;

// Specific method used only by TLResetConversationOperation
- (nonnull instancetype)initWithConversationId:(nonnull TLDatabaseIdentifier *)conversationId type:(TLConversationServiceOperationType)type descriptor:(nullable TLDescriptor *)descriptor;

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type  conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId;

- (NSComparisonResult)compareWithOperation:(nonnull TLConversationServiceOperation *)operation;

- (void)updateWithRequestId:(int64_t)requestId;

- (void)appendTo:(nonnull NSMutableString*)string;

- (nullable NSData *)serialize;

/// Check if we can execute the operation immediately:
/// INVOKE_LEAVE_GROUP, INVOKE_JOIN_GROUP, INVOKE_ADD_MEMBER don't need a P2P connection.
- (BOOL)canExecuteWithConversation:(nonnull TLConversationImpl *)conversation;

/// Check if the operation is an executeInvoke() operation.
- (BOOL)isInvokeTwincode;

/// Execute the operation by using the given connection instance.
- (TLBaseServiceErrorCode)executeWithConnection:(nonnull TLConversationConnection *)connection;

/// Execute the operation with its conversation instance: it may not be connected to the peer (only usable for twincode invocations).
- (TLBaseServiceErrorCode)executeInvokeWithConversation:(nonnull TLConversationImpl *)conversationImpl conversationService:(nonnull TLConversationService *)conversationService;

@end

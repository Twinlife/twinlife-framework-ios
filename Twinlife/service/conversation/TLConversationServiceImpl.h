/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationService.h"
#import "TLPeerConnectionService.h"
#import "TLBaseServiceImpl.h"
#import "TLAssertion.h"

#ifdef TWINME
    #define CONVERSATION_MAX_GROUP_MEMBERS 12
#else
    #define CONVERSATION_MAX_GROUP_MEMBERS 20
#endif

#define INVOKE_TWINCODE_ACTION_CONVERSATION_REFRESH_SECRET    @"twinlife::conversation::refresh-secret"
#define INVOKE_TWINCODE_ACTION_CONVERSATION_ON_REFRESH_SECRET @"twinlife::conversation::on-refresh-secret"
#define INVOKE_TWINCODE_ACTION_CONVERSATION_VALIDATE_SECRET   @"twinlife::conversation::validate-secret"

@class TLConversationImpl;
@class TLConversationConnection;

typedef void (^TLPeerConnectionBinaryPacketListener) (TLConversationConnection * _Nonnull, TLBinaryPacketIQ * _Nonnull iq);

//
// Interface: TLConversationServiceAssertPoint ()
//

@interface TLConversationServiceAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)SERVICE;
+(nonnull TLAssertPoint *)EXCEPTION;
+(nonnull TLAssertPoint *)SERIALIZE_ERROR;
+(nonnull TLAssertPoint *)PROCESS_IQ;
+(nonnull TLAssertPoint *)PROCESS_LEGACY_IQ;
+(nonnull TLAssertPoint *)RESET_CONVERSATION;
+(nonnull TLAssertPoint *)LOCK_CONVERSATION_FAILED;

@end

//
// Interface: TLPeerConnectionPacketHandler ()
//

@interface TLPeerConnectionPacketHandler : NSObject

@property (nonnull, readonly) TLSerializer *serializer;
@property (nonnull, readonly) TLPeerConnectionBinaryPacketListener listener;

- (nonnull instancetype)initWithSerializer:(nonnull TLSerializer *)serializer listener:(nonnull TLPeerConnectionBinaryPacketListener)listener;

@end

//
// Interface: TLConversationService ()
//

@class TLGroupConversationImpl;
@class TLConversationServiceProvider;
@class TLIQ;
@class TLConversationServiceResetConversationIQ;
@class TLConversationServicePushObjectIQ;
@class TLConversationServiceOnPushObjectIQ;
@class TLConversationServiceOperation;
@class TLConversationServicePeerConnectionServiceDelegate;
@class TLConversationServiceTwincodeOutboundServiceDelegate;
@class TLConversationServiceScheduler;
@class TLGroupConversationManager;
@class TLSignatureInfoIQ;

@interface TLConversationService ()<TLPeerConnectionDataChannelDelegate, TLPeerConnectionDelegate>

@property (readonly, nonnull) TLConversationServiceProvider *serviceProvider;
@property (readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (readonly, nonnull) TLTwincodeOutboundService *twincodeOutboundService;
@property (readonly, nonnull) TLTwincodeInboundService *twincodeInboundService;
@property (readonly, nonnull) NSMutableDictionary<NSUUID*, TLConversationConnection *> *peerConnectionId2Conversation;
@property (readonly, nonnull) TLConversationServiceScheduler *scheduler;
@property (readonly, nonnull) NSMutableDictionary<TLSerializerKey *, TLPeerConnectionPacketHandler *> *binaryPacketListeners;
@property (readonly, nonnull) TLGroupConversationManager *groupManager;
@property (nonnull) int64_t *requestId;
@property (readonly, nonnull) dispatch_queue_t executorQueue;
@property (readonly, nonnull) NSMutableSet<NSUUID*> *acceptedPushTwincode;
@property BOOL groupsLoaded;
@property BOOL needResyncGroups;
@property int lockIdentifier;

@property (readonly, nonnull) TLConversationServiceTwincodeOutboundServiceDelegate *twincodeOutboundServiceDelegate;

+ (int)MAJOR_VERSION_1;

+ (int)CONVERSATION_SERVICE_MAJOR_VERSION_2;

+ (int)CONVERSATION_SERVICE_GROUP_MINOR_VERSION;

+ (int)CONVERSATION_SERVICE_GROUP_RESET_CONVERSATION_MINOR_VERSION;

+ (int)CONVERSATION_SERVICE_GEOLOCATION_MINOR_VERSION;

+ (int)CONVERSATION_SERVICE_PUSH_COMMAND_MINOR_VERSION;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife peerConnectionService:(nonnull TLPeerConnectionService *)peerConnectionService;

- (void)onTerminatePeerConnectionWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)onDataChannelOpenWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId peerVersion:(nonnull NSString *)peerVersion leadingPadding:(BOOL)leadingPadding;

- (void)onDataChannelClosedWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;

- (void)onDataChannelMessageWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId data:(nonnull NSData *)data leadingPadding:(BOOL)leadingPadding;

/// Force a reload of conversations operations by the conversation scheduler.
/// This is intended to be called in case the ShareExtension has created some operations while we are still running (ie, not yet suspended).
- (void)reloadOperations;

- (void)loadConversations;

- (void)askConversationSynchronizeWithConversation:(nonnull TLConversationImpl*) conversation;

- (void)executeOperationWithConversation:(nonnull TLConversationImpl *)conversation;

- (void)executeFirstOperationWithConversation:(nonnull TLConversationImpl *)conversation operation:(nonnull TLConversationServiceOperation *)operation;

- (void)executeNextOperationWithConnection:(nonnull TLConversationConnection *)connection operation:(nonnull TLConversationServiceOperation *)operation;

- (nullable id <TLConversation>)getConversationWithId:(nonnull TLDatabaseIdentifier *)conversationId;

- (void)closeWithConnection:(nonnull TLConversationConnection *)connection terminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

- (void)notifyDeletedConversationWithList:(nonnull NSArray<TLConversationImpl *> *)list;

- (void)addPacketListener:(nonnull TLBinaryPacketIQSerializer *)serializer listener:(nonnull TLPeerConnectionBinaryPacketListener)listener;

- (void)deleteConversation:(nonnull TLConversationImpl *)conversationImpl;

- (BOOL)resetWithConversation:(nonnull id<TLConversation>)conversation resetList:(nonnull NSDictionary<NSUUID *, TLDescriptorId *> *)resetList clearMode:(TLConversationServiceClearMode)clearMode;

- (void)deleteFilesWithConversation:(nonnull id <TLConversation>)conversation;

- (void)addOperationsWithMap:(nonnull NSMapTable<TLConversationImpl *, NSObject *> *)pendingOperations;

- (void)deleteConversationDescriptor:(nonnull TLDescriptor *)descriptor requestId:(int64_t)requestId conversation:(nonnull id<TLConversation>)conversation;

+ (nonnull NSMutableArray<TLConversationImpl *> *)getConversations:(nonnull id <TLConversation>)conversation sendTo:(nullable NSUUID *)sendTo;

- (void)updateWithDescriptor:(nonnull TLDescriptor *)descriptor conversation:(nonnull TLConversationImpl *)conversationImpl;

@end

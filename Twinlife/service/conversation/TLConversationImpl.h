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
#import "TLSerializer.h"
#import "TLDatabaseService.h"

//
// Interface: TLConversationFactory
//

@interface TLConversationFactory : NSObject <TLDatabaseObjectFactory>

@property (readonly, nonnull) TLDatabaseService *database;

- (nonnull instancetype)initWithDatabase:(nonnull TLDatabaseService *)database;

@end

//
// Interface: TLConversationImpl ()
//

@class TLGroupConversationImpl;
@class TLConversationServiceProvider;
@class TLConversationConnection;

@interface TLConversationImpl : NSObject<TLConversation>

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property (readonly, nonnull) id<TLRepositoryObject> subject;
@property (readonly) int64_t creationDate;
@property (readonly, nonnull) NSUUID *resourceId;
@property int flags;

@property (nullable) NSUUID *peerResourceId;
@property BOOL isActive;
@property int delayPos;
@property int64_t delay;
@property BOOL needSynchronize;
@property int64_t lastConnectTime;
@property int64_t lastRetryTime;
@property int64_t permissions;
@property (nullable) TLConversationConnection *connection;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier conversationId:(nonnull NSUUID *)conversationId subject:(nonnull id<TLRepositoryObject>)subject creationDate:(int64_t)creationDate resourceId:(nonnull NSUUID *)resourceId peerResourceId:(nullable NSUUID *)peerResourceId permissions:(int64_t)permissions lastConnectDate:(int64_t)lastConnectDate lastRetryDate:(int64_t)lastRetryDate flags:(int)flags;

- (void)updateWithPeerResourceId:(nullable NSUUID *)peerResourceId permissions:(int64_t)permissions lastConnectDate:(int64_t)lastConnectDate lastRetryDate:(int64_t)lastRetryDate flags:(int)flags;

- (nonnull NSString *)to;

- (nonnull NSString *)from;

- (nonnull id<TLConversation>)mainConversation;

- (nullable TLGroupConversationImpl *)groupConversation;

- (void)touch;

- (void)resetDelay;

- (void)nextDelayWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason;

/// Returns YES if the P2P connection is opened.
- (BOOL)isOpened;

/// Start an incoming P2P connection if we are idle or return nil if we must reject the incoming connection.
- (nullable TLConversationConnection *)acceptIncomingWithTimestamp:(int64_t)now twinlife:(nonnull TLTwinlife *)twinlife;

/// Start an outgoing P2P connection if we are idle or return nil.
- (nullable TLConversationConnection *)startOutgoingWithTimestamp:(int64_t)now twinlife:(nonnull TLTwinlife *)twinlife;

/// Close the current connection if there is one.
- (void)closeConnection;

/// Old group member support: transfer the connection from the TLGroupConversation incoming P2P to the real group member conversation.
- (nonnull TLConversationConnection *)transferWithConnection:(nonnull TLConversationConnection*)connection twinlife:(nonnull TLTwinlife *)twinlife;

- (void)appendTo:(nonnull NSMutableString*)string;

@end

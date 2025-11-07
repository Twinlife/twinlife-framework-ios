/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLConversationImpl.h"
#import "TLTwincodeInboundService.h"
#import "TLTwincodeOutboundService.h"
#import "TLRepositoryService.h"
#import "TLConversationServiceProvider.h"
#import "TLConversationConnection.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLConversationServiceImpl.h"
#import "TLGroupConversationImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLConversationSerializer
//

static NSUUID *CONVERSATION_SCHEMA_ID = nil;
static int CONVERSATION_SCHEMA_VERSION = 4;
static const int FAST_RETRY_DELAY = 20 * 1000; // 20 sec (must be > 8 sec to get a Firebase wakeup)
static const int LONG_RETRY_DELAY = 60 * 1000; // 1 min

/**
 * Backoff table to retry connection to a peer.
 * - retry two times quite quickly,
 * - pause for a longer time that doubles until it reaches 60 mins.
 * - last entry is only used when we receive a GONE
 */
static const int BACKOFF_DELAYS[] = {
    FAST_RETRY_DELAY,
    FAST_RETRY_DELAY,
    2 * LONG_RETRY_DELAY,
    4 * LONG_RETRY_DELAY,
    8 * LONG_RETRY_DELAY,
    16 * LONG_RETRY_DELAY,
    32 * LONG_RETRY_DELAY,
    60 * LONG_RETRY_DELAY  // GONE delay or long running errors.
};
static const int BACKOFF_DELAYS_COUNT = sizeof(BACKOFF_DELAYS) / sizeof(BACKOFF_DELAYS[0]);

//
// Implementation: TLConversationFactory
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationFactory"

@implementation TLConversationFactory

+ (void)initialize {
    
    CONVERSATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"7589801a-83ba-4ce2-af50-46994088053e"];
}

- (nonnull instancetype)initWithDatabase:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@ initWithDatabase: %@", LOG_TAG, database);

    self = [super init];
    if (self) {
        _database = database;
    }
    return self;
}

- (TLDatabaseTable)kind {
    
    return TLDatabaseTableConversation;
}

- (nonnull NSUUID *)schemaId {
    
    // This is informational: the value is not stored in the database (but used in the TLDatabaseIdentifier).
    return CONVERSATION_SCHEMA_ID;
}

- (int)schemaVersion {
    
    // This is informational: the value is not stored in the database (but used in the TLDatabaseIdentifier).
    return CONVERSATION_SCHEMA_VERSION;
}

- (BOOL)isLocal {
    
    return YES;
}

- (nullable id<TLDatabaseObject>)createObjectWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ createObjectWithIdentifier: %@", LOG_TAG, identifier);

    NSUUID *conversationId = [cursor uuidForColumnIndex:offset];
    int64_t creationDate = [cursor longLongIntForColumnIndex:offset + 1];
    long subjectId = [cursor longForColumnIndex:offset + 2];
    NSUUID *schemaId = [cursor uuidForColumnIndex:offset + 3];
    // We don't use it for the conversation since we have it on the subject
    // long peerTwincodeOutbound = cursor.getLong(offset + 4);
    NSUUID *resourceId = [cursor uuidForColumnIndex:offset + 5];
    NSUUID *peerResourceId = [cursor uuidForColumnIndex:offset + 6];
    int64_t permissions = [cursor longLongIntForColumnIndex:offset + 7];
    // long joinPermissions = cursor.getLong(offset + 8);
    int64_t lastConnectDate = [cursor longLongIntForColumnIndex:offset + 9];
    int64_t lastRetryDate = [cursor longLongIntForColumnIndex:offset + 10];
    int flags = [cursor intForColumnIndex:offset + 11];
    long descriptorCount = [cursor longForColumnIndex:offset + 12];
    id<TLRepositoryObject> subject = [self.database loadRepositoryObjectWithId:subjectId schemaId:schemaId];
    if (!subject) {
        return nil;
    }

    TLConversationImpl *result = [[TLConversationImpl alloc] initWithIdentifier:identifier conversationId:conversationId subject:subject creationDate:creationDate resourceId:resourceId peerResourceId:peerResourceId permissions:permissions == 0 ? -1L : permissions lastConnectDate:lastConnectDate lastRetryDate:lastRetryDate flags:flags];
    if (descriptorCount > 0) {
        result.isActive = YES;
    }
    return result;
}

- (BOOL)loadWithObject:(nonnull id<TLDatabaseObject>)object cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ loadWithObject: %@", LOG_TAG, object);

    // Ignore fields which are read-only.
    // NSUUID *conversationId = [cursor uuidForColumnIndex:offset];
    // int64_t creationDate = [cursor longLongIntForColumnIndex:offset + 1];
    // long subjectId = [cursor longForColumnIndex:offset + 2];
    // NSUUID *schemaId = [cursor uuidForColumnIndex:offset + 3];
    // long peerTwincodeOutbound = cursor.getLong(offset + 4);
    // NSUUID *resourceId = [cursor uuidForColumnIndex:offset + 5];
    NSUUID *peerResourceId = [cursor uuidForColumnIndex:offset + 6];
    int64_t permissions = [cursor longLongIntForColumnIndex:offset + 7];
    // long joinPermissions = cursor.getLong(offset + 8);
    int64_t lastConnectDate = [cursor longLongIntForColumnIndex:offset + 9];
    int64_t lastRetryDate = [cursor longLongIntForColumnIndex:offset + 10];
    int flags = [cursor intForColumnIndex:offset + 11];
    long descriptorCount = [cursor longForColumnIndex:offset + 12];
    TLConversationImpl *conversation = (TLConversationImpl *)object;
    [conversation updateWithPeerResourceId:peerResourceId permissions:permissions == 0 ? -1L : permissions lastConnectDate:lastConnectDate lastRetryDate:lastRetryDate flags:flags];
    conversation.isActive = descriptorCount > 0 ? YES : NO;
    return YES;
}

@end

//
// Implementation: TLConversationImpl
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationImpl"

@implementation TLConversationImpl

@synthesize uuid = _uuid;
@synthesize subject = _subject;

+ (NSUUID *)SCHEMA_ID {
    
    return CONVERSATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return CONVERSATION_SCHEMA_VERSION;
}

#define FLAGS_TO_DELAY(FLAGS) \
   ((((FLAGS) >> 8) >= BACKOFF_DELAYS_COUNT) ? BACKOFF_DELAYS_COUNT - 1 : ((FLAGS) >> 8))

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier conversationId:(nonnull NSUUID *)conversationId subject:(nonnull id<TLRepositoryObject>)subject creationDate:(int64_t)creationDate resourceId:(nonnull NSUUID *)resourceId peerResourceId:(nullable NSUUID *)peerResourceId permissions:(int64_t)permissions lastConnectDate:(int64_t)lastConnectDate lastRetryDate:(int64_t)lastRetryDate flags:(int)flags {
    DDLogVerbose(@"%@ initWithIdentifier: %@ conversationId: %@ subject: %@", LOG_TAG, identifier, conversationId, subject);

    self = [super init];
    if (self) {
        _databaseId = identifier;
        _uuid = conversationId;
        _subject = subject;
        _creationDate = creationDate;
        _resourceId = resourceId;
        _peerResourceId = peerResourceId;
        _permissions = permissions;
        _lastConnectTime = lastConnectDate;
        _lastRetryTime = lastRetryDate;
        _flags = flags;
        _delayPos = FLAGS_TO_DELAY(flags);
        _delay = BACKOFF_DELAYS[_delayPos];
    }
    return self;
}

- (void)updateWithPeerResourceId:(nullable NSUUID *)peerResourceId permissions:(int64_t)permissions lastConnectDate:(int64_t)lastConnectDate lastRetryDate:(int64_t)lastRetryDate flags:(int)flags {
    DDLogVerbose(@"%@ updateWithPeerResourceId: %@ permissions: %lld lastConnectDate: %lld lastRetryDate: %lld flags: %d", LOG_TAG, peerResourceId, permissions, lastConnectDate, lastRetryDate, flags);

    @synchronized (self) {
        self.peerResourceId = peerResourceId;
        self.permissions = permissions;
        self.lastConnectTime = lastConnectDate;
        self.lastRetryTime = lastRetryDate;
        self.flags = flags;
        self.delayPos = FLAGS_TO_DELAY(flags);
        self.delay = BACKOFF_DELAYS[self.delayPos];
    }
}

#pragma - mark TLDatabaseObject

- (nonnull TLDatabaseIdentifier *)identifier {
    
    return self.databaseId;
}

- (nonnull NSUUID *)objectId {
    
    return self.uuid;
}

#pragma - mark TLConversation

- (nonnull NSUUID *)twincodeOutboundId {
    
    TLTwincodeOutbound *twincodeOutbound = [self.subject twincodeOutbound];
    if (twincodeOutbound) {
        return [twincodeOutbound uuid];
    } else {
        return [TLTwincode NOT_DEFINED];
    }
}

- (nonnull NSUUID *)twincodeInboundId {
    
    TLTwincodeInbound *twincodeInbound = [self.subject twincodeInbound];
    if (twincodeInbound) {
        return [twincodeInbound uuid];
    } else {
        return [TLTwincode NOT_DEFINED];
    }
}

- (nullable TLTwincodeOutbound *)peerTwincodeOutbound {
    
    return [self.subject peerTwincodeOutbound];
}

- (nonnull NSUUID *)peerTwincodeOutboundId {

    TLTwincodeOutbound *peerTwincodeOutbound = [self.subject peerTwincodeOutbound];
    if (peerTwincodeOutbound) {
        return [peerTwincodeOutbound uuid];
    } else {
        return [TLTwincode NOT_DEFINED];
    }
    return nil;
}

- (nonnull NSUUID *)contactId {
    
    return self.subject.objectId;
}

- (BOOL)isGroup {

    return NO;
}

- (BOOL)isConversationWithUUID:(NSUUID *)id {
    
    return [self.uuid isEqual:id];
}

- (BOOL)hasPermissionWithPermission:(TLPermissionType)permission {
    
    return (permission != TLPermissionTypeNone) && (self.permissions & (1 << permission)) != 0;
}

- (BOOL)hasPeer {
    
    return [self.subject canCreateP2P];
}

- (nonnull id<TLConversation>)mainConversation {
    
    return self;
}

- (nullable TLGroupConversationImpl *)groupConversation {
    
    return nil;
}

#pragma - mark PeerConnection

- (nullable TLConversationConnection *)startOutgoingWithTimestamp:(int64_t)now twinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ startOutgoingWithTimestamp %lld", LOG_TAG, now);

    if (self.connection) {
        if ([self.connection canStartOutgoingWithTimestamp:now]) {
            return self.connection;
        } else {
            return nil;
        }
    }

    // Outgoing P2P is accepted, create the connection instance.
    self.connection = [[TLConversationConnection alloc] initWithConversation:self twinlife:twinlife];
    return self.connection;
}

- (nullable TLConversationConnection *)acceptIncomingWithTimestamp:(int64_t)now twinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ acceptIncomingWithTimestamp %lld", LOG_TAG, now);
    
    // If one of the IN/OUT connection is opened, we are busy.
    if (self.connection) {
        TLAcceptIncomingConversationState result = [self.connection canAcceptIncomingWithTimestamp:now];
        if (result != TLAcceptIncomingConversationStateMaybe) {
            return result == TLAcceptIncomingConversationStateYes ? self.connection : nil;
        }

        TLTwincodeOutbound *twincodeOutbound = [self.subject twincodeOutbound];
        if (!twincodeOutbound) {
            return nil;
        }
        if ([twincodeOutbound.uuid compareTo:self.peerTwincodeOutboundId] < 0) {
            return nil;
        }
    }

    self.connection = [[TLConversationConnection alloc] initWithConversation:self twinlife:twinlife];
    return self.connection;
}
- (BOOL)isOpened {

    return self.connection != nil && [self.connection state] == TLConversationStateOpen;
}

- (void)closeConnection {
    DDLogVerbose(@"%@ closeConnection", LOG_TAG);
 
    self.connection = nil;
}

- (nonnull TLConversationConnection *)transferWithConnection:(nonnull TLConversationConnection*)connection twinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ transferWithConnection: %@", LOG_TAG, connection);

    TLConversationImpl *oldConversation = connection.conversation;
    self.connection = [connection transferConnectionWithConversation:self twinlife:twinlife];
    oldConversation.connection = nil;

    return self.connection;
}

- (NSString *)to {
    
    return self.peerTwincodeOutboundId.UUIDString;
}

- (nonnull NSString *)from {

    return [NSString stringWithFormat:@"%@/%@", self.twincodeOutboundId, self.resourceId];
}

- (void)touch {
    
    if (self.connection) {
        [self.connection touch];
    }
}

- (void)resetDelay {
    
    self.delay = 0;
    self.delayPos = 0;
    self.flags = self.flags & 0x0FF; // Clear the delayPos info from the flags.
}

- (void)nextDelayWithTerminateReason:(TLPeerConnectionServiceTerminateReason)terminateReason {
    
    switch (terminateReason) {
            // Long running error, retrying will not help, use the highest retry delay (GONE delay).
        case TLPeerConnectionServiceTerminateReasonGone:
        case TLPeerConnectionServiceTerminateReasonRevoked:
        case TLPeerConnectionServiceTerminateReasonNotAuthorized:
        case TLPeerConnectionServiceTerminateReasonNotEncrypted:
        case TLPeerConnectionServiceTerminateReasonNoPublicKey:
        case TLPeerConnectionServiceTerminateReasonNoPrivateKey:
        case TLPeerConnectionServiceTerminateReasonEncryptError:
        case TLPeerConnectionServiceTerminateReasonDecryptError:
            self.delayPos = BACKOFF_DELAYS_COUNT - 1;
            break;
            
            // Transient error, we can be more aggressive on the retry.
        case TLPeerConnectionServiceTerminateReasonBusy:
        case TLPeerConnectionServiceTerminateReasonDisconnected:
        case TLPeerConnectionServiceTerminateReasonSuccess:
            self.delayPos = 0;
            break;
        
            // No way to wakeup the peer
        case TLPeerConnectionServiceTerminateReasonCancel:

            // Connectivity error, use the backoff table.
        case TLPeerConnectionServiceTerminateReasonConnectivityError:
        case TLPeerConnectionServiceTerminateReasonUnknown:
        case TLPeerConnectionServiceTerminateReasonGeneralError:
        case TLPeerConnectionServiceTerminateReasonTimeout:

            // Other errors should not happen.
        case TLPeerConnectionServiceTerminateReasonDecline:
        default:
            // For the backoff table, exclude the last GONE entry and restart at 1.
            if (self.delayPos + 1 < BACKOFF_DELAYS_COUNT - 1) {
                self.delayPos++;
            } else {
                self.delayPos = 1;
            }
            break;
    }
    self.delay = BACKOFF_DELAYS[self.delayPos];
    self.flags = (self.delayPos << 8) | (self.flags & 0x0FF);
}

#pragma - mark NSObject

- (BOOL)isEqual:(nullable id)object {
    
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLConversationImpl class]]) {
        return NO;
    }
    TLConversationImpl* conversation = (TLConversationImpl *)object;
    return [conversation.uuid isEqual:self.uuid];
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    result = 31 * result + self.uuid.hash;
    return result;
}

- (void)appendTo:(nonnull NSMutableString*)string {
    
    [string appendFormat:@"%@ twincodeOutboundId=%@", self.databaseId, [self.twincodeOutboundId UUIDString]];
    [string appendFormat:@" peerTwincodeOutboundId: %@", [self.peerTwincodeOutboundId UUIDString]];
    [string appendFormat:@" twincodeInboundId: %@\n", [self.twincodeInboundId UUIDString]];
    [string appendFormat:@" subject: %@\n", self.subject];
    [string appendFormat:@" resourceId: %@", [self.resourceId UUIDString]];
    [string appendFormat:@" peerResourceId: %@\n", [self.peerResourceId UUIDString]];
    [string appendFormat:@" isActive: %@", self.isActive ? @"YES" : @"NO"];
    [string appendFormat:@" delay: %lld\n", self.delay];
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLConversation["];
    [self appendTo:string];
    [string appendString:@"]"];
    return string;
}

@end

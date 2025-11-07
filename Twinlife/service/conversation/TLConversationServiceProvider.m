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

#import "TLConversationServiceProvider.h"
#import "TLConversationServiceImpl.h"
#import "TLFilter.h"
#import "TLDatabase.h"

#import "TLTwinlifeImpl.h"
#import "TLConversationServiceImpl.h"
#import "TLConversationMigration.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLRepositoryServiceImpl.h"
#import "TLConversationImpl.h"
#import "TLGroupConversationImpl.h"
#import "TLClearDescriptorImpl.h"
#import "TLObjectDescriptorImpl.h"
#import "TLResetConversationOperation.h"
#import "TLSynchronizeConversationOperation.h"
#import "TLPushCommandOperation.h"
#import "TLPushGeolocationOperation.h"
#import "TLPushObjectOperation.h"
#import "TLPushFileOperation.h"
#import "TLPushTwincodeOperation.h"
#import "TLUpdateAnnotationsOperation.h"
#import "TLGroupInviteOperation.h"
#import "TLGroupJoinOperation.h"
#import "TLGroupLeaveOperation.h"
#import "TLGroupUpdateOperation.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLSerializerFactory.h"
#import "TLFileDescriptorImpl.h"
#import "TLGeolocationDescriptorImpl.h"
#import "TLImageDescriptorImpl.h"
#import "TLAudioDescriptorImpl.h"
#import "TLVideoDescriptorImpl.h"
#import "TLNamedFileDescriptorImpl.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLTwincodeDescriptorImpl.h"
#import "TLCallDescriptorImpl.h"
#import "TLUpdateDescriptorTimestampOperation.h"
#import "TLUpdateDescriptorOperation.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define CONVERSATION_LOCK_MAX_TIMEOUT (5 * 60 * 1000)

/**
 * conversation table:
 * id INTEGER: local database identifier (primary key)
 * uuid TEXT UNIQUE NOT NULL: conversation id
 * creationDate INTEGER NOT NULL: conversation creation date
 * subject INTEGER NOT NULL: the repository object key (allows to read the RepositoryObject)
 * groupId INTEGER: the group conversation key
 * invitedContact INTEGER: the repository object representing the invited contact
 * peerTwincodeOutbound INTEGER: the peer twincode outbound key (necessary for group member twincode)
 * resourceId TEXT: the resource UUID
 * peerResourceId TEXT: the peer resource UUID
 * permissions INTEGER: the peer's permissions
 * joinPermissions INTEGER DEFAULT 0: the join permissions for members.
 * lastConnectDate INTEGER: the last connection date
 * lastRetryDate INTEGER: the date of the last WebRTC connection retry
 * flags INTEGER DEFAULT 0: group and conversation state
 * lock INTEGER DEFAULT 0: exclusive lock to prevent multiple processes to create P2P connections.
 *
 * Note: id, uuid, creationDate, subject, groupId, invitedContact are readonly.
 */
#define CONVERSATION_TABLE \
        @"CREATE TABLE IF NOT EXISTS conversation (id INTEGER PRIMARY KEY," \
                " uuid TEXT UNIQUE NOT NULL, creationDate INTEGER NOT NULL," \
                " subject INTEGER NOT NULL, groupId INTEGER, invitedContact INTEGER, peerTwincodeOutbound INTEGER," \
                " resourceId TEXT, peerResourceId TEXT, permissions INTEGER DEFAULT 0," \
                " joinPermissions INTEGER DEFAULT 0, lastConnectDate INTEGER, lastRetryDate INTEGER," \
                " flags INTEGER DEFAULT 0, lock INTEGER DEFAULT 0" \
                ")"

/**
 * descriptor table:
 * id INTEGER: local database identifier (primary key)
 * cid INTEGER NOT NULL: the conversation id
 * sequenceId INTEGER NOT NULL: the descriptor sequence id
 * twincodeOutbound INTEGER NOT NULL: the twincode outbound key
 * sentTo INTEGER: the optional twincode outbound key for sentTo
 * replyTo INTEGER: the optional reply to
 * descriptorType INTEGER NOT NULL: the descriptor type
 * creationDate INTEGER NOT NULL: descriptor creation date
 * sendDate INTEGER: the send date
 * receiveDate INTEGER: the receive date
 * readDate INTEGER: the read date
 * updateDate INTEGER: the update date
 * peerDeleteDate INTEGER: the peer deletion date
 * deleteDate INTEGER: the description deletion date
 * expireTimeout INTEGER: the expiration timeout
 * flags INTEGER: the copy flags
 * value INTEGER: an integer value (length of file, clear timestamp, duration, ...)
 * content TEXT: the message or the descriptor information (serialized in text form)
 *
 * Note: id, cid, sequenceId, twincodeOutbound, sentTo, replyTo, descriptorType, creationDate are readonly.
 */
#define DESCRIPTOR_TABLE \
        @"CREATE TABLE IF NOT EXISTS descriptor (id INTEGER PRIMARY KEY," \
                " cid INTEGER NOT NULL, sequenceId INTEGER NOT NULL, twincodeOutbound INTEGER," \
                " sentTo INTEGER, replyTo INTEGER, descriptorType INTEGER NOT NULL," \
                " creationDate INTEGER, sendDate INTEGER, receiveDate INTEGER, readDate INTEGER," \
                " updateDate INTEGER, peerDeleteDate INTEGER, deleteDate INTEGER, expireTimeout INTEGER," \
                " flags INTEGER, value INTEGER, content TEXT" \
                ")"

#define DESCRIPTOR_INDEX \
        @"CREATE INDEX IF NOT EXISTS idx_descriptor_cid ON descriptor (cid, creationDate)"

/**
 * invitation table:
 * id INTEGER NOT NULL: the invitation id == descriptor key (primary key)
 * groupId INTEGER: the group conversation id
 * inviterMember INTEGER: the member twincode that made the invitation (note: this is our twincode within the group)
 * joinedMember INTEGER: the joined member twincode
 *
 * Note: id, groupId, inviterMember are readonly.
 */
#define INVITATION_TABLE \
        @"CREATE TABLE IF NOT EXISTS invitation (id INTEGER PRIMARY KEY," \
                " groupId INTEGER NOT NULL, inviterMember INTEGER NOT NULL, joinedMember INTEGER" \
                ")"

/**
 * annotation table:
 * cid INTEGER NOT NULL: the conversation key
 * descriptor INTEGER NOT NULL: the descriptor key
 * peerTwincodeOutbound INTEGER: the peer twincode key when the annotation is from a peer
 * creationDate INTEGER: the date when the annotation was created
 * notificationId INTEGER: the optional notification id
 * kind INTEGER NOT NULL: annotation kind
 * value INTEGER: annotation value
 *
 * Note: cid, descriptor, peerTwincodeOutbound, kind are readonly.
 */
#define ANNOTATION_TABLE \
        @"CREATE TABLE IF NOT EXISTS annotation (cid INTEGER NOT NULL, descriptor INTEGER NOT NULL," \
                " peerTwincodeOutbound INTEGER, kind INTEGER NOT NULL, value INTEGER, creationDate INTEGER," \
                " notificationId INTEGER, PRIMARY KEY(cid, descriptor, peerTwincodeOutbound, kind)" \
                ")"

/**
 * operation table:
 * id INTEGER: local database identifier (primary key)
 * creationDate INTEGER NOT NULL: operation creation date
 * cid INTEGER NOT NULL: conversation key
 * type INTEGER: operation type
 * descriptor INTEGER: the descriptor key
 * chunkStart INTEGER: the upload file chunk start.
 * content BLOB: the optional operation data.
 *
 */
#define OPERATION_TABLE \
        @"CREATE TABLE IF NOT EXISTS operation (id INTEGER PRIMARY KEY," \
                " creationDate INTEGER NOT NULL, cid INTEGER NOT NULL, type INTEGER," \
                " descriptor INTEGER, chunkStart INTEGER, content BLOB" \
                ")"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

//
// Interface: TLConversationDeleteInfo ()
//

@interface TLConversationDeleteInfo : NSObject

@property (readonly) NSNumber *cid;
@property (readonly) NSNumber *groupId;
@property (readonly) NSNumber *subjectId;

- (nonnull instancetype)initWithCid:(int64_t)cid groupId:(int64_t)groupId subjectId:(int64_t)subjectId;

@end

//
// Interface: TLConversationServiceProvider ()
//

@interface TLConversationServiceProvider ()

@property (readonly, nonnull) TLTwinlife *twinlife;
@property (readonly, nonnull) NSMapTable<TLDescriptorId *, TLDescriptor *> *descriptorCache;
@property (readonly, nonnull) TLConversationFactory *conversationFactory;
@property (readonly, nonnull) TLGroupConversationFactory *groupConversationFactory;
@property (readonly, nonnull) TLConversationService *conversationService;

@property FMDatabaseQueue *databaseQueue;

+ (int)fromOperationType:(TLConversationServiceOperationType)type;

@end

//
// Implementation: TLConversationDeleteInfo ()
//

@implementation TLConversationDeleteInfo : NSObject

- (nonnull instancetype)initWithCid:(int64_t)cid groupId:(int64_t)groupId subjectId:(int64_t)subjectId {
    
    self = [super init];
    if (self) {
        _cid = [NSNumber numberWithLongLong:cid];
        _groupId = [NSNumber numberWithLongLong:groupId];
        _subjectId = [NSNumber numberWithLongLong:subjectId];
    }
    return self;
}

@end

//
// Implementation: TLConversationServiceProvider
//

#undef LOG_TAG
#define LOG_TAG @"ConversationServiceProvider"

@implementation TLConversationServiceProvider

- (instancetype)initWithService:(nonnull TLConversationService *)service database:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@: initWithService: %@", LOG_TAG, service);
    
    self = [super initWithService:service database:database sqlCreate:CONVERSATION_TABLE table:TLDatabaseTableConversation];
    
    if (self) {
        _twinlife = service.twinlife;
        _conversationFactory = [[TLConversationFactory alloc] initWithDatabase:database];
        _groupConversationFactory = [[TLGroupConversationFactory alloc] initWithDatabase:database];
        _conversationService = service;
        
        // Cache of descriptors with weak objects.
        _descriptorCache = [NSMapTable strongToWeakObjectsMapTable];
    }
    return self;
}

- (void)onCreateWithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ onCreateWithTransaction: %@", LOG_TAG, transaction);
    
    [super onCreateWithTransaction:transaction];
    [transaction createSchemaWithSQL:DESCRIPTOR_TABLE];
    [transaction createSchemaWithSQL:DESCRIPTOR_INDEX];
    [transaction createSchemaWithSQL:INVITATION_TABLE];
    [transaction createSchemaWithSQL:ANNOTATION_TABLE];
    [transaction createSchemaWithSQL:OPERATION_TABLE];
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);
    
    /**
     * <pre>
     * Database Version 21
     *  Date: 2024/05/07
     *    Add columns creationDate and notificationId in the annotation table to record who annotates for the notification.
     *
     * Database Version 20
     *  Date: 2023/08/28
     *    New database schema optimized to allow loading repository objects and twincodes in a single SQL query.
     *
     * Database Version 13
     *  Date: 2022/02/25
     *
     *  ConversationService
     *   Update oldVersion [10]:
     *    Add table conversationDescriptorAnnotation
     *
     * Database Version 10
     *  Date: 2020/06/18:
     *   Update oldVersion [6,9]:
     *    Add column 'lock INTEGER' in table conversationConversation
     *    Add column 'lastConnectDate INTEGER' in table conversationConversation
     *    Add column 'groupId INTEGER' in table conversationConversation
     *    Add column 'cid INTEGER' in table conversationOperation
     *
     * Database Version 8
     *  Date: 2020/02/07
     *   Update oldVersion [6,7]:
     *    Add column 'createdTimestamp INTEGER' in table conversationDescriptor
     *    Add column 'cid INTEGER' in table conversationDescriptor
     *    Add column 'descriptorType INTEGER' in table conversationDescriptor
     *    Add column 'cid INTEGER' in table conversationConversation
     *   Update oldVersion [4,5]: -
     *   Update oldVersion [3]:
     *    Rename conversationObject table: conversationDescriptor
     *    Delete digest column from conversationDescriptor table
     *   Update oldVersion [0,2]: reset
     *
     * Database Version 6
     *  Date: 2017/04/27
     *
     *  ConversationService
     *   Upgrade oldVersion [4,5]: -
     *   Upgrade oldVersion [3]:
     *    Rename conversationObject table: conversationDescriptor
     *    Delete digest column from conversationDescriptor table
     *   Update oldVersion [0,2]: reset
     *
     * Database Version 5
     *  Date: 2017/04/20
     *
     *  ConversationService
     *   Upgrade oldVersion [4]: -
     *   Upgrade oldVersion [3]:
     *    Rename conversationObject table: conversationDescriptor
     *    Delete digest column from conversationDescriptor table
     *   Update oldVersion [0,2]: reset
     *
     * Database Version 4
     *  Date: 2016/10/13
     *
     *  ConversationService
     *   Upgrade oldVersion [3]:
     *    Rename conversationObject table: conversationDescriptor
     *    Delete digest column from conversationDescriptor table
     *   Update oldVersion [0,2]: reset
     *
     * Database Version 3
     *  Date: 2015/11/28
     *
     *  DirectoryService
     *   Upgrade oldVersion <= 2: reset
     *
     * </pre>
     */
    [self onCreateWithTransaction:transaction];
    if (oldVersion < 20) {
        TLConversationMigration *conversationMigration = [[TLConversationMigration alloc] initWithService:self.service database:self.database conversationFactory:self.conversationFactory];
        
        [conversationMigration upgradeWithTransaction:transaction oldVersion:oldVersion newVersion:newVersion];
    } else if (oldVersion == 20) {
        [transaction createSchemaWithSQL:@"ALTER TABLE annotation ADD COLUMN creationDate INTEGER"];
        [transaction createSchemaWithSQL:@"ALTER TABLE annotation ADD COLUMN notificationId INTEGER"];
    }
    
    // The conversation table was not updated when the pair::bind invocation was received.
    // Repair the conversation table where we should always have:
    //  <conversation>.peerTwincodeOutbound = <conversation>.subject.peerTwincodeOutbound
    // when the <conversation>.groupId is null.
    // See https://www.sqlite.org/lang_update.html for the UPDATE+FROM query (be careful if it must be changed!).
    if (oldVersion <= 24) {
        [transaction executeUpdate:@"UPDATE conversation AS c SET peerTwincodeOutbound=repo.peerId"
         " FROM (SELECT r.id AS id, r.peerTwincodeOutbound as peerId FROM repository AS r) AS repo"
         " WHERE c.groupId IS NULL AND c.subject=repo.id"];
    }
}

#if 0

// Uncomment the #if 0 to run again the conversation repair code.
- (void)onOpen {
    DDLogVerbose(@"%@ onOpen", LOG_TAG);
    
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE conversation AS c SET peerTwincodeOutbound=repo.peerId"
         " FROM (SELECT r.id AS id, r.peerTwincodeOutbound as peerId FROM repository AS r) AS repo"
         " WHERE c.groupId IS NULL AND c.subject=repo.id"];
        [transaction commit];
    }];
}
#endif

#pragma mark - TLConversationCleaner

- (void)deleteConversationsWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId {
    DDLogVerbose(@"%@ deleteConversationsWithTransaction: %@ subjectId: %@ twincodeId: %@", LOG_TAG, transaction, subjectId, twincodeId);
    
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"c.id, c.groupId, c.subject FROM conversation AS c"];
    [query filterNumber:twincodeId field:@"c.peerTwincodeOutbound"];
    [query filterNumber:subjectId field:@"c.subject"];
    
    // Keep the list of conversation to delete in a list.  For a group, we get the group as well as all its members.
    // (because we are going to remove them and we can't iterate at the same time).
    NSMutableArray<TLConversationDeleteInfo *> *toDelete = [[NSMutableArray alloc] init];
    FMResultSet *resultSet = [transaction executeWithQuery:query];
    if (resultSet) {
        while ([resultSet next]) {
            long cid = [resultSet longLongIntForColumnIndex:0];
            long groupId = [resultSet longLongIntForColumnIndex:1];
            long subjectId = [resultSet longLongIntForColumnIndex:2];
            
            [toDelete addObject:[[TLConversationDeleteInfo alloc] initWithCid:cid groupId:groupId subjectId:subjectId]];
        }
        [resultSet close];
    }
    
    NSMutableArray<TLConversationImpl *> *deleteList = [[NSMutableArray alloc] init];
    for (TLConversationDeleteInfo *deleteInfo in toDelete) {
        TLDatabaseIdentifier *identifier;
        if (deleteInfo.groupId.longLongValue > 0 && deleteInfo.cid.longLongValue != deleteInfo.groupId.longLongValue) {
            [self internalDeleteGroupMemberConversationWithTransaction:transaction subjectId:deleteInfo.subjectId conversationId:deleteInfo.cid groupId:deleteInfo.subjectId twincodeId:twincodeId];
            identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:deleteInfo.cid.longLongValue factory:self.groupConversationFactory];
        } else {
            [self internalDeleteConversationWithTransaction:transaction subjectId:deleteInfo.subjectId conversationId:deleteInfo.cid];
            identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:deleteInfo.cid.longLongValue factory:(deleteInfo.groupId.longLongValue == deleteInfo.cid.longLongValue ? self.groupConversationFactory : self.conversationFactory)];
        }
        
        id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
        if (object) {
            [self.database evictCacheWithIdentifier:identifier];
            
            if ([object isKindOfClass:[TLConversationImpl class]]) {
                [deleteList addObject:(TLConversationImpl *)object];
            }
        }
    }
    
    if (deleteList.count > 0) {
        [self.conversationService notifyDeletedConversationWithList:deleteList];
    }
}

#pragma mark - Conversations

- (nonnull NSMutableArray<id<TLConversation>> *)listConversationsWithFilter:(nullable TLFilter *)filter {
    DDLogVerbose(@"%@ listConversationsWithFilter: %@", LOG_TAG, filter);

    TL_DECL_START_MEASURE(startTime)

    NSMutableArray<id<TLConversation>> *result = [[NSMutableArray alloc] init];
    __block NSMutableArray<TLConversationDeleteInfo *> *toDeleteList = nil;
    [self inDatabase:^(FMDatabase *database) {
        // Notes:
        // - use a sub-select for perf reasons on the descriptors (it is quite efficient due to
        //   the idx_descriptor_cid index, and more effecient than a COUNT(d.id) combined with
        //   a left join when we have a lot of descriptors, with fiew descriptors, the left join
        //   approach is faster).
        // - use use a LEFT JOIN on repository to find dead conversations.
        TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"c.id, c.groupId, c.uuid, c.creationDate,"
                                 " c.subject, r.schemaId, c.peerTwincodeOutbound, c.resourceId, c.peerResourceId,"
                                 " c.permissions, c.joinPermissions, c.lastConnectDate, c.lastRetryDate, c.flags,"
                                 " (SELECT COUNT(d.id) FROM descriptor AS d WHERE c.id=d.cid)"
                                 " FROM conversation AS c LEFT JOIN repository AS r ON c.subject = r.id"];
        
        [query filterWhere:@"(c.groupId IS NULL OR c.id = c.groupId)"];
        if (filter) {
            [query filterOwner:filter.owner field:@"r.owner"];
            [query filterName:filter.name field:@"r.name"];
        }
        
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            return;
        }
        
        while ([resultSet next]) {
            id<TLConversation> conversation = [self loadConversationWithCursor:resultSet];
            if (conversation) {
                if (!filter || !filter.acceptWithObject || filter.acceptWithObject(conversation)) {
                    [result addObject:conversation];
                }
            } else {
                if (!toDeleteList) {
                    toDeleteList = [[NSMutableArray alloc] init];
                }
                long cid = [resultSet longLongIntForColumnIndex:0];
                long groupId = [resultSet longLongIntForColumnIndex:1];
                long subjectId = [resultSet longLongIntForColumnIndex:4];
                [toDeleteList addObject:[[TLConversationDeleteInfo alloc] initWithCid:cid groupId:groupId subjectId:subjectId]];
            }
        }
        [resultSet close];
    }];
    
    // Some conversations are now invalid (RepositoryObject was removed or became invalid).
    // Remove the conversation, its operations, descriptors, annotations.
    if (toDeleteList) {
        [self inTransaction:^(TLTransaction *transaction) {
            for (TLConversationDeleteInfo *deleteInfo in toDeleteList) {
                if (deleteInfo.groupId.longLongValue > 0 && deleteInfo.cid.longLongValue != deleteInfo.groupId.longLongValue) {
                    [self internalDeleteGroupMemberConversationWithTransaction:transaction subjectId:deleteInfo.subjectId conversationId:deleteInfo.cid groupId:deleteInfo.groupId twincodeId:nil];
                } else {
                    [self internalDeleteConversationWithTransaction:transaction subjectId:deleteInfo.subjectId conversationId:deleteInfo.cid];
                }
            }
            [transaction commit];
        }];
    }
    TL_END_MEASURE(startTime, @"ConversationService loadConversations")
    return result;
}

- (nullable id <TLConversation>)loadConversationWithId:(int64_t)conversationId {
    DDLogVerbose(@"%@ loadConversationWithConversationId: %lld", LOG_TAG, conversationId);
    
    // Look in the cache for the Contact conversation.
    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:conversationId factory:self.conversationFactory];
    id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
    if (object) {
        return (id<TLConversation>) object;
    }
    
    // Likewise for a Group conversation.
    identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:conversationId factory:self.groupConversationFactory];
    object = [self.database getCacheWithIdentifier:identifier];
    if (object) {
        return (id<TLConversation>) object;
    }
    
    // We must load it from the database: we can find a Contact conversation or a GroupConversation.
    id<TLConversation> conversation = [self internalLoadConversationWithId:[identifier identifierNumber]];
    
    // If the asked database id corresponds to the conversation which is loaded, return it.
    if (!conversation || conversation.identifier.identifier == conversationId) {
        return conversation;
    }
    
    if (![conversation isKindOfClass:[TLGroupConversationImpl class]]) {
        return nil;
    }
    
    // The cid corresponds to a group member and we must find it because we loaded the full GroupConversation.
    TLGroupConversationImpl *groupConversation = (TLGroupConversationImpl *)conversation;
    return [groupConversation getConversationWithId:conversationId];
}

- (nullable id <TLConversation>)loadConversationWithSubject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ loadConversationWithSubject: %@", LOG_TAG, subject);
    
    NSString *query = @"SELECT c.id, c.groupId, c.uuid, c.creationDate, c.subject, r.schemaId,"
    " c.peerTwincodeOutbound, c.resourceId, c.peerResourceId, c.permissions,"
    " c.joinPermissions, c.lastConnectDate, c.lastRetryDate, c.flags,"
    " (SELECT COUNT(d.id) FROM descriptor AS d WHERE c.id=d.cid)"
    " FROM conversation AS c"
    " INNER JOIN repository AS r ON c.subject = r.id"
    " WHERE c.subject=? AND (c.groupId IS NULL OR c.id = c.groupId)";
    return [self loadConversationWithQuery:query param1:[subject.identifier identifierNumber] param2:nil];
}

- (nullable id <TLConversation>)internalLoadConversationWithId:(nonnull NSNumber *)conversationId {
    DDLogVerbose(@"%@ internalLoadConversationWithId: %@", LOG_TAG, conversationId);
    
    // Load a conversation by its conversation Id.  If this is a group member conversation id,
    // we must get the GroupConversation.  The first condition matches the contact conversation and
    // the second condition matches the group member conversation and then matches in C1 the group
    // conversation that we must return.  Use a sub-select for perf reasons on the descriptors.
    NSString *query = @"SELECT c1.id, c1.groupId, c1.uuid, c1.creationDate, c1.subject, r.schemaId,"
    " c1.peerTwincodeOutbound, c1.resourceId, c1.peerResourceId, c1.permissions,"
    " c1.joinPermissions, c1.lastConnectDate, c1.lastRetryDate, c1.flags,"
    " (SELECT COUNT(d.id) FROM descriptor AS d WHERE c1.id=d.cid)"
    " FROM conversation AS c1"
    " INNER JOIN repository AS r ON c1.subject = r.id"
    " LEFT JOIN conversation AS c2"
    " WHERE (c1.id=? AND c1.groupId IS NULL AND c1.id=c2.id) OR (c1.id=c2.groupId AND c2.id=?)";
    
    return [self loadConversationWithQuery:query param1:conversationId param2:conversationId];
}

- (nullable id<TLConversation>)loadConversationWithCursor:(nonnull FMResultSet *)resultSet {
    DDLogVerbose(@"%@ loadConversationWithCursor: %@", LOG_TAG, resultSet);
    
    id<TLDatabaseObject> result;
    long cid = [resultSet longForColumnIndex:0];
    long group = [resultSet longForColumnIndex:1];
    if (group == cid) {
        TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.groupConversationFactory];
        id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
        if (!object) {
            result = [self.groupConversationFactory createObjectWithIdentifier:identifier cursor:resultSet offset:2];
            if (result) {
                [self.database putCacheWithObject:result];
            }
        } else {
            result = object;
            [self.groupConversationFactory loadWithObject:result cursor:resultSet offset:2];
        }
    } else {
        TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.conversationFactory];
        id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
        if (!object) {
            result = [self.conversationFactory createObjectWithIdentifier:identifier cursor:resultSet offset:2];
            if (result) {
                [self.database putCacheWithObject:result];
            }
        } else {
            result = object;
            [self.conversationFactory loadWithObject:result cursor:resultSet offset:2];
        }
    }
    return (id<TLConversation>) result;
}

- (nullable id <TLConversation>)loadConversationWithQuery:(nonnull NSString *)query param1:(nonnull NSObject *)param1 param2:(nullable NSObject *)param2 {
    DDLogVerbose(@"%@ loadConversationWithQuery: %@ param1: %@ param2: %@", LOG_TAG, query, param1, param2);
    
    __block id<TLConversation> conversation = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }
        
        FMResultSet *resultSet = [database executeQuery:query, param1, param2];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if ([resultSet next]) {
            conversation = [self loadConversationWithCursor:resultSet];
        }
        [resultSet close];
    }];
    
    return conversation;
}

- (nullable TLConversationImpl *)createConversationWithSubject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ createConversationWithSubject: %@", LOG_TAG, subject);
    
    __block TLConversationImpl *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *subjectId = [subject.identifier identifierNumber];
        long cid = [transaction longForQuery:@"SELECT c.id FROM conversation AS c WHERE c.subject=?", subjectId];
        if (cid > 0) {
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.conversationFactory];
            id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
            if (object) {
                result = (TLConversationImpl *)object;
            } else {
                result = [self loadConversationWithId:cid];
            }
        } else {
            cid = [transaction allocateIdWithTable:TLDatabaseTableConversation];
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.conversationFactory];
            NSUUID *conversationId = [NSUUID UUID];
            NSUUID *resourceId = [NSUUID UUID];
            TLTwincodeOutbound *peerTwincodeOutbound = [subject peerTwincodeOutbound];
            int64_t creationDate = [[NSDate date] timeIntervalSince1970] * 1000;
            
            NSObject *peerTwincode = peerTwincodeOutbound && [subject canCreateP2P] ? [peerTwincodeOutbound.identifier identifierNumber] : [NSNull alloc];
            TLConversationImpl *conversation = [[TLConversationImpl alloc] initWithIdentifier:identifier conversationId:conversationId subject:subject creationDate:creationDate resourceId:resourceId peerResourceId:nil permissions:-1L lastConnectDate:0 lastRetryDate:0 flags:0];
            [transaction executeUpdate:@"INSERT INTO conversation (id, uuid, subject, creationDate,"
             " peerTwincodeOutbound, resourceId, permissions,"
             " flags) VALUES(?, ?, ?, ?, ?, ?, -1, 0)", [identifier identifierNumber], [TLDatabaseService toObjectWithUUID:conversationId], subjectId, [NSNumber numberWithLongLong:creationDate], peerTwincode, [TLDatabaseService toObjectWithUUID:resourceId]];
            [transaction commit];
            [self.database putCacheWithObject:conversation];
            result = conversation;
        }
    }];
    return result;
}

- (nullable TLGroupConversationImpl *)createGroupConversationWithSubject:(nonnull id<TLRepositoryObject>)subject isOwner:(BOOL)isOwner {
    DDLogVerbose(@"%@ createGroupConversationWithSubject: %@ isOwner: %d", LOG_TAG, subject, isOwner);
    
    TLTwincodeOutbound *peerTwincodeOutbound = [subject peerTwincodeOutbound];
    if (!peerTwincodeOutbound) {
        return nil;
    }
    __block TLGroupConversationImpl *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *subjectId = [subject.identifier identifierNumber];
        long cid = [transaction longForQuery:@"SELECT c.id FROM conversation"
                    " AS c WHERE c.subject=? AND (c.id=c.groupId OR c.groupId IS NULL)", subjectId];
        if (cid > 0) {
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.groupConversationFactory];
            id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
            if (object && [object isKindOfClass:[TLGroupConversationImpl class]]) {
                result = (TLGroupConversationImpl *)object;
            } else {
                result = (TLGroupConversationImpl *)[self loadConversationWithId:cid];
            }
        } else {
            cid = [transaction allocateIdWithTable:TLDatabaseTableConversation];
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.groupConversationFactory];
            NSUUID *conversationId = [NSUUID UUID];
            NSUUID *resourceId = [NSUUID UUID];
            int64_t creationDate = [[NSDate date] timeIntervalSince1970] * 1000;
            
            NSObject *peerTwincode = peerTwincodeOutbound ? [peerTwincodeOutbound.identifier identifierNumber] : [NSNull alloc];
            TLGroupConversationImpl *conversation = [[TLGroupConversationImpl alloc] initWithIdentifier:identifier conversationId:conversationId subject:subject creationDate:creationDate resourceId:resourceId permissions:-1L joinPermissions:-1L flags:0];
            if (isOwner) {
                [conversation joinWithPermissions:-1L];
            }
            [transaction executeUpdate:@"INSERT INTO conversation (id, groupId, uuid, subject, creationDate,"
             " peerTwincodeOutbound, resourceId, permissions, joinPermissions,"
             " flags) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [identifier identifierNumber], [identifier identifierNumber], [TLDatabaseService toObjectWithUUID:conversationId], subjectId, [NSNumber numberWithLongLong:creationDate], peerTwincode, [TLDatabaseService toObjectWithUUID:resourceId], [NSNumber numberWithLongLong:conversation.permissions], [NSNumber numberWithLongLong:conversation.joinPermissions], [NSNumber numberWithInt:conversation.flags]];
            [transaction commit];
            [self.database putCacheWithObject:conversation];
            result = conversation;
        }
    }];
    return result;
}

- (nullable TLGroupMemberConversationImpl *)createGroupMemberWithConversation:(nonnull TLGroupConversationImpl *)groupConversation memberTwincodeId:(nonnull NSUUID *)memberTwincodeId permissions:(int64_t)permissions invitedContactId:(nullable NSUUID *)invitedContactId {
    DDLogVerbose(@"%@ createGroupMemberWithConversation: %@ memberTwincodeId: %@ permissions: %lld", LOG_TAG, groupConversation, memberTwincodeId, permissions);
    
    __block TLGroupMemberConversationImpl *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *groupId = [groupConversation.identifier identifierNumber];
        long cid = [transaction longForQuery:@"SELECT"
                    " c.id"
                    " FROM conversation AS c INNER JOIN twincodeOutbound AS twout ON c.peerTwincodeOutbound=twout.id"
                    " WHERE c.groupId=? AND twout.twincodeId=?", groupId, [TLDatabaseService toObjectWithUUID:memberTwincodeId]];
        if (cid > 0) {
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.groupConversationFactory];
            id<TLDatabaseObject> object = [self.database getCacheWithIdentifier:identifier];
            if (object && [object isKindOfClass:[TLGroupMemberConversationImpl class]]) {
                result = (TLGroupMemberConversationImpl *)object;
                return;
            }
            object = [self loadConversationWithId:cid];
            if (object && [object isKindOfClass:[TLGroupMemberConversationImpl class]]) {
                [transaction executeUpdate:@"UPDATE conversation SET permissions=? WHERE id=?", [NSNumber numberWithLongLong:permissions], [NSNumber numberWithLongLong:cid]];
                [transaction commit];
                result = (TLGroupMemberConversationImpl *)object;
            }
        } else {
            // Too many members or pending invitation in the group, refuse the invitation.
            if ([groupConversation activeMemberCount] > CONVERSATION_MAX_GROUP_MEMBERS) {
                return;
            }
            
            TLTwincodeOutbound *memberTwincodeOutbound = [transaction loadOrStoreTwincodeOutboundId:memberTwincodeId];
            if (!memberTwincodeOutbound) {
                return;
            }
            
            cid = [transaction allocateIdWithTable:TLDatabaseTableConversation];
            TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self.groupConversationFactory];
            NSUUID *conversationId = [NSUUID UUID];
            NSUUID *resourceId = [NSUUID UUID];
            int64_t creationDate = [[NSDate date] timeIntervalSince1970] * 1000;
            
            TLGroupMemberConversationImpl *conversation = [[TLGroupMemberConversationImpl alloc] initWithIdentifier:identifier conversationId:conversationId group:groupConversation creationDate:creationDate resourceId:resourceId peerResourceId:nil permissions:permissions lastConnectDate:0 lastRetryDate:0 flags:0 peerTwincodeOutbound:memberTwincodeOutbound invitedContactId:invitedContactId];
            
            [transaction executeUpdate:@"INSERT INTO conversation (id, groupId, uuid, subject, creationDate,"
             " peerTwincodeOutbound, resourceId, permissions,"
             " flags) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)", [identifier identifierNumber], groupId, [TLDatabaseService toObjectWithUUID:conversationId], [groupConversation.subject.identifier identifierNumber], [NSNumber numberWithLongLong:creationDate], [memberTwincodeOutbound.identifier identifierNumber], [TLDatabaseService toObjectWithUUID:resourceId], [NSNumber numberWithLongLong:conversation.permissions], [NSNumber numberWithInt:conversation.flags]];
            [transaction commit];
            [groupConversation addMemberWithConversation:conversation];
            [self.database putCacheWithObject:conversation];
            result = conversation;
        }
    }];
    return result;
}

- (void)updateConversation:(nonnull TLConversationImpl *)conversation {
    DDLogVerbose(@"%@ updateConversation: %@", LOG_TAG, conversation);
    
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE conversation SET permissions=?, lastConnectDate=?,"
         " lastRetryDate=?, flags=?, peerResourceId=? WHERE id=?", [NSNumber numberWithLongLong:conversation.permissions], [NSNumber numberWithLongLong:conversation.lastConnectTime], [NSNumber numberWithLongLong:conversation.lastRetryTime], [NSNumber numberWithInt:conversation.flags], [TLDatabaseService toObjectWithUUID:conversation.peerResourceId], [conversation.identifier identifierNumber]];
        [transaction commit];
    }];
}

- (void)updateConversation:(nonnull TLConversationImpl *)conversation peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ updateConversation: %@ peerTwincodeOutbound: %@", LOG_TAG, conversation, peerTwincodeOutbound);
    
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE conversation SET peerTwincodeOutbound=? WHERE id=?", [peerTwincodeOutbound.identifier identifierNumber], [conversation.identifier identifierNumber]];
        [transaction commit];
    }];
}

- (void)updateGroupConversation:(nonnull TLGroupConversationImpl *)conversation {
    DDLogVerbose(@"%@ updateGroupConversation: %@", LOG_TAG, conversation);
    
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE conversation SET permissions=?, joinPermissions=?,"
         " flags=? WHERE id=?", [NSNumber numberWithLongLong:conversation.permissions], [NSNumber numberWithLongLong:conversation.joinPermissions], [NSNumber numberWithInt:conversation.flags], [conversation.databaseId identifierNumber]];

        // If we are leaving the group, remove the associated invitations immediately because the group
        // is no longer visible in the UI (we still have the GroupConversation until every member is notified).
        // We also remove any notification related to that group now to prevent re-entering in the group.
        if ([conversation state] == TLGroupConversationStateLeaving) {
            [self internalDeleteGroupInvitationsWithTransaction:transaction subjectId:[conversation.subject.identifier identifierNumber] conversationId:[conversation.identifier identifierNumber]];
            [transaction deleteNotificationsWithSubjectId:[conversation.subject.identifier identifierNumber] twincodeId:nil descriptorId:nil];
        }
        [transaction commit];
    }];
}

- (nullable TLGroupConversationImpl *)findGroupWithTwincodeId:(nonnull NSUUID *)twincodeId {
    DDLogVerbose(@"%@ findGroupWithTwincodeId: %@", LOG_TAG, twincodeId);
    
    NSString *query = @"SELECT c.id, c.groupId, c.uuid, c.creationDate, c.subject, r.schemaId,"
      " c.peerTwincodeOutbound, c.resourceId, c.peerResourceId, c.permissions,"
      " c.joinPermissions, c.lastConnectDate, c.lastRetryDate, c.flags FROM conversation AS c"
      " INNER JOIN repository AS r ON c.subject = r.id"
      " INNER JOIN twincodeOutbound AS peerTwout ON r.peerTwincodeOutbound = peerTwout.id"
      " WHERE peerTwout.twincodeId=? AND c.id = c.groupId";

    id<TLConversation> conversation = [self loadConversationWithQuery:query param1:[TLDatabaseService toObjectWithUUID:twincodeId] param2:nil];
    if (!conversation) {
        return nil;
    }
    return (TLGroupConversationImpl *)conversation;
}

- (void)deleteConversationWithConversation:(nonnull id <TLConversation>)conversation {
    DDLogVerbose(@"%@ deleteConversationWithConversation: %@", LOG_TAG, conversation);
    
    [self inTransaction:^(TLTransaction *transaction) {
        TLDatabaseIdentifier *identifier = [conversation identifier];
        NSNumber *subjectId = [conversation.subject.identifier identifierNumber];
        NSNumber *cid = [identifier identifierNumber];
        if ([conversation isKindOfClass:[TLGroupMemberConversationImpl class]]) {
            TLGroupMemberConversationImpl *groupMemberConversation = (TLGroupMemberConversationImpl *)conversation;
            // Delete only the group member descriptors and their notifications (if we know the twincode!)
            TLTwincodeOutbound *peerTwincodeOutbound = groupMemberConversation.peerTwincodeOutbound;
            NSNumber *twincodeId = peerTwincodeOutbound ? [peerTwincodeOutbound.identifier identifierNumber] : nil;
            NSNumber *groupId = [groupMemberConversation.mainConversation.identifier identifierNumber];
            [self internalDeleteGroupMemberConversationWithTransaction:transaction subjectId:subjectId conversationId:cid groupId:groupId twincodeId:twincodeId];
            if (peerTwincodeOutbound) {
                [transaction deleteTwincodeWithTwincodeOutbound:peerTwincodeOutbound];
            }
        } else {
            [self internalDeleteConversationWithTransaction:transaction subjectId:subjectId conversationId:cid];
            
            // Delete the invitations that allowed us to join this group.
            if ([conversation isKindOfClass:[TLGroupConversationImpl class]]) {
                [self internalDeleteGroupInvitationsWithTransaction:transaction subjectId:subjectId conversationId:[conversation.identifier identifierNumber]];
            }
        }
        [transaction commit];
        [self.database evictCacheWithIdentifier:identifier];
    }];
}

- (void)internalDeleteConversationWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nonnull NSNumber *)subjectId conversationId:(nonnull NSNumber *)conversationId {
    DDLogVerbose(@"%@ internalDeleteConversationWithTransaction: %@ subjectId: %@ conversationId: %@", LOG_TAG, conversationId, subjectId, conversationId);

    [transaction executeUpdate:@"DELETE FROM operation WHERE cid=?", conversationId];
    [transaction executeUpdate:@"DELETE FROM invitation WHERE id IN (SELECT invitation.id FROM invitation"
            " INNER JOIN descriptor ON invitation.id=descriptor.id WHERE descriptor.cid=?)", conversationId];
    [transaction executeUpdate:@"DELETE FROM annotation WHERE cid=?", conversationId];
    [transaction executeUpdate:@"DELETE FROM descriptor WHERE cid=?", conversationId];
    [transaction deleteWithDatabaseId:conversationId.longLongValue table:TLDatabaseTableConversation];
    [transaction deleteNotificationsWithSubjectId:subjectId twincodeId:nil descriptorId:nil];
}

- (void)internalDeleteGroupMemberConversationWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nonnull NSNumber *)subjectId conversationId:(nonnull NSNumber *)conversationId groupId:(nonnull NSNumber *)groupId twincodeId:(nullable NSNumber *)twincodeId {
    DDLogVerbose(@"%@ internalDeleteGroupMemberConversationWithTransaction: %@ subjectId: %@ conversationId: %@ groupId: %@ twincodeId: %@", LOG_TAG, conversationId, subjectId, conversationId, groupId, twincodeId);
    
    // When the group member's twincode is not known, try to get the peer twincode from the conversation.
    if (twincodeId == nil) {
        twincodeId = [NSNumber numberWithLong:[transaction longForQuery:@"SELECT peerTwincodeOutbound FROM conversation"
                                               " WHERE id=?", conversationId]];
    }
    if (twincodeId != nil) {
        [transaction executeUpdate:@"DELETE FROM invitation WHERE id IN (SELECT invitation.id FROM invitation"
         " INNER JOIN descriptor ON invitation.id=descriptor.id WHERE descriptor.cid=? AND descriptor.twincodeOutbound=?)", conversationId, twincodeId];
        [transaction executeUpdate:@"DELETE FROM annotation WHERE cid=? AND peerTwincodeOutbound=?", conversationId, twincodeId];
        [transaction executeUpdate:@"DELETE FROM descriptor WHERE cid=? AND twincodeOutbound=?", conversationId, twincodeId];
        [transaction deleteNotificationsWithSubjectId:subjectId twincodeId:twincodeId descriptorId:nil];
    }
    [transaction executeUpdate:@"DELETE FROM operation WHERE cid=?", conversationId];
    [transaction deleteWithDatabaseId:conversationId.longLongValue table:TLDatabaseTableConversation];
}

- (void)internalDeleteGroupInvitationsWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nonnull NSNumber *)subjectId conversationId:(nonnull NSNumber *)conversationId {
    DDLogVerbose(@"%@ internalDeleteGroupInvitationsWithTransaction: %@ subjectId: %@ conversationId: %@", LOG_TAG, conversationId, subjectId, conversationId);

    NSArray<NSNumber *> *ids = [transaction listIdsWithSQL:@"SELECT id FROM invitation WHERE groupId=?", conversationId];
    if (ids && ids.count > 0) {
        [transaction deleteWithList:ids table:TLDatabaseTableInvitation];
        [transaction deleteWithList:ids table:TLDatabaseTableDescriptor];
        for (NSNumber *did in ids) {
            [transaction deleteNotificationsWithSubjectId:subjectId twincodeId:nil descriptorId:did];
        }
    }
}

- (int64_t)lockConversation:(nonnull TLConversationImpl *)conversation lockIdentifier:(int)lockIdentifier now:(int64_t)now {
    DDLogVerbose(@"%@ lockConversation: %@ identifier: %d now: %lld", LOG_TAG, conversation, lockIdentifier, now);
    
    if (conversation == nil) {
        return 0;
    }
    
    __block int64_t lastConnectDate = now;
    [self inTransaction:^(TLTransaction *transaction) {
        int64_t ignoreOlderDate = lastConnectDate - CONVERSATION_LOCK_MAX_TIMEOUT;
        NSNumber *lockNumber = [NSNumber numberWithInt:lockIdentifier];
        NSNumber *cid = [conversation.identifier identifierNumber];
        [transaction executeUpdate:@"UPDATE conversation SET lock=?, lastConnectDate=?"
         " WHERE id=? AND (lock=0 OR lock=? OR lastConnectDate < ?)", lockNumber, [NSNumber numberWithLongLong:lastConnectDate], cid, lockNumber, [NSNumber numberWithLongLong:ignoreOlderDate]];
        if ([transaction changes] == 0) {
            // Look and check if we can steal the lock.
            FMResultSet *resultSet = [transaction executeQuery:@"SELECT lock, lastConnectDate FROM conversation WHERE id=?", cid];
            if (resultSet && [resultSet next]) {
                int currentLock = [resultSet intForColumnIndex:0];
                int64_t lockDate = [resultSet longLongIntForColumnIndex:1];
                if (![self.twinlife isProcessActive:currentLock date:lockDate]) {
                    [transaction executeUpdate:@"UPDATE conversation SET lock=?, lastConnectDate=?"
                     " WHERE id=? AND (lock=? OR lastConnectDate < ?)", lockNumber, [NSNumber numberWithLongLong:lastConnectDate], cid, [NSNumber numberWithInt:currentLock], [NSNumber numberWithLongLong:ignoreOlderDate]];
                    if ([transaction changes] == 0) {
                        lastConnectDate = 0;
                    } else {
                        DDLogVerbose(@"%@ conversation lock %@ was stealed to %d now: %lld", LOG_TAG, conversation, currentLock, now);
                    }

                } else {
                    lastConnectDate = 0;
                }
            } else {
                // Update failed: lock is already taken by another process.
                lastConnectDate = 0;
            }
        }
        [transaction commit];
    }];
    return lastConnectDate;
}

- (int64_t)unlockConversation:(nonnull TLConversationImpl *)conversation lockIdentifier:(int)lockIdentifier connected:(BOOL)connected {
    DDLogVerbose(@"%@ unlockConversation: %@ lockIdentifier: %d connected: %d", LOG_TAG, conversation, lockIdentifier, connected);
    
    if (conversation == nil) {
        return 0;
    }
    
    __block int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *lockNumber = [NSNumber numberWithInt:lockIdentifier];
        NSNumber *cid = [conversation.identifier identifierNumber];
        if (connected) {
            [transaction executeUpdate:@"UPDATE conversation SET lock=0, lastConnectDate=?,"
             " lastRetryDate=0, flags=(flags & 0x0FF)"
             " WHERE id=? AND lock=?", [NSNumber numberWithLongLong:now], cid, lockNumber];
        } else {
            NSNumber *delayPos = [NSNumber numberWithInt:conversation.delayPos << 8];
            [transaction executeUpdate:@"UPDATE conversation SET lock=0, lastConnectDate=?,"
             " lastRetryDate=?, flags=(? + (flags & 0x0FF))"
             " WHERE id=? AND lock=?", [NSNumber numberWithLongLong:now], [NSNumber numberWithLongLong:now], delayPos, cid, lockNumber];
        }
        if ([transaction changes] == 0) {
            // Update failed: lock was released (lock was stealed due to timeout?).
            now = 0;
        }
        [transaction commit];
        if (now > 0) {
            conversation.lastConnectTime = now;
            conversation.lastRetryTime = connected ? 0 : now;
        }
    }];
    return now;
}

#pragma mark - Descriptors

- (int)countDescriptorsWithConversation:(nonnull id<TLConversation>)conversation {
    DDLogVerbose(@"%@ countDescriptorsWithConversation: %@", LOG_TAG, conversation);
    
    __block int count;
    [self inDatabase:^(FMDatabase *database) {
        NSNumber *cid = [conversation.identifier identifierNumber];
        count = [database intForQuery:@"SELECT COUNT(*) FROM descriptor WHERE cid=?", cid];
    }];
    return count;
}

- (nullable NSDictionary<NSUUID *, TLDescriptorId *> *)listDescriptorsToDeleteWithConversation:(nonnull id<TLConversation>)conversation twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId resetDate:(int64_t)resetDate {
    DDLogVerbose(@"%@ listDescriptorsToDeleteWithConversation: %@ resetDate: %lld", LOG_TAG, conversation, resetDate);
    
    NSMutableDictionary<NSUUID *, TLDescriptorId *> *result = [[NSMutableDictionary alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }
        
        TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"twout.twincodeId AS twincodeOutboundId,"
                                 " MAX(d.sequenceId) FROM descriptor AS d"
                                 " INNER JOIN twincodeOutbound AS twout ON d.twincodeOutbound=twout.id"];
        [query filterIdentifier:conversation.identifier field:@"d.cid"];
        [query filterBefore:resetDate field:@"d.creationDate"];
        if (twincodeOutboundId) {
            [query filterUUID:twincodeOutboundId field:@"twout.twincodeId"];
        } else {
            [query appendString:@"GROUP BY twout.twincodeId"];
        }
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            NSUUID *twincodeOutboundId = [resultSet uuidForColumnIndex:0];
            if (twincodeOutboundId) {
                result[twincodeOutboundId] = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:[resultSet longLongIntForColumnIndex:1]];
            }
        }
        [resultSet close];
    }];
    return result;
}

- (nullable NSArray<TLConversationDescriptorPair *> *)listLastConversationDescriptorsWithFilter:(nullable TLFilter *)filter callsMode:(TLDisplayCallsMode)callsMode {
    DDLogVerbose(@"%@ listLastConversationDescriptorsWithFilter: %@", LOG_TAG, filter);
    
    NSMutableArray<id<TLConversation>> *conversations = [self listConversationsWithFilter:filter];
    long count = conversations.count;
    NSMutableArray<NSNumber *> *list = [[NSMutableArray alloc] initWithCapacity:count];
    for (id<TLConversation> conversation in conversations) {
        [list addObject:[conversation.identifier identifierNumber]];
    }
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.cid, d.sequenceId, d.twincodeOutbound,"
                             " d.sentTo, replyTo.id, replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType,"
                             " d.creationDate, d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate,"
                             " d.deleteDate, d.expireTimeout, d.flags, d.content, d.value"
                             " FROM descriptor AS d"
                             " LEFT JOIN descriptor AS replyTo ON d.replyTo = replyTo.id"];
    [query appendString:@" WHERE d.id IN (SELECT id FROM (SELECT d2.id, ROW_NUMBER() OVER (PARTITION BY cid ORDER BY creationDate DESC) AS rn FROM descriptor AS d2"];
    [query filterInList:list field:@"d2.cid"];
    if (callsMode == TLDisplayCallsModeNone) {
        [query appendString:@" AND d2.descriptorType != 12"];
    } else if (callsMode == TLDisplayCallsModeMissed) {
        // Missed call descriptors have the 0x20 flag set and the 0x40 flag cleared (See CallDescriptorImpl).
        [query appendString:@" AND (d2.descriptorType != 12 OR (d2.flags & 0x60 = 0x20))"];
    }
    [query appendString:@") lastDescriptorId WHERE rn = 1)"];
    
    NSMutableArray<TLDescriptor *> *descriptors = [self internalListDescriptorWithQuery:query conversation:nil maxDescriptors:(int)count];
    NSMutableArray<TLConversationDescriptorPair *> *result = [[NSMutableArray alloc] initWithCapacity:count];
    for (long i = count; --i >= 0;) {
        id<TLConversation> conversation = conversations[i];
        int64_t conversationId = conversation.identifier.identifier;
        for (TLDescriptor *descriptor in descriptors) {
            if (descriptor.conversationId == conversationId) {
                [result addObject:[[TLConversationDescriptorPair alloc] initWithConversation:conversation descriptor:descriptor]];
                [descriptors removeObject:descriptor];
                [conversations removeObjectAtIndex:i];
                break;
            }
        }
    }
    for (id<TLConversation> conversation in conversations) {
        [result addObject:[[TLConversationDescriptorPair alloc] initWithConversation:conversation descriptor:nil]];
    }
    return result;
}

- (nullable NSArray<TLConversationDescriptorPair *> *)searchDescriptorsWithConversations:(nonnull NSArray<id<TLConversation>> *)conversations searchText:(nonnull NSString *)searchText beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ searchDescriptorsWithConversations: %@", LOG_TAG, searchText);

    NSMutableDictionary<NSNumber *, id<TLConversation>> *toConversation = [[NSMutableDictionary alloc] init];
    NSMutableArray<NSNumber *> *list = [[NSMutableArray alloc] initWithCapacity:conversations.count];
    for (id<TLConversation> conversation in conversations) {
        NSNumber *cid = [conversation.identifier identifierNumber];
        [list addObject:cid];
        [toConversation setObject:conversation forKey:cid];
    }

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.cid, d.sequenceId, d.twincodeOutbound,"
                             " d.sentTo, replyTo.id, replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType,"
                             " d.creationDate, d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate,"
                             " d.deleteDate, d.expireTimeout, d.flags, d.content, d.value"
                             " FROM descriptor AS d"
                             " LEFT JOIN descriptor AS replyTo ON d.replyTo = replyTo.id"];
    [query filterBefore:beforeTimestamp field:@"d.creationDate"];
    [query filterInList:list field:@"d.cid"];
    [query filterLong:2 field:@"d.descriptorType"];
    [query filterName:searchText field:@"d.content"];
    [query appendString:@" ORDER BY d.creationDate DESC"];
    [query limit:maxDescriptors];

    NSMutableArray<TLDescriptor *> *descriptors = [self internalListDescriptorWithQuery:query conversation:nil maxDescriptors:maxDescriptors];
    NSMutableArray<TLConversationDescriptorPair *> *result = [[NSMutableArray alloc] initWithCapacity:descriptors.count];
    for (TLDescriptor *descriptor in descriptors) {
        id<TLConversation> conversation = toConversation[[NSNumber numberWithLongLong:descriptor.conversationId]];
        if (conversation) {
            [result addObject:[[TLConversationDescriptorPair alloc] initWithConversation:conversation descriptor:descriptor]];
        }
    }

    return result;
}

- (nonnull NSMutableDictionary<NSUUID *, TLInvitationDescriptor *> *)listPendingInvitationsWithGroup:(nonnull id<TLRepositoryObject>)group {
    DDLogVerbose(@"%@ listPendingInvitationsWithGroup: %@", LOG_TAG, group);

    NSMutableDictionary<NSUUID *, TLInvitationDescriptor *> *result = [[NSMutableDictionary alloc] init];
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.cid, d.sequenceId, d.twincodeOutbound,"
                             " d.sentTo, replyTo.id, replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType,"
                             " d.creationDate, d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate,"
                             " d.deleteDate, d.expireTimeout, d.flags, d.content, d.value, r.uuid"
                             " FROM conversation AS g"
                             " INNER JOIN invitation AS i ON i.groupId=g.id"
                             " INNER JOIN descriptor AS d ON i.id = d.id"
                             " INNER JOIN twincodeOutbound AS twout ON twout.id=d.twincodeOutbound"
                             " INNER JOIN conversation AS c ON c.id=d.cid"
                             " INNER JOIN repository AS r ON c.subject=r.id"
                             " LEFT JOIN descriptor AS replyTo ON d.replyTo = replyTo.id"];
    [query filterLong:group.identifier.identifier field:@"g.subject"];
    [query appendString:@" AND d.value=0"];
    [self inDatabase:^(FMDatabase *database) {
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            return;
        }
        while ([resultSet next]) {
            NSUUID *contactId = [resultSet uuidForColumnIndex:20];

            if (contactId) {
                TLDescriptor *descriptor = [self loadDescriptorWithCursor:resultSet];
                if ([descriptor isKindOfClass:[TLInvitationDescriptor class]]) {
                    [result setObject:(TLInvitationDescriptor *)descriptor forKey:contactId];
                }
            }
        }
        [resultSet close];
    }];
    return result;
}

- (nonnull NSSet<NSUUID *> *)listDescriptorTwincodesWithConversation:(nullable id<TLConversation>)conversation descriptorType:(TLDescriptorType)descriptorType beforeTimestamp:(int64_t)beforeTimestamp {
    DDLogVerbose(@"%@ listDescriptorTwincodesWithConversation: %@ descriptorType: %d beforeTimestamp: %lld", LOG_TAG, conversation, descriptorType, beforeTimestamp);
    
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"DISTINCT twout.twincodeId"
                             " FROM descriptor AS d INNER JOIN twincodeOutbound AS twout ON d.twincodeOutbound=twout.id"];
    if (conversation) {
        [query filterIdentifier:conversation.identifier field:@"d.cid"];
    }
    [query filterBefore:beforeTimestamp field:@"d.creationDate"];
    if (descriptorType != TLDescriptorTypeDescriptor) {
        [query filterLong:[TLConversationServiceProvider fromDescriptorType:descriptorType] field:@"d.descriptorType"];
    }

    __block NSMutableSet<NSUUID *> *twincodes = [[NSMutableSet alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }
            
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }

        while ([resultSet next]) {
            NSUUID *uuid = [resultSet uuidForColumnIndex:0];
            if (uuid) {
                [twincodes addObject:uuid];
            }
        }
        [resultSet close];
    }];
    return twincodes;
}

- (nullable TLDescriptor *)loadDescriptorWithId:(int64_t)descriptorId {
    DDLogVerbose(@"%@ loadDescriptorWithId: %lld", LOG_TAG, descriptorId);

    // Reject 0 because filterLong will ignore it and we never use 0 as valid database id.
    if (descriptorId == 0) {
        return nil;
    }

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.cid, d.sequenceId, d.twincodeOutbound,"
                             " d.sentTo, replyTo.id, replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType,"
                             " d.creationDate, d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate,"
                             " d.deleteDate, d.expireTimeout, d.flags, d.content, d.value FROM descriptor AS d"
                             " LEFT JOIN descriptor AS replyTo ON d.replyTo = replyTo.id"];
    [query filterLong:descriptorId field:@"d.id"];

    return [self loadDescriptorWithQuery:query];
}

- (nullable TLDescriptor *)loadDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ loadDescriptorWithDescriptorId: %@", LOG_TAG, descriptorId);
    
    @synchronized (self) {
        // Get the descriptor from the cache: it may be used by a current operation.
        TLDescriptor *descriptor = [self.descriptorCache objectForKey:descriptorId];
        if (descriptor) {
            return descriptor;
        }
    }
    
    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.cid, d.sequenceId, d.twincodeOutbound,"
                             " d.sentTo, replyTo.id, replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType,"
                             " d.creationDate, d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate,"
                             " d.deleteDate, d.expireTimeout, d.flags, d.content, d.value FROM descriptor AS d"
                             " LEFT JOIN descriptor AS replyTo ON d.replyTo = replyTo.id"];
    if (descriptorId.id > 0) {
        [query filterLong:descriptorId.id field:@"d.id"];
    } else {
        [query appendString:@" INNER JOIN twincodeOutbound AS twout ON d.twincodeOutbound=twout.id"];
        [query filterLong:descriptorId.sequenceId field:@"d.sequenceId"];
        [query filterUUID:descriptorId.twincodeOutboundId field:@"twout.twincodeId"];
    }
    
    return [self loadDescriptorWithQuery:query];
}

- (nullable TLDescriptor *)loadDescriptorWithQuery:(nonnull TLQueryBuilder *)query {
    DDLogVerbose(@"%@ loadDescriptorWithQuery: %@", LOG_TAG, query);

    __block TLDescriptor *descriptor = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }

        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if ([resultSet next]) {
            descriptor = [self loadDescriptorWithCursor:resultSet];
        }
        [resultSet close];
        if (!descriptor) {
            return;
        }
  
        TLDescriptorId *descriptorId = descriptor.descriptorId;
        resultSet = [database executeQuery:@"SELECT kind, value, COUNT(*) FROM annotation WHERE"
                     " cid=? AND descriptor=? GROUP BY kind, value", [NSNumber numberWithLongLong:descriptor.conversationId], [NSNumber numberWithLongLong:descriptorId.id]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }

        NSMutableArray<TLDescriptorAnnotation *> *annotations = nil;
        while ([resultSet next]) {
            TLDescriptorAnnotationType type = [TLConversationServiceProvider toDescriptorAnnotationType:[resultSet intForColumnIndex:0]];
            if (type != TLDescriptorAnnotationTypeInvalid) {
                int value = [resultSet intForColumnIndex:1];
                int count = [resultSet intForColumnIndex:2];
                if (!annotations) {
                    annotations = [[NSMutableArray alloc] init];
                    descriptor.annotations = annotations;
                }
                [annotations addObject:[[TLDescriptorAnnotation alloc] initWithType:type value:value count:count]];
            }
        }
        [resultSet close];
    }];

    if (descriptor) {
        // Keep the descriptor in the cache: it will be released when there is no strong reference to it.
        @synchronized (self) {
            [self.descriptorCache setObject:descriptor forKey:descriptor.descriptorId];
        }
    }
    return descriptor;
}

- (nonnull NSArray<TLDescriptor *> *)listDescriptorWithConversation:(nullable id<TLConversation>)conversation types:(nullable NSArray<NSNumber *> *)types callsMode:(TLDisplayCallsMode)callsMode beforeTimestamp:(int64_t)beforeTimestamp maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ listDescriptorWithConversation: %@ types: %@ beforeTimestamp: %lld maxDescriptors: %d", LOG_TAG, conversation, types, beforeTimestamp, maxDescriptors);

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.cid, d.sequenceId, d.twincodeOutbound,"
                             " d.sentTo, replyTo.id, replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType,"
                             " d.creationDate, d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate,"
                             " d.deleteDate, d.expireTimeout, d.flags, d.content, d.value FROM descriptor AS d"
                             " LEFT JOIN descriptor AS replyTo ON d.replyTo = replyTo.id"];
    [query filterBefore:beforeTimestamp field:@"d.creationDate"];
    if (conversation != nil) {
        [query filterIdentifier:conversation.identifier field:@"d.cid"];
    }
    if (types) {
        [query filterWhere:[TLConversationServiceProvider filterWithTypes:types]];
    }
    if (callsMode == TLDisplayCallsModeNone) {
        [query appendString:@" AND d.descriptorType != 12"];
    } else if (callsMode == TLDisplayCallsModeMissed) {
        // Missed call descriptors have the 0x20 flag set and the 0x40 flag cleared (See CallDescriptorImpl).
        [query appendString:@" AND (d.descriptorType != 12 OR (d.flags & 0x60 = 0x20))"];
    }
    [query appendString:@" ORDER BY d.creationDate DESC"];
    if (maxDescriptors > 0) {
        [query limit:maxDescriptors];
    }

    return [self internalListDescriptorWithQuery:query conversation:conversation maxDescriptors:maxDescriptors];
}

- (nonnull NSArray<TLDescriptor *> *)listDescriptorWithDescriptorIds:(nonnull NSArray<NSNumber *> *)descriptorIds {
    DDLogVerbose(@"%@ listDescriptorWithDescriptorIds: %@", LOG_TAG, descriptorIds);

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.cid, d.sequenceId, d.twincodeOutbound,"
                             " d.sentTo, replyTo.id, replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType,"
                             " d.creationDate, d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate,"
                             " d.deleteDate, d.expireTimeout, d.flags, d.content, d.value FROM descriptor AS d"
                             " LEFT JOIN descriptor AS replyTo ON d.replyTo = replyTo.id"];
    
    [query filterInList:descriptorIds field:@"d.id"];

    return [self internalListDescriptorWithQuery:query conversation:nil maxDescriptors:(int)descriptorIds.count];
}

- (nonnull NSMutableArray<TLDescriptor *> *)internalListDescriptorWithQuery:(nonnull TLQueryBuilder *)query conversation:(nullable id<TLConversation>)conversation maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ internalListDescriptorWithQuery: %@ conversation: %@ maxDescriptors: %d", LOG_TAG, query, conversation, maxDescriptors);

    __block NSMutableArray<NSNumber *> *toDeletedDescriptors = nil;
    __block NSMutableArray<TLDescriptor *> *descriptors = [[NSMutableArray alloc] initWithCapacity:maxDescriptors];
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }

        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }

        NSMutableDictionary<NSNumber *, TLDescriptor *> *descriptorMap = [[NSMutableDictionary alloc] init];
        while ([resultSet next]) {
            TLDescriptor *descriptor = [self loadDescriptorWithCursor:resultSet];
            if (descriptor && ![descriptor isExpired]) {
                [descriptors addObject:descriptor];
                
                [descriptorMap setObject:descriptor forKey:[NSNumber numberWithLongLong:descriptor.descriptorId.id]];
            } else {
                if (!toDeletedDescriptors) {
                    toDeletedDescriptors = [[NSMutableArray alloc] init];
                }
                [toDeletedDescriptors addObject:[NSNumber numberWithLongLong:[resultSet longLongIntForColumnIndex:0]]];
            }
        }
        [resultSet close];

        // Get the descriptor annotations in a second query.
        if (descriptors.count > 0) {
            TLQueryBuilder *annotationsQuery = [[TLQueryBuilder alloc] initWithSQL:@"descriptor, kind, value, COUNT(*) FROM annotation"];
            if (conversation) {
                [annotationsQuery filterIdentifier:conversation.identifier field:@"cid"];
            }
            [annotationsQuery filterInList:[descriptorMap allKeys] field:@"descriptor"];
            [annotationsQuery appendString:@"GROUP BY descriptor, kind, value"];
            
            // Step 2: run the query and dispatch the annotation to the corresponding descriptor.
            resultSet = [database executeQuery:[annotationsQuery sql] withArgumentsInArray:[annotationsQuery sqlParams]];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
                return;
            }
            
            while ([resultSet next]) {
                int64_t descriptorId = [resultSet longLongIntForColumnIndex:0];
                TLDescriptorAnnotationType type = [TLConversationServiceProvider toDescriptorAnnotationType:[resultSet intForColumnIndex:1]];
                TLDescriptor *descriptor = descriptorMap[[NSNumber numberWithLongLong:descriptorId]];
                if (descriptor && type != TLDescriptorAnnotationTypeInvalid) {
                    int value = [resultSet intForColumnIndex:2];
                    int count = [resultSet intForColumnIndex:3];
                    
                    NSMutableArray<TLDescriptorAnnotation *> *annotations = descriptor.annotations;
                    if (!annotations) {
                        annotations = [[NSMutableArray alloc] init];
                        descriptor.annotations = annotations;
                    }
                    [annotations addObject:[[TLDescriptorAnnotation alloc] initWithType:type value:value count:count]];
                }
            }
            [resultSet close];
        }
    }];

    if (toDeletedDescriptors) {
        [self inTransaction:^(TLTransaction *transaction) {
            [transaction deleteWithList:toDeletedDescriptors table:TLDatabaseTableDescriptor];
            [transaction commit];
        }];
    }
    return descriptors;
}

- (nullable TLDescriptor *)loadDescriptorWithCursor:(nonnull FMResultSet *)resultSet {
    DDLogVerbose(@"%@ loadDescriptorWithCursor: %@", LOG_TAG, resultSet);

    // d.id, d.cid, d.sequenceId, d.twincodeOutbound, d.sendTo, replyTo.id,
    //  replyTo.sequenceId, replyTo.twincodeOutbound, d.descriptorType, d.creationDate,
    //  d.sendDate, d.receiveDate, d.readDate, d.updateDate, d.peerDeleteDate, d.deleteDate,
    //  d.expireTimeout, d.flags, d.content, d.value

    int64_t id = [resultSet longLongIntForColumnIndex:0];
    int64_t cid = [resultSet longLongIntForColumnIndex:1];
    int64_t sequenceId = [resultSet longLongIntForColumnIndex:2];
    int64_t twincodeOutboundId = [resultSet longLongIntForColumnIndex:3];
    int64_t sendToId = [resultSet longLongIntForColumnIndex:4];
    int64_t replyToId = [resultSet longLongIntForColumnIndex:5];
    int descriptorType = [resultSet intForColumnIndex:8];
    int64_t creationDate = [resultSet longLongIntForColumnIndex:9];
    int64_t sendDate = [resultSet longLongIntForColumnIndex:10];
    int64_t receiveDate = [resultSet longLongIntForColumnIndex:11];
    int64_t readDate = [resultSet longLongIntForColumnIndex:12];
    int64_t updateDate = [resultSet longLongIntForColumnIndex:13];
    int64_t peerDeleteDate = [resultSet longLongIntForColumnIndex:14];
    int64_t deleteDate = [resultSet longLongIntForColumnIndex:15];
    int64_t expireTimeout = [resultSet longLongIntForColumnIndex:16];
    int flags = [resultSet intForColumnIndex:17];
    NSString* content = [resultSet stringForColumnIndex:18];
    int64_t value = [resultSet longLongIntForColumnIndex:19];

    TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithId:twincodeOutboundId];
    if (!twincodeOutbound) {
        return nil;
    }

    TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithId:id twincodeOutboundId:twincodeOutbound.uuid sequenceId:sequenceId];
    NSUUID *sendTo = nil;
    if (sendToId > 0) {
        TLTwincodeOutbound *sendTwincodeOutbound = [self.database loadTwincodeOutboundWithId:sendToId];
        if (sendTwincodeOutbound) {
            sendTo = sendTwincodeOutbound.uuid;
        }
    }

    TLDescriptorId *replyTo = nil;
    if (replyToId > 0) {
        int64_t replyToSequenceId = [resultSet longLongIntForColumnIndex:6];
        int64_t replyToTwincodeId = [resultSet longLongIntForColumnIndex:7];
        if (replyToSequenceId > 0 && replyToTwincodeId > 0) {
            TLTwincodeOutbound *replyTwincodeOutbound = [self.database loadTwincodeOutboundWithId:replyToTwincodeId];
            if (replyTwincodeOutbound) {
                replyTo = [[TLDescriptorId alloc] initWithId:replyToId twincodeOutboundId:replyTwincodeOutbound.uuid sequenceId:replyToSequenceId];
            }
        }
    }

    switch (descriptorType) {
         case 1: // Generic descriptor (not used)
             return nil;

         case 2: // Message/Object descriptor
            return [[TLObjectDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content];

         case 3: // TransientDescriptor
             return nil;

         case 4: // FileDescriptor (should not be used)
             return nil;

         case 5: // ImageDescriptor
            return [[TLImageDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content length:value];

        case 6: // AudioDescriptor
            return [[TLAudioDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content length:value];

         case 7: // VideoDescriptor
            return [[TLVideoDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content length:value];

         case 8: // NamedFileDescriptor
            return [[TLNamedFileDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content length:value];

         case 9: // Invitation descriptor
            return [[TLInvitationDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content status:value];

         case 10: // Geolocation descriptor
            return [[TLGeolocationDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content];

         case 11: // Twincode descriptor
            return [[TLTwincodeDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content];

         case 12: // Call descriptor
            return [[TLCallDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout flags:flags content:content duration:value];

         case 13: // Clear descriptor
            return [[TLClearDescriptor alloc] initWithDescriptorId:descriptorId conversationId:cid sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout clearDate:value];

         default:
             return nil;
     }
}

+ (nonnull NSString *)filterWithTypes:(nullable NSArray<NSNumber *> *)types {
    DDLogVerbose(@"%@ filterWithTypes: %@", LOG_TAG, types);
    
    if (!types || types.count == 0) {
        return @"";
    }

    if (types.count == 1) {
        return [NSString stringWithFormat:@"d.descriptorType=%d", [TLConversationServiceProvider fromDescriptorType:(TLDescriptorType)types[0].intValue]];
    }

    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:1024];
    [result appendString:@"d.descriptorType IN ("];
    BOOL needSep = NO;
    for (NSNumber *type in types) {
        if (needSep) {
            [result appendString:@","];
        }
        needSep = YES;
        [result appendFormat:@"%d", [TLConversationServiceProvider fromDescriptorType:(TLDescriptorType)type.intValue]];
    }
    [result appendString:@")"];
    return result;
}

- (int64_t)newSequenceId {
    DDLogVerbose(@"%@ newSequenceId", LOG_TAG);

    __block int64_t sequenceId = -1L;
    [self inTransaction:^(TLTransaction *transaction) {
        sequenceId = [transaction allocateIdWithTable:TLDatabaseSequence];
        [transaction commit];
    }];
    return sequenceId;
}

- (nullable TLDescriptor *)createDescriptorWithConversation:(nonnull id<TLConversation>)conversation createBlock:(nonnull TLDescriptor * _Nullable (^)(int64_t descriptorId, int64_t conversationId, int64_t sequenceId))block {
    DDLogVerbose(@"%@ createDescriptorWithConversation: %@", LOG_TAG, conversation);

    int64_t localCid = conversation.identifier.identifier;
    __block TLDescriptor *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        int64_t descriptorId = [transaction allocateIdWithTable:TLDatabaseTableDescriptor];
        int64_t sequenceId = [transaction allocateIdWithTable:TLDatabaseSequence];
        TLDescriptor *descriptor = block(descriptorId, localCid, sequenceId);
        if (descriptor) {
            descriptor = [self internalInsertWithTransaction:transaction descriptor:descriptor];
            [transaction commit];
            result = descriptor;
        }
    }];
    return result;
}

- (nullable TLDescriptor *)internalInsertWithTransaction:(nonnull TLTransaction *)transaction descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ internalInsertWithTransaction: %@ descriptor: %@", LOG_TAG, transaction, descriptor);

    TLDescriptorId *descriptorId = descriptor.descriptorId;
    TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithTwincodeId:descriptorId.twincodeOutboundId];
    if (!twincodeOutbound) {
        return nil;
    }
    NSUUID *sendToId = descriptor.sendTo;
    NSObject *sendTo;
    if (sendToId) {
        TLTwincodeOutbound *sendToTwincodeOutbound = [self.database loadTwincodeOutboundWithTwincodeId:sendToId];
        if (!sendToTwincodeOutbound) {
            return nil;
        }
        sendTo = [sendToTwincodeOutbound.identifier identifierNumber];
    } else {
        sendTo = [NSNull alloc];
    }
        
    NSNumber *did = [NSNumber numberWithLongLong:descriptorId.id];
    NSNumber *seq = [NSNumber numberWithLongLong:descriptorId.sequenceId];
    NSNumber *cid = [NSNumber numberWithLongLong:descriptor.conversationId];
    NSNumber *twincode = [twincodeOutbound.identifier identifierNumber];
    NSNumber *descriptorType = [NSNumber numberWithInt:[TLConversationServiceProvider fromDescriptorType:[descriptor getType]]];
    
    TLDescriptorId *replyTo = descriptor.replyTo;
    NSObject *replyToDescriptorId = [NSNull alloc];
    
    if (replyTo) {
        if (replyTo.id > 0) {
            replyToDescriptorId = [NSNumber numberWithLongLong:replyTo.id];
        } else {
            TLTwincodeOutbound *replyPeerTwincode = [transaction loadOrStoreTwincodeOutboundId:replyTo.twincodeOutboundId];
            if (replyPeerTwincode) {
                
                FMResultSet *resultSet = [transaction executeQuery:@"SELECT d.id FROM descriptor AS d"
                                          " WHERE d.cid=? AND d.sequenceId=? AND d.twincodeOutbound=?", cid, [NSNumber numberWithLongLong:replyTo.sequenceId], [replyPeerTwincode.identifier identifierNumber]];
                if (resultSet){
                    if ([resultSet next]) {
                        replyToDescriptorId = [NSNumber numberWithLongLong:[resultSet longLongIntForColumnIndex:0]];
                    }
                    [resultSet close];
                }
            }
        }
    }
    
    [transaction executeUpdate:@"INSERT INTO descriptor (id, cid, sequenceId, twincodeOutbound,"
     " sentTo, replyTo, descriptorType, creationDate, sendDate, receiveDate, readDate, updateDate,"
     " peerDeleteDate, deleteDate, expireTimeout, flags, value, content) VALUES(?, ?, ?, ?,"
     " ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", did, cid, seq, twincode, sendTo, replyToDescriptorId, descriptorType, [NSNumber numberWithLongLong:descriptor.createdTimestamp], [NSNumber numberWithLongLong:descriptor.sentTimestamp], [NSNumber numberWithLongLong:descriptor.receivedTimestamp], [NSNumber numberWithLongLong:descriptor.readTimestamp], [NSNumber numberWithLongLong:descriptor.updatedTimestamp], [NSNumber numberWithLongLong:descriptor.peerDeletedTimestamp], [NSNumber numberWithLongLong:descriptor.deletedTimestamp], [NSNumber numberWithLongLong:descriptor.expireTimeout], [NSNumber numberWithInt:[descriptor flags]], [NSNumber numberWithLongLong:[descriptor value]], [TLDatabaseService toObjectWithString:[descriptor serialize]]];

    @synchronized (self) {
        [self.descriptorCache setObject:descriptor forKey:descriptor.descriptorId];
    }
    return descriptor;
}

- (nullable TLInvitationDescriptor *)createInvitationWithConversation:(nonnull id<TLConversation>)conversation group:(nonnull TLGroupConversationImpl *)group name:(nonnull NSString *)name publicKey:(nullable NSString *)publicKey {

    TLTwincodeOutbound *groupTwincode = group.subject.peerTwincodeOutbound;
    if (!groupTwincode) {
        return nil;
    }
    TLTwincodeOutbound *inviterTwincode = group.subject.twincodeOutbound;
    if (!inviterTwincode) {
        return nil;
    }

    __block TLInvitationDescriptor *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *groupId = [group.identifier identifierNumber];

        long count = [transaction longForQuery:@"SELECT COUNT(*) FROM invitation AS i"
                      " INNER JOIN descriptor AS d ON i.id=d.id"
                      " WHERE i.groupId=? AND d.value=0", groupId];

        // Too many members or pending invitation in the group, refuse the invitation.
        if (count + [group activeMemberCount] > CONVERSATION_MAX_GROUP_MEMBERS) {
            return;
        }

        int64_t did = [transaction allocateIdWithTable:TLDatabaseTableDescriptor];
        int64_t sequenceId = [transaction allocateIdWithTable:TLDatabaseSequence];
        TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithId:did twincodeOutboundId:conversation.twincodeOutboundId sequenceId:sequenceId];
        TLInvitationDescriptor *descriptor = [[TLInvitationDescriptor alloc] initWithDescriptorId:descriptorId conversationId:conversation.identifier.identifier groupTwincodeId:groupTwincode.uuid inviterTwincodeId:inviterTwincode.uuid name:name publicKey:publicKey];
        [self internalInsertWithTransaction:transaction descriptor:descriptor];
        [transaction executeUpdate:@"INSERT INTO invitation(id, groupId, inviterMember)"
         " VALUES(?, ?, ?)", [NSNumber numberWithLongLong:did], groupId, [inviterTwincode.databaseId identifierNumber]];
        [transaction commit];
        result = descriptor;
    }];

    return result;
}

- (TLConversationServiceProviderResult)insertOrUpdateDescriptorWithConversation:(nonnull id<TLConversation>)conversation descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ insertOrUpdateDescriptorWithConversation: %@ descriptor: %@", LOG_TAG, conversation, descriptor);

    int64_t localCid = conversation.identifier.identifier;
    TLDescriptorId *descriptorId = descriptor.descriptorId;
    NSNumber *conversationId = [NSNumber numberWithLongLong:localCid];
    NSNumber *sequenceId = [NSNumber numberWithLongLong:descriptorId.sequenceId];

    __block TLConversationServiceProviderResult result = TLConversationServiceProviderResultError;
    [self inTransaction:^(TLTransaction *transaction) {
        TLTwincodeOutbound *twincodeOutbound = [transaction loadOrStoreTwincodeOutboundId:descriptorId.twincodeOutboundId];
        if (!twincodeOutbound) {
            return;
        }

        FMResultSet *resultSet = [transaction executeQuery:@"SELECT d.id FROM descriptor AS d"
                                  " WHERE d.cid=? AND d.sequenceId=? AND d.twincodeOutbound=?", conversationId, sequenceId, [twincodeOutbound.identifier identifierNumber]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
            return;
        }
        if (![resultSet next]) {
            [descriptor updateWithConversationId:localCid descriptorId:[transaction allocateIdWithTable:TLDatabaseTableDescriptor]];
            [resultSet close];
            [self internalInsertWithTransaction:transaction descriptor:descriptor];
            [transaction commit];
            result = TLConversationServiceProviderResultStored;
        } else {
            [descriptor updateWithConversationId:localCid descriptorId:[resultSet longLongIntForColumnIndex:0]];
            [resultSet close];
            [transaction commit];
            @synchronized (self) {
                [self.descriptorCache setObject:descriptor forKey:descriptor.descriptorId];
            }
            result = TLConversationServiceProviderResultUpdated;
        }
    }];
    return result;
}

- (void)updateWithDescriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ updateWithDescriptor: %@", LOG_TAG, descriptor);

    [self inTransaction:^(TLTransaction *transaction) {
        NSObject *content = [TLDatabaseService toObjectWithString:[descriptor serialize]];
        [transaction executeUpdate:@"UPDATE descriptor SET content=?, value=?, sendDate=?, receiveDate=?, readDate=?, updateDate=?, deleteDate=?, peerDeleteDate=?, flags=? WHERE id=?", content, [NSNumber numberWithLongLong:[descriptor value]], [NSNumber numberWithLongLong:descriptor.sentTimestamp], [NSNumber numberWithLongLong:descriptor.receivedTimestamp], [NSNumber numberWithLongLong:descriptor.readTimestamp], [NSNumber numberWithLongLong:descriptor.updatedTimestamp], [NSNumber numberWithLongLong:descriptor.deletedTimestamp], [NSNumber numberWithLongLong:descriptor.peerDeletedTimestamp], [NSNumber numberWithInt:descriptor.flags], [NSNumber numberWithLongLong:descriptor.descriptorId.id]];
        [transaction commit];
    }];
}

- (void)acceptInvitationWithDescriptor:(nonnull TLInvitationDescriptor *)descriptor groupConversation:(nonnull TLGroupConversationImpl *)groupConversation {
    DDLogVerbose(@"%@ acceptInvitationWithDescriptor: %@", LOG_TAG, descriptor);

    [self inTransaction:^(TLTransaction *transaction) {
        NSObject *content = [TLDatabaseService toObjectWithString:[descriptor serialize]];
        [transaction executeUpdate:@"UPDATE descriptor SET content=?, value=?, sendDate=?, receiveDate=?, readDate=?, updateDate=?, deleteDate=?, peerDeleteDate=?, flags=? WHERE id=?", content, [NSNumber numberWithLongLong:[descriptor value]], [NSNumber numberWithLongLong:descriptor.sentTimestamp], [NSNumber numberWithLongLong:descriptor.receivedTimestamp], [NSNumber numberWithLongLong:descriptor.readTimestamp], [NSNumber numberWithLongLong:descriptor.updatedTimestamp], [NSNumber numberWithLongLong:descriptor.deletedTimestamp], [NSNumber numberWithLongLong:descriptor.peerDeletedTimestamp], [NSNumber numberWithInt:descriptor.flags], [NSNumber numberWithLongLong:descriptor.descriptorId.id]];

        TLTwincodeOutbound *memberTwincode = groupConversation.subject.twincodeOutbound;
        TLTwincodeOutbound *inviterMemberTwincode = [transaction loadOrStoreTwincodeOutboundId:descriptor.descriptorId.twincodeOutboundId];
        if (memberTwincode && inviterMemberTwincode) {
            [transaction executeUpdate:@"INSERT OR REPLACE INTO invitation (id, groupId, inviterMember,"
             " joinedMember) VALUES(?, ?, ?, ?)", [NSNumber numberWithLongLong:descriptor.descriptorId.id], [groupConversation.identifier identifierNumber], [inviterMemberTwincode.identifier identifierNumber], [memberTwincode.identifier identifierNumber]];
        }
        [transaction commit];
    }];
}

- (void)updateDescriptorTimestamps:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ updateDescriptorTimestamps: %@", LOG_TAG, descriptor);
    
    // We can receive the 'read' indicator very late and the descriptor can now has expired.
    // If this is the case, delete it immediately.
    /* if ([descriptor isExpired]) {
        [self deleteDescriptorWithDescriptor:descriptor];
        return;
    }*/

    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE descriptor SET sendDate=?, receiveDate=?, readDate=?, updateDate=?, deleteDate=?, peerDeleteDate=? WHERE id=?", [NSNumber numberWithLongLong:descriptor.sentTimestamp], [NSNumber numberWithLongLong:descriptor.receivedTimestamp], [NSNumber numberWithLongLong:descriptor.readTimestamp], [NSNumber numberWithLongLong:descriptor.updatedTimestamp], [NSNumber numberWithLongLong:descriptor.deletedTimestamp], [NSNumber numberWithLongLong:descriptor.peerDeletedTimestamp], [NSNumber numberWithLongLong:descriptor.descriptorId.id]];
        [transaction commit];
    }];
}

- (BOOL)deleteDescriptorsWithMap:(nonnull NSDictionary<NSUUID *, TLDescriptorId *> *)descriptorList conversation:(nonnull id<TLConversation>)conversation keepMediaMessages:(BOOL)keepMediaMessages  deletedOperations:(nonnull NSMutableArray<NSNumber *> *)deletedOperations {
    DDLogVerbose(@"%@ deleteDescriptorsWithMap: %@ keepMediaMessages: %d", LOG_TAG, descriptorList, keepMediaMessages);

    int64_t cid = conversation.identifier.identifier;

    __block BOOL result = NO;
    
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *conversationId = [NSNumber numberWithLongLong:cid];
        for (NSUUID *twincodeOutboundId in descriptorList) {
            TLDescriptorId *descriptorId = descriptorList[twincodeOutboundId];
            if (!descriptorId) {
                continue;
            }
            TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithTwincodeId:twincodeOutboundId];
            if (!twincodeOutbound) {
                continue;
            }
            NSNumber *twincodeId = [twincodeOutbound.identifier identifierNumber];
            NSNumber *sequenceId = [NSNumber numberWithLongLong:descriptorId.sequenceId];
            if (keepMediaMessages) {
                // Step 1: use a subquery to delete the annotations since DELETE+JOIN is not possible with SQLite.
                // We only delete the annotations of deleted descriptors.
                [transaction executeUpdate:@"DELETE FROM annotation WHERE descriptor IN "
                 " (SELECT d.id FROM descriptor AS d WHERE d.cid=? AND d.twincodeOutbound=? AND d.sequenceId<=?"
                 " AND d.descriptorType != 2 AND d.descriptorType != 5 AND d.descriptorType != 7"
                 " AND d.descriptorType != 9 AND d.descriptorType != 11)", conversationId, twincodeId, sequenceId];
                
                // Step 2: delete the descriptors but keep messages, images, video, invitations.
                [transaction executeUpdate:@"DELETE FROM descriptor AS d WHERE d.cid=? AND d.twincodeOutbound=? AND d.sequenceId<=?"
                 " AND d.descriptorType != 2 AND d.descriptorType != 5 AND d.descriptorType != 7"
                 " AND d.descriptorType != 9 AND d.descriptorType != 11", conversationId, twincodeId, sequenceId];
                
                if ([transaction changes] > 0) {
                    result = YES;
                }
                
                // Step 3: clear the length of image and video descriptors.
                [transaction executeUpdate:@"UPDATE descriptor SET value=0"
                 " WHERE cid=? AND twincodeOutbound=? AND sequenceId<=?"
                 " AND (descriptorType = 5 OR descriptorType =7)", conversationId, twincodeId, sequenceId];
                
            } else {
                [transaction executeUpdate:@"DELETE FROM annotation WHERE descriptor IN "
                 " (SELECT d.id FROM descriptor AS d WHERE d.cid=? AND d.twincodeOutbound=? AND d.sequenceId<=?)", conversationId, twincodeId, sequenceId];
                
                [transaction executeUpdate:@"DELETE FROM descriptor WHERE cid=? AND twincodeOutbound=? AND sequenceId<=?", conversationId, twincodeId, sequenceId];
                if ([transaction changes] > 0) {
                    result = YES;
                }
            }
        }
        [transaction commit];
    }];
    
    return result;
}

- (nonnull NSMutableArray<NSMutableSet<TLDescriptorId *> *> *)deleteMediaDescriptorsWithConversation:(nonnull id<TLConversation>)conversation beforeDate:(int64_t)beforeDate resetDate:(int64_t)resetDate {

    __block NSMutableSet<TLDescriptorId *> *deleteList = [[NSMutableSet alloc] init];
    __block NSMutableSet<TLDescriptorId *> *peerDeleteList = [[NSMutableSet alloc] init];
    __block NSMutableSet<TLDescriptorId *> *ownerDeleteList = [[NSMutableSet alloc] init];
    [self inTransaction:^(TLTransaction *transaction) {
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithTwincodeId:conversation.twincodeOutboundId];
        long ownerTwincodeId = twincodeOutbound.identifier.identifier;

        TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.sequenceId, d.twincodeOutbound,"
                                 " twout.twincodeId, d.sendDate, d.deleteDate, d.peerDeleteDate FROM descriptor AS d"
                                 " LEFT JOIN twincodeOutbound AS twout ON twout.id = d.twincodeOutbound"];
        [query filterIdentifier:conversation.identifier field:@"d.cid"];
        [query filterBefore:beforeDate field:@"d.creationDate"];
        [query filterWhere:@"d.descriptorType >= 4 AND d.descriptorType <= 8"];
        [query appendString:@" AND (d.twincodeOutbound = "];
        [query appendString:[NSString stringWithFormat:@"%ld",ownerTwincodeId]];
        [query appendString:@" OR d.deleteDate = 0)"];
        
        FMResultSet *resultSet = [transaction executeWithQuery:query];
        if (!resultSet) {
            return;
        }
        while ([resultSet next]) {
            int64_t did = [resultSet longLongIntForColumnIndex:0];
            int64_t sequenceId = [resultSet longLongIntForColumnIndex:1];
            int64_t twincodeId = [resultSet longLongIntForColumnIndex:2];
            NSUUID *twincodeUUID = [resultSet uuidForColumnIndex:3];
            int64_t sendDate = [resultSet longLongIntForColumnIndex:4];
            int64_t deleteDate = [resultSet longLongIntForColumnIndex:5];
            int64_t peerDeleteDate = [resultSet longLongIntForColumnIndex:6];

            // If this is one of our descriptor, we can delete it immediately if it was not sent
            // or the peer has removed it.
            if (ownerTwincodeId == twincodeId || !twincodeUUID) {
                if (sendDate <= 0 || peerDeleteDate > 0 || !twincodeUUID) {
                    if (!twincodeUUID) {
                        twincodeUUID = [TLTwincode NOT_DEFINED];
                    }
                    [deleteList addObject:[[TLDescriptorId alloc] initWithId:did twincodeOutboundId:twincodeUUID sequenceId:sequenceId]];
                } else if (deleteDate == 0) {
                    [ownerDeleteList addObject:[[TLDescriptorId alloc] initWithId:did twincodeOutboundId:twincodeUUID sequenceId:sequenceId]];
                }
            } else {
                // This is a media peer descriptor, we can delete it immediately and report
                // a PEER_DELETE operation to the sender.
                [peerDeleteList addObject:[[TLDescriptorId alloc] initWithId:did twincodeOutboundId:twincodeUUID sequenceId:sequenceId]];
            }
        }
        [resultSet close];
        if (ownerDeleteList.count > 0) {
            [self updateDescriptorTimestampsWithTransaction:transaction descriptors:ownerDeleteList.allObjects peerDeleteDate:0 deleteDate:resetDate];
        }
        if (deleteList.count > 0) {
            [self deleteDescriptorListWithTransaction:transaction subjectId:[conversation.subject.identifier identifierNumber] list:deleteList];
        }
        if (peerDeleteList.count > 0) {
            [self deleteDescriptorListWithTransaction:transaction subjectId:[conversation.subject.identifier identifierNumber] list:peerDeleteList];
        }
        [transaction commit];
    }];
    
    NSMutableArray<NSMutableSet<TLDescriptorId *>*> *result = [[NSMutableArray alloc] initWithCapacity:3];
    
    [result addObject:deleteList];
    [result addObject:ownerDeleteList];
    [result addObject:peerDeleteList];
    return result;
}

- (nullable NSSet<TLDescriptorId *> *)markDescriptorDeletedWithConversation:(nonnull id<TLConversation>)conversation clearDate:(int64_t)clearDate resetDate:(int64_t)resetDate twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId keepMediaMessages:(BOOL)keepMediaMessages {
    DDLogVerbose(@"%@ markDescriptorDeletedWithConversation: %@ clearDate: %lld resetDate: %lld twincodeOutboundId: %@ keepMediaMessages: %d", LOG_TAG, conversation, clearDate, resetDate, twincodeOutboundId, keepMediaMessages);
    
    __block NSMutableSet<TLDescriptorId *> *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithTwincodeId:twincodeOutboundId];
        if (!twincodeOutbound) {
            return;
        }

        long ownerTwincodeId = twincodeOutbound.identifier.identifier;
        TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"d.id, d.sequenceId, d.twincodeOutbound,"
                                 " twout.twincodeId, d.deleteDate, d.peerDeleteDate FROM descriptor AS d"
                                 " LEFT JOIN twincodeOutbound AS twout ON d.twincodeOutbound=twout.id"];

        [query filterIdentifier:conversation.identifier field:@"d.cid"];
        [query filterBefore:clearDate field:@"d.creationDate"];
        if (keepMediaMessages) {
            [query filterWhere:@"d.descriptorType != 2 AND d.descriptorType != 5"
              " AND d.descriptorType != 7 AND d.descriptorType != 9 AND d.descriptorType != 11"];
        }
        
        [query appendString:@" AND (d.twincodeOutbound = "];
        [query appendString:[NSString stringWithFormat:@"%ld",ownerTwincodeId]];
        [query appendString:@" OR d.deleteDate = 0)"];
        

        FMResultSet *resultSet = [transaction executeWithQuery:query];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
            return;
        }

        NSMutableArray<TLDescriptorId *> *updatePeerDeleteList = nil;
        NSMutableArray<TLDescriptorId *> *updateDeleteList = nil;
        while ([resultSet next]) {
            long did = [resultSet longLongIntForColumnIndex:0];
            int64_t sequenceId = [resultSet longLongIntForColumnIndex:1];
            long twincodeId = [resultSet longLongIntForColumnIndex:2];
            NSUUID *twincodeUUID = [resultSet uuidForColumnIndex:3];
            int64_t deleteDate = [resultSet longLongIntForColumnIndex:4];
            int64_t peerDeleteDate = [resultSet longLongIntForColumnIndex:5];

            TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithId:did twincodeOutboundId:twincodeUUID sequenceId:sequenceId];

            // If this is one of our descriptor, check if it is not yet marked as deleted by the peer, set the mark now.
            if (ownerTwincodeId == twincodeId) {
                if (peerDeleteDate == 0) {
                    // Our descriptor is also deleted locally, we can remove it because the peer has deleted it.
                    if (deleteDate != 0) {
                        if (!result) {
                            result = [[NSMutableSet alloc] init];
                        }
                        [result addObject:descriptorId];
                    } else {
                        if (!updatePeerDeleteList) {
                            updatePeerDeleteList = [[NSMutableArray alloc] init];
                        }
                        [updatePeerDeleteList addObject:descriptorId];
                    }
                }
            } else {
                // Mark the peer descriptor as deleted but keep it.
                if (deleteDate == 0) {
                    if (!updateDeleteList) {
                        updateDeleteList = [[NSMutableArray alloc] init];
                    }
                    [updateDeleteList addObject:descriptorId];
                }
            }
        }
        [resultSet close];

        if (updateDeleteList) {
            [self updateDescriptorTimestampsWithTransaction:transaction descriptors:updateDeleteList peerDeleteDate:0 deleteDate:resetDate];
        }
        if (updatePeerDeleteList) {
            [self updateDescriptorTimestampsWithTransaction:transaction descriptors:updatePeerDeleteList peerDeleteDate:resetDate deleteDate:0];
        }
        
        if (result) {
            [self deleteDescriptorListWithTransaction:transaction subjectId:[conversation.subject.identifier identifierNumber] list:result];
        }
        [transaction commit];
    }];
    return result;
}

- (void)updateDescriptorTimestampsWithTransaction:(nonnull TLTransaction *)transaction descriptors:(nonnull NSArray<TLDescriptorId *> *)descriptors peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate {
    DDLogVerbose(@"%@ updateDescriptorTimestampsWithTransaction: %@", LOG_TAG, transaction);
    
    if (peerDeleteDate != 0) {
        NSNumber *date = [NSNumber numberWithLongLong:peerDeleteDate];
        for (TLDescriptorId *descriptorId in descriptors) {
            [transaction executeUpdate:@"UPDATE descriptor SET peerDeleteDate=? WHERE id=?", date, [NSNumber numberWithLongLong:descriptorId.id]];
        }
    } else {
        NSNumber *date = [NSNumber numberWithLongLong:deleteDate];
        for (TLDescriptorId *descriptorId in descriptors) {
            [transaction executeUpdate:@"UPDATE descriptor SET deleteDate=? WHERE id=?", date, [NSNumber numberWithLongLong:descriptorId.id]];
        }
    }
}

- (void)deleteDescriptorWithDescriptor:(nonnull TLDescriptor *)descriptor conversation:(nonnull id<TLConversation>)conversation {
    DDLogVerbose(@"%@ deleteDescriptorWithDescriptor: %@", LOG_TAG, descriptor);
    
    [descriptor deleteDescriptor];
    
    [self deleteDescriptorWithDescriptorId:descriptor.descriptorId conversation:conversation];
}

- (void)deleteDescriptorWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversation:(nonnull id<TLConversation>)conversation {
    DDLogVerbose(@"%@ deleteDescriptorWithDescriptorId: %@", LOG_TAG, descriptorId);

    [self inTransaction:^(TLTransaction *transaction) {
        [self deleteDescriptorListWithTransaction:transaction subjectId:[conversation.subject.identifier identifierNumber] list:[NSSet setWithObject:descriptorId]];
        [transaction commit];
    }];
}

- (void)deleteDescriptorListWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nonnull NSNumber *)subjectId list:(nonnull NSSet<TLDescriptorId *> *)list {
    DDLogVerbose(@"%@ deleteDescriptorListWithTransaction: %@ subjectId: %@ list: %@", LOG_TAG, transaction, subjectId, list);

    for (TLDescriptorId *descriptorId in list) {
        NSNumber *did = [NSNumber numberWithLongLong:descriptorId.id];
        [transaction executeUpdate:@"DELETE FROM annotation WHERE descriptor=?", did];
        [transaction deleteWithDatabaseId:descriptorId.id table:TLDatabaseTableInvitation];
        [transaction deleteWithDatabaseId:descriptorId.id table:TLDatabaseTableDescriptor];
        [transaction deleteNotificationsWithSubjectId:subjectId twincodeId:nil descriptorId:did];
    }

    @synchronized (self) {
        for (TLDescriptorId *descriptorId in list) {
            [self.descriptorCache removeObjectForKey:descriptorId];
        }
    }
}

#pragma mark - Annotations

- (nonnull NSMutableArray<TLDescriptorAnnotation *> *)loadLocalAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversation:(nonnull id<TLConversation>)conversation {
    DDLogVerbose(@"%@ loadLocalAnnotationsWithDescriptorId: %@ conversation: %@", LOG_TAG, descriptorId, conversation);
    
    NSMutableArray<TLDescriptorAnnotation *> *annotations = [[NSMutableArray alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        NSNumber *cid = [conversation.identifier identifierNumber];
        FMResultSet *resultSet = [database executeQuery:@"SELECT kind, value"
                                  " FROM annotation WHERE cid=? AND descriptor=? AND peerTwincodeOutbound IS NULL", cid, [NSNumber numberWithLongLong:descriptorId.id]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            TLDescriptorAnnotationType type = [TLConversationServiceProvider toDescriptorAnnotationType:[resultSet intForColumnIndex:0]];
            if (type != TLDescriptorAnnotationTypeInvalid) {
                int value = [resultSet intForColumnIndex:1];
                        
                [annotations addObject:[[TLDescriptorAnnotation alloc] initWithType:type value:value count:0]];
            }
        }
        [resultSet close];
    }];
    return annotations;
}

- (BOOL)setAnnotationsWithDescriptor:(nonnull TLDescriptor *)descriptor peerTwincodeOutboundId:(nonnull NSUUID *)peerTwincodeOutboundId annotations:(nonnull NSArray<TLDescriptorAnnotation *> *)annotations  annotatingUsers:(nonnull NSMutableSet<TLTwincodeOutbound *> *)annotatingUsers {
    DDLogVerbose(@"%@ setAnnotationsWithDescriptor: %@ peerTwincodeOutboundId: %@ annotations: %@", LOG_TAG, descriptor, peerTwincodeOutboundId, annotations);

    NSMutableDictionary<NSNumber *, NSNumber *> *newList = [[NSMutableDictionary alloc] initWithCapacity:annotations.count];
    for (TLDescriptorAnnotation *annotation in annotations) {
        [newList setObject:[NSNumber numberWithInt:annotation.value] forKey:[NSNumber numberWithInt:annotation.type]];
    }
    
    __block BOOL modified = NO;
    [self inTransaction:^(TLTransaction *transaction) {
        TLDescriptorId *descriptorId = descriptor.descriptorId;
        TLTwincodeOutbound *twincodeOutbound = [transaction loadOrStoreTwincodeOutboundId:peerTwincodeOutboundId];
        if (!twincodeOutbound) {
            return;
        }

        NSNumber *conversationId = [NSNumber numberWithLongLong:descriptor.conversationId];
        NSNumber *did = [NSNumber numberWithLongLong:descriptorId.id];
        NSNumber *peerTwincodeId = [twincodeOutbound.databaseId identifierNumber];
      
        // Step 1: from the current list of annotations on the descriptor for the peer twincode, identify those
        // that must be removed, updated and inserted.
        FMResultSet *resultSet = [transaction executeQuery:@"SELECT kind, value"
                                  " FROM annotation WHERE cid=? AND descriptor=? AND peerTwincodeOutbound=?", conversationId, did, peerTwincodeId];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
            return;
        }

        NSMutableArray<NSNumber *> *deleteList = nil;
        NSMutableArray<NSNumber *> *updateList = nil;
        while ([resultSet next]) {
            TLDescriptorAnnotationType type = [TLConversationServiceProvider toDescriptorAnnotationType:[resultSet intForColumnIndex:0]];
            if (type != TLDescriptorAnnotationTypeInvalid) {
                NSNumber *value = [NSNumber numberWithInt:[resultSet intForColumnIndex:1]];
                NSNumber *key = [NSNumber numberWithInt:type];
                NSNumber *newValue = newList[key];
                        
                if (newValue == nil) {
                    if (!deleteList) {
                        deleteList = [[NSMutableArray alloc] init];
                    }
                    [deleteList addObject:key];
                } else if (newValue.intValue != value.intValue) {
                    if (!updateList) {
                        updateList = [[NSMutableArray alloc] init];
                    }
                    [updateList addObject:key];
                } else {
                    [newList removeObjectForKey:key];
                }
            }
        }
        [resultSet close];
            
        // Step 2: delete the annotations which are removed.
        if (deleteList) {
            for (NSNumber *key in deleteList) {
                [transaction executeUpdate:@"DELETE FROM annotation WHERE cid=? AND descriptor=? AND peerTwincodeOutbound=? AND kind=?", conversationId, did, peerTwincodeId, [NSNumber numberWithInt:[self fromDescriptorAnnotationType:key.intValue]]];
                        
                modified |= [transaction changes] > 0;
            }
        }
            
        // Step 3: update existing annotations.
        if (updateList) {
            NSNumber *creationDate = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
            for (NSNumber *key in updateList) {
                NSNumber *newValue = newList[key];
                [newList removeObjectForKey:key];
                [transaction executeUpdate:@"UPDATE annotation SET value=?, creationDate=?, notificationId=NULL WHERE cid=? AND descriptor=? AND peerTwincodeOutbound=? AND kind=? AND value != ?", newValue, creationDate, conversationId, did, peerTwincodeId, [NSNumber numberWithInt:[self fromDescriptorAnnotationType:key.intValue]], newValue];
                modified = YES;
            }
            [annotatingUsers addObject:twincodeOutbound];
        }
            
        // Step 4: add the new ones.
        if (newList.count > 0) {
            NSNumber *creationDate = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
            for (NSNumber *key in newList) {
                NSNumber *value = newList[key];
                [transaction executeUpdate:@"INSERT OR IGNORE INTO annotation (cid, descriptor, peerTwincodeOutbound, kind, value, creationDate) VALUES(?, ?, ?, ?, ?, ?)", conversationId, did, peerTwincodeId, [NSNumber numberWithInt:[self fromDescriptorAnnotationType:key.intValue]], value, creationDate];
                modified = YES;
            }
            [annotatingUsers addObject:twincodeOutbound];
        }
        if (modified) {
            [self reloadAnnotationsWithTransaction:transaction descriptor:descriptor];
        }
        [transaction commit];
    }];
    return modified;
}

- (BOOL)setAnnotationWithDescriptor:(nonnull TLDescriptor *)descriptor type:(TLDescriptorAnnotationType)type value:(int)value {
    DDLogVerbose(@"%@ setAnnotationWithDescriptor: %@ type: %d value: %d", LOG_TAG, descriptor, type, value);
    
    NSNumber *kind = [NSNumber numberWithInt:[self fromDescriptorAnnotationType:type]];
    NSNumber *annotationValue = [NSNumber numberWithInt:value];
    NSNumber *did = [NSNumber numberWithLongLong:descriptor.descriptorId.id];
    NSNumber *conversationId = [NSNumber numberWithLongLong:descriptor.conversationId];
    __block BOOL modified = NO;
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE annotation SET value=? WHERE cid=? AND descriptor=? AND peerTwincodeOutbound IS NULL AND kind=? AND value != ?", annotationValue, conversationId, did, kind, annotationValue];
        modified = [transaction changes] > 0;

        if (!modified) {
            [transaction executeUpdate:@"INSERT OR IGNORE INTO annotation (cid, descriptor, kind, value) VALUES(?, ?, ?, ?)", conversationId, did, kind, annotationValue];
            modified = [transaction changes] > 0;
        }
        [transaction commit];
        
        if (modified) {
            [self reloadAnnotationsWithTransaction:transaction descriptor:descriptor];
        }
    }];
    return modified;
}

- (BOOL)deleteAnnotationWithDescriptor:(nonnull TLDescriptor *)descriptor type:(TLDescriptorAnnotationType)type {
    DDLogVerbose(@"%@ deleteAnnotationWithDescriptor: %@ type: %d", LOG_TAG, descriptor, type);
    
    NSNumber *kind = [NSNumber numberWithInt:[self fromDescriptorAnnotationType:type]];
    NSNumber *did = [NSNumber numberWithLongLong:descriptor.descriptorId.id];
    NSNumber *conversationId = [NSNumber numberWithLongLong:descriptor.conversationId];
    __block BOOL modified = NO;
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"DELETE FROM annotation WHERE cid=? AND descriptor=? AND peerTwincodeOutbound IS NULL AND kind=?", conversationId, did, kind];
        modified = [transaction changes] > 0;
        [transaction commit];

        if (modified) {
            [self reloadAnnotationsWithTransaction:transaction descriptor:descriptor];
        }
    }];
    return modified;
}

- (BOOL)toggleAnnotationWithDescriptor:(nonnull TLDescriptor *)descriptor type:(TLDescriptorAnnotationType)type value:(int)value {
    DDLogVerbose(@"%@ toggleAnnotationWithDescriptor: %@ type: %d value: %d", LOG_TAG, descriptor, type, value);
    
    NSNumber *kind = [NSNumber numberWithInt:[self fromDescriptorAnnotationType:type]];
    NSNumber *annotationValue = [NSNumber numberWithInt:value];
    NSNumber *did = [NSNumber numberWithLongLong:descriptor.descriptorId.id];
    NSNumber *conversationId = [NSNumber numberWithLongLong:descriptor.conversationId];
    __block BOOL modified = NO;
    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE annotation SET value=? WHERE cid=? AND descriptor=? AND peerTwincodeOutbound IS NULL AND kind=? AND value != ?", annotationValue, conversationId, did, kind, annotationValue];
        modified = [transaction changes] > 0;
        if (!modified) {
            // Try to delete the annotation if it has the specified value.
            [transaction executeUpdate:@"DELETE FROM annotation WHERE cid=? AND descriptor=? AND peerTwincodeOutbound IS NULL AND kind=? AND value=?", conversationId, did, kind, annotationValue];
            modified = [transaction changes] > 0;
        }
                
        // Deletion failed, the annotation does not exist and must be inserted.
        if (!modified) {
            [transaction executeUpdate:@"INSERT OR IGNORE INTO annotation (cid, descriptor, kind, value) VALUES(?, ?, ?, ?)", conversationId, did, kind, annotationValue];
            modified = [transaction changes] > 0;
        }
        [transaction commit];
        
        if (modified) {
            [self reloadAnnotationsWithTransaction:transaction descriptor:descriptor];
        }
    }];
    return modified;
}

- (nullable NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair *> *)listAnnotationsWithDescriptorId:(nonnull TLDescriptorId *)descriptorId {
    DDLogVerbose(@"%@ listAnnotationsWithDescriptorId: %@", LOG_TAG, descriptorId);

    NSMutableDictionary<NSUUID *, TLDescriptorAnnotationPair *> *annotations = [[NSMutableDictionary alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"tw.id, tw.twincodeId, tw.modificationDate,"
                            " tw.name, tw.avatarId, tw.description, tw.capabilities, tw.attributes, tw.flags, a.kind, a.value"
                            " FROM descriptor AS d"
                            " INNER JOIN annotation AS a ON d.cid=a.cid AND a.descriptor=d.id"
                            " INNER JOIN conversation AS c on d.cid=c.id"
                            " INNER JOIN repository AS r on r.id=c.subject"
                            " INNER JOIN twincodeOutbound AS tw ON"
                            " (a.peerTwincodeOutbound IS NULL AND tw.id=r.twincodeOutbound)"
                            " OR (a.peerTwincodeOutbound IS NOT NULL AND tw.id=a.peerTwincodeOutbound)"];
        if (descriptorId.id > 0) {
            [query filterLong:descriptorId.id field:@"d.id"];
        } else {
            [query appendString:@" INNER JOIN twincodeOutbound AS twout ON d.twincodeOutbound=twout.id"];
            [query filterLong:descriptorId.sequenceId field:@"d.sequenceId"];
            [query filterUUID:descriptorId.twincodeOutboundId field:@"twout.twincodeId"];
        }
        FMResultSet *resultSet = [database executeQuery:[query sql] withArgumentsInArray:[query sqlParams]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithResultSet:resultSet offset:0];
            TLDescriptorAnnotationType type = [TLConversationServiceProvider toDescriptorAnnotationType:[resultSet intForColumnIndex:9]];
            int value = [resultSet intForColumnIndex:10];
            if (type != TLDescriptorAnnotationTypeInvalid && twincodeOutbound) {
                [annotations setObject:[[TLDescriptorAnnotationPair alloc] initWithTwincodeOutbound:twincodeOutbound annotation:[[TLDescriptorAnnotation alloc] initWithType:type value:value count:1]] forKey:twincodeOutbound.uuid];
            }
        }
        [resultSet close];
    }];
    return annotations;
}

- (void)reloadAnnotationsWithTransaction:(nonnull TLTransaction *)transaction descriptor:(nonnull TLDescriptor *)descriptor {
    DDLogVerbose(@"%@ reloadAnnotationsWithTransaction: %@ descriptor:%@", LOG_TAG, transaction, descriptor);
    
    NSNumber *conversationId = [NSNumber numberWithLongLong:descriptor.conversationId];
    NSNumber *did = [NSNumber numberWithLongLong:descriptor.descriptorId.id];
    NSMutableArray<TLDescriptorAnnotation *> *annotations = nil;
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT kind, value, COUNT(*) FROM annotation WHERE cid=? AND descriptor=? GROUP BY kind, value", conversationId, did];
    if (!resultSet) {
        [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
        return;
    }
    while ([resultSet next]) {
        int v = [resultSet intForColumnIndex:0];
        TLDescriptorAnnotationType type = [TLConversationServiceProvider toDescriptorAnnotationType:v];
        if (type != TLDescriptorAnnotationTypeInvalid) {
            int value = [resultSet intForColumnIndex:1];
            int count = [resultSet intForColumnIndex:2];
            if (!annotations) {
                annotations = [[NSMutableArray alloc] init];
            }
            [annotations addObject:[[TLDescriptorAnnotation alloc] initWithType:type value:value count:count]];
        }
    }
    [resultSet close];
    descriptor.annotations = annotations;
}

#pragma mark - Operations

- (nullable NSMutableDictionary<TLDatabaseIdentifier *, NSMutableArray<TLConversationServiceOperation *> *> *)loadOperations {
    DDLogVerbose(@"%@ loadOperations", LOG_TAG);
    
    NSArray<TLConversationServiceOperation *> *operations = [self loadOperationsWithQuery:@"SELECT op.id,"
                " op.creationDate, op.cid, op.type, op.descriptor, op.chunkStart, op.content, c.groupId FROM operation AS op"
                " LEFT JOIN conversation AS c ON op.cid = c.id" param:nil];
    if (operations.count == 0) {
        return nil;
    }

    // To help the scheduler, group the operations by conversation in the dictionary.
    NSMutableDictionary<TLDatabaseIdentifier *, NSMutableArray<TLConversationServiceOperation *> *> *result = [[NSMutableDictionary alloc] init];
    for (TLConversationServiceOperation *operation in operations) {
        NSMutableArray<TLConversationServiceOperation *> *list = result[operation.conversationId];
        if (!list) {
            list = [[NSMutableArray alloc] init];
            [result setObject:list forKey:operation.conversationId];
        }
        [list addObject:operation];
    }
    return result;
}

- (nonnull NSMutableArray<TLConversationServiceOperation *> *)loadOperationsWithCid:(int64_t)cid {
    DDLogVerbose(@"%@ loadOperationsWithCid: %lld", LOG_TAG, cid);

    return [self loadOperationsWithQuery:@"SELECT op.id,"
            " op.creationDate, op.cid, op.type, op.descriptor, op.chunkStart, op.content, c.groupId FROM operation AS op"
            " LEFT JOIN conversation AS c ON op.cid = c.id "
            " WHERE op.cid=?" param:[NSNumber numberWithLongLong:cid]];
}

- (nonnull NSMutableArray<TLConversationServiceOperation *> *)loadOperationsWithQuery:(nonnull NSString *)query param:(nullable NSObject *)param {
    DDLogVerbose(@"%@ loadOperationsWithQuery: %@", LOG_TAG, query);

    __block NSMutableArray *toBeDeletedOperations = nil;
    __block NSMutableArray<TLConversationServiceOperation *> *operations = [[NSMutableArray alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }
            
        FMResultSet *resultSet = [database executeQuery:query, param];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }

        while ([resultSet next]) {
            int64_t operationId = [resultSet longLongIntForColumnIndex:0];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:1];
            int64_t cid = [resultSet longLongIntForColumnIndex:2];
            int type = [resultSet intForColumnIndex:3];
            int64_t descriptorId = [resultSet longLongIntForColumnIndex:4];
            int64_t chunkStart = [resultSet longLongIntForColumnIndex:5];
            int64_t groupId = [resultSet longLongIntForColumnIndex:7];
            TLDatabaseIdentifier *conversationId = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:(groupId > 0 ? self.groupConversationFactory : self.conversationFactory)];
            TLConversationServiceOperation *operation;
            switch (type) {
                case 0:
                    operation = [[TLResetConversationOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 1:
                    operation = [[TLSynchronizeConversationOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate];
                    break;

                case 2:
                    operation = [[TLPushObjectOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
                    break;

                case 4:
                    operation = [[TLPushFileOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId chunkStart:chunkStart];
                    break;

                case 5:
                    operation = [[TLUpdateDescriptorTimestampOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 6:
                    operation = [[TLGroupInviteOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeInviteGroup conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
                    break;

                case 7:
                    operation = [[TLGroupInviteOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeWithdrawInviteGroup conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
                    break;

                case 8:
                    operation = [[TLGroupJoinOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeJoinGroup conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 9:
                    operation = [[TLGroupLeaveOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeLeaveGroup conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 10:
                    operation = [[TLGroupUpdateOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeUpdateGroupMember conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 11:
                    operation = [[TLPushGeolocationOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
                    break;

                case 12:
                    operation = [[TLPushTwincodeOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
                    break;

                case 14:
                    operation = [[TLUpdateAnnotationsOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
                    break;

                case 15: // Added 2024-09-09
                    operation = [[TLGroupJoinOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeInvokeJoinGroup conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 16:
                    operation = [[TLGroupLeaveOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeInvokeLeaveGroup conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 17:
                    operation = [[TLGroupJoinOperation alloc] initWithId:operationId type:TLConversationServiceOperationTypeInvokeAddMember conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 18: // Added 2025-05-21
                    operation = [[TLUpdateDescriptorOperation alloc] initWithId:operationId conversationId:conversationId creationDate:creationDate descriptorId:descriptorId content:[resultSet dataForColumnIndex:6]];
                    break;

                case 3:  // Transient operation should never be saved!
                case 13: // Push command
                default:
                    operation = nil;
                    break;
            }
            if (operation) {
                [operations addObject:operation];
            } else {
                if (!toBeDeletedOperations) {
                    toBeDeletedOperations = [[NSMutableArray alloc] init];
                }
                [toBeDeletedOperations addObject:[NSNumber numberWithLongLong:operationId]];
            }
        }
        [resultSet close];
    }];
    
    if (toBeDeletedOperations) {
        [self.database inTransaction:^(TLTransaction *transaction) {
            [transaction deleteWithList:toBeDeletedOperations table:TLDatabaseTableOperation];
            [transaction commit];
        }];
    }
    return operations;
}

- (void)storeOperation:(nonnull TLConversationServiceOperation *)operation {
    DDLogVerbose(@"%@ storeOperation: %@", LOG_TAG, operation);
    
    [self.database inTransaction:^(TLTransaction *transaction) {
        [self storeOperationWithTransaction:transaction operation:operation];
        [transaction commit];
    }];
}

- (void)storeOperations:(nonnull NSMapTable<TLConversationImpl *, NSObject *> *)operations {
    DDLogVerbose(@"%@ storeOperations: %@", LOG_TAG, operations);
    
    // Store a list of operations by using an SQL transaction (serious performance improvement).
    [self.database inTransaction:^(TLTransaction *transaction) {
        for (TLConversationImpl *conversation in operations) {
            NSObject *item = [operations objectForKey:conversation];
            if ([item isKindOfClass:[TLConversationServiceOperation class]]) {
                [self storeOperationWithTransaction:transaction operation:(TLConversationServiceOperation *)item ];
            } else {
                NSArray<TLConversationServiceOperation *> *list = (NSArray *)item;
                for (TLConversationServiceOperation *operation in list) {
                    [self storeOperationWithTransaction:transaction operation:operation];
                }
            }
        }
        [transaction commit];
    }];
}

- (void)storeOperationWithTransaction:(nonnull TLTransaction *)transaction operation:(nonnull TLConversationServiceOperation *)operation {
    DDLogVerbose(@"%@ storeOperationWithTransaction: %@ operation: %@", LOG_TAG, transaction, operation);

    long databaseId = [transaction allocateIdWithTable:TLDatabaseTableOperation];
    NSObject *newContent = [TLDatabaseService toObjectWithData:[operation serialize]];
    NSObject *descriptor = [NSNumber numberWithLongLong:operation.descriptor];
    int operationType = [TLConversationServiceProvider fromOperationType:operation.type];
    NSNumber *chunkStart;
    if (operationType == TLConversationServiceOperationTypePushFile) {
        chunkStart = [NSNumber numberWithLongLong:-1];
    } else {
        chunkStart = [NSNumber numberWithLongLong:0];
    }
    [transaction executeUpdate:@"INSERT INTO operation (id, cid, creationDate,"
     " type, descriptor, chunkStart, content) VALUES(?, ?, ?, ?, ?, ?, ?)", [NSNumber numberWithLong:databaseId], [operation.conversationId identifierNumber], [NSNumber numberWithLongLong:operation.timestamp], [NSNumber numberWithInt:operationType], descriptor, chunkStart, newContent];
    operation.id = databaseId;
}

- (void)updateFileOperation:(nonnull TLPushFileOperation *)operation {
    DDLogVerbose(@"%@ updateFileOperation: %@", LOG_TAG, operation);
    
    [self.database inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE operation SET chunkStart=? WHERE id=?", [NSNumber numberWithLongLong:operation.chunkStart], [NSNumber numberWithLongLong:operation.id]];
        [transaction commit];
    }];
}

- (void)deleteOperationWithOperationId:(int64_t)operationId {
    DDLogVerbose(@"%@ deleteOperation: %lld", LOG_TAG, operationId);
    
    [self.database inTransaction:^(TLTransaction *transaction) {
        [transaction deleteWithDatabaseId:operationId table:TLDatabaseTableOperation];
        [transaction commit];
    }];
}

+ (int)fromDescriptorType:(TLDescriptorType)type {
    
    switch (type) {
        case TLDescriptorTypeDescriptor:
            return 1;
            
        case TLDescriptorTypeObjectDescriptor:
            return 2;
            
        case TLDescriptorTypeTransientObjectDescriptor:
            return 3;
            
        case TLDescriptorTypeFileDescriptor:
            return 4;
            
        case TLDescriptorTypeImageDescriptor:
            return 5;
            
        case TLDescriptorTypeAudioDescriptor:
            return 6;
            
        case TLDescriptorTypeVideoDescriptor:
            return 7;
            
        case TLDescriptorTypeNamedFileDescriptor:
            return 8;
            
        case TLDescriptorTypeInvitationDescriptor:
            return 9;
            
        case TLDescriptorTypeGeolocationDescriptor:
            return 10;
            
        case TLDescriptorTypeTwincodeDescriptor:
            return 11;
            
        case TLDescriptorTypeCallDescriptor:
            return 12;
            
        case TLDescriptorTypeClearDescriptor:
            return 13;
    }
    
    return 0;
}

- (int)fromDescriptorAnnotationType:(TLDescriptorAnnotationType)type {
    
    switch (type) {
        case TLDescriptorAnnotationTypeInvalid:
            return 0;
            
        case TLDescriptorAnnotationTypeForward:
            return 1;
            
        case TLDescriptorAnnotationTypeForwarded:
            return 2;
            
        case TLDescriptorAnnotationTypeSave:
            return 3;
            
        case TLDescriptorAnnotationTypeLike:
            return 4;
            
        case TLDescriptorAnnotationTypePoll:
            return 5;
            
    }
    return 0;
}

+ (TLDescriptorAnnotationType)toDescriptorAnnotationType:(int)type {
    
    switch (type) {
        case 1:
            return TLDescriptorAnnotationTypeForward;
        case 2:
            return TLDescriptorAnnotationTypeForwarded;
        case 3:
            return TLDescriptorAnnotationTypeSave;
        case 4:
            return TLDescriptorAnnotationTypeLike;
        case 5:
            return TLDescriptorAnnotationTypePoll;
    }
    return TLDescriptorAnnotationTypeInvalid;
}

+ (int)fromOperationType:(TLConversationServiceOperationType)type {

    // Use a fix mapping to make sure we don't rely on the Enum order.
    switch (type) {
        case TLConversationServiceOperationTypeResetConversation:
            return 0;
        case TLConversationServiceOperationTypeSynchronizeConversation:
            return 1;
        case TLConversationServiceOperationTypePushObject:
            return 2;
        case TLConversationServiceOperationTypePushTransientObject:
            return 3;
        case TLConversationServiceOperationTypePushFile:
            return 4;
        case TLConversationServiceOperationTypeUpdateDescriptorTimestamp:
            return 5;
        case TLConversationServiceOperationTypeInviteGroup:
            return 6;
        case TLConversationServiceOperationTypeWithdrawInviteGroup:
            return 7;
        case TLConversationServiceOperationTypeJoinGroup:
            return 8;
        case TLConversationServiceOperationTypeLeaveGroup:
            return 9;
        case TLConversationServiceOperationTypeUpdateGroupMember:
            return 10;
        case TLConversationServiceOperationTypePushGeolocation:
            return 11;
        case TLConversationServiceOperationTypePushTwincode:
            return 12;
        case TLConversationServiceOperationTypePushCommand:
            return 13;
        case TLConversationServiceOperationTypeUpdateAnnotations:
            return 14;
        case TLConversationServiceOperationTypeInvokeJoinGroup: // Added 2024-09-09
            return 15;
        case TLConversationServiceOperationTypeInvokeLeaveGroup:
            return 16;
        case TLConversationServiceOperationTypeInvokeAddMember:
            return 17;
        case TLConversationServiceOperationTypeUpdateObject: // Added 2025-05-21
            return 18;
    }
    return 0;
}

@end

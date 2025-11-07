/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLBaseServiceImpl.h"
#import "TLConversationServiceProvider.h"
#import "TLConversationMigration.h"
#import "TLGroupConversationImpl.h"
#import "TLGroupMemberConversationImpl.h"
#import "TLConversationServiceImpl.h"
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
#import "TLGroupOperation.h"
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

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLSerializerFactory.h"
#import "TLTwincode.h"

#if 0
static const int ddLogLevel = DDLogLevelWarning;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLConversationMigration
//

@interface TLConversationMigration ()

@property (readonly, nonnull) TLBaseService *service;
@property (readonly, nonnull) TLDatabaseService *database;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;
@property (readonly, nonnull) TLConversationFactory *conversationFactory;
@property (readonly, nonnull) NSMutableDictionary<NSUUID*, NSNumber *> *objectMap;
@property (readonly, nonnull) NSMutableDictionary<NSUUID*, NSNumber *> *twincodeToConversationIdMap;

- (void)prepareObjectMapWithTransaction:(nonnull TLTransaction *)transaction;

/// Find the descriptor database id which corresponds to the {twincodeOutboundId, sequenceId} pair.
- (nullable NSNumber *)findDescriptorWithTwincodeOutboundId:(nullable NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId transaction:(nonnull TLTransaction *)transaction;

/// Find the repositoryObject database id knowing either the object UUID or the twincode outbound (contact's identity).
- (nullable NSNumber *)findRepositoryObjectIdWithId:(nullable NSUUID *)objectId twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId;

/// Migrate the contact and group conversation to the V20 format.
- (void)upgradeConversations_V20_WithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion;

/// Migrate the group member conversation to the V20 format.
- (void)upgradeGroupMemberConversations_V20_WithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion;

/// Upgrade the conversationDescriptor table from V7/V8 to V20.
- (void)upgradeDescriptors_V20_WithTransaction:(nonnull TLTransaction *)transaction;

/// Upgrade the conversationDescriptorAnnotation table from V16 to V20.
- (void)upgradeAnnotations_V20_WithTransaction:(nonnull TLTransaction *)transaction;

/// Migrate the operations from V12 to V20 format.
- (void)upgradeOperations_V20_WithTransaction:(nonnull TLTransaction *)transaction;

/// Migrate the notification from V7 to V20.
/// This migration must be executed after migrating the descriptors.
- (void)upgradeNotifications_V20_WithTransaction:(nonnull TLTransaction *)transaction;

@end

//
// Implementation: TLConversationMigration
//

#undef LOG_TAG
#define LOG_TAG @"TLConversationMigration"

@implementation TLConversationMigration

- (nonnull instancetype)initWithService:(nonnull TLBaseService *)service database:(nonnull TLDatabaseService *)database conversationFactory:(nonnull TLConversationFactory *)conversationFactory {
    DDLogVerbose(@"%@ initWithService: %@ database: %@", LOG_TAG, service, database);
    
    self = [super init];
    if (self) {
        _service = service;
        _database = database;
        _serializerFactory = service.twinlife.serializerFactory;
        _conversationFactory = conversationFactory;
        _objectMap = [[NSMutableDictionary alloc] init];
        _twincodeToConversationIdMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)upgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ upgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);
    
    if (oldVersion < 20) {
        [self prepareObjectMapWithTransaction:transaction];
        // Do the migration in several steps in case it is interrupted by the user.
        if ([transaction hasTableWithName:@"conversationConversation"]) {
            [self upgradeConversations_V20_WithTransaction:transaction oldVersion:oldVersion];
            [self upgradeGroupMemberConversations_V20_WithTransaction:transaction oldVersion:oldVersion];
            [transaction dropTable:@"conversationConversation"];
            
            [transaction commit];
        }
        
        if ([transaction hasTableWithName:@"conversationDescriptor"]) {
            [self upgradeDescriptors_V20_WithTransaction:transaction];
            [transaction dropTable:@"conversationDescriptor"];
            [transaction commit];
        }
        
        // Annotations are introduced in V10 for iOS and V16 for Android.
        if ([transaction hasTableWithName:@"conversationDescriptorAnnotation"]) {
            if (oldVersion >= 10) {
                [self upgradeAnnotations_V20_WithTransaction:transaction];
            }
            [transaction dropTable:@"conversationDescriptorAnnotation"];
            [transaction commit];
        }
        if ([transaction hasTableWithName:@"conversationOperation"]) {
            [self upgradeOperations_V20_WithTransaction:transaction];
            [transaction dropTable:@"conversationOperation"];
            [transaction commit];
        }
        if ([transaction hasTableWithName:@"notificationNotification"]) {
            [self upgradeNotifications_V20_WithTransaction:transaction];
            [transaction dropTable:@"notificationNotification"];
        }
        // Last commit is done by DatabaseService.
    }
}

- (void)prepareObjectMapWithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ prepareObjectMapWithTransaction: %@", LOG_TAG, transaction);
    
    // Pre-load the list of contact/groups to populate the objectMap table by using the new repository table.
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT id, uuid FROM repository"];
    if (resultSet) {
        while ([resultSet next]) {
            long databaseId = [resultSet longForColumnIndex:0];
            NSUUID *uuid = [resultSet uuidForColumnIndex:1];
            
            if (uuid) {
                [self.objectMap setObject:[NSNumber numberWithLong:databaseId] forKey:uuid];
            }
        }
        [resultSet close];
    }
    
    // Pre-load the list of twincode outbound to populate the mObjectMap table by using the new twincodeOutbound table.
    resultSet = [transaction executeQuery:@"SELECT id, twincodeId FROM twincodeOutbound"];
    if (resultSet) {
        while ([resultSet next]) {
            long databaseId = [resultSet longForColumnIndex:0];
            NSUUID *uuid = [resultSet uuidForColumnIndex:1];
            
            if (uuid) {
                [self.objectMap setObject:[NSNumber numberWithLong:databaseId] forKey:uuid];
            }
        }
        [resultSet close];
    }
    
    // Pre-load the list of conversation to populate the mObjectMap table by using the new conversation table.
    // Note: this table is empty for a normal upgrade but it can contain conversations if the upgrade was interrupted!
    resultSet = [transaction executeQuery:@"SELECT c.id, c.groupId,"
                 " c.uuid, twout.twincodeId, peerTwout.twincodeId FROM conversation AS c"
                 " LEFT JOIN repository AS r ON c.subject = r.id"
                 " LEFT JOIN twincodeOutbound AS twout ON r.twincodeOutbound=twout.id"
                 " LEFT JOIN twincodeOutbound AS peerTwout ON c.peerTwincodeOutbound = peerTwout.id"];
    if (resultSet) {
        while ([resultSet next]) {
            long databaseId = [resultSet longForColumnIndex:0];
            long groupId = [resultSet longForColumnIndex:1];
            NSUUID *conversationId = [resultSet uuidForColumnIndex:2];
            NSUUID *twincodeId = [resultSet uuidForColumnIndex:3];
            NSUUID *peerTwincodeId = [resultSet uuidForColumnIndex:4];
            
            if (conversationId) {
                [self.objectMap setObject:[NSNumber numberWithLong:databaseId] forKey:conversationId];
            }
            if (twincodeId) {
                [self.twincodeToConversationIdMap setObject:[NSNumber numberWithLong:groupId > 0 ? groupId : databaseId] forKey:twincodeId];
            }
            if (peerTwincodeId) {
                [self.twincodeToConversationIdMap setObject:[NSNumber numberWithLong:groupId > 0 ? groupId : databaseId] forKey:peerTwincodeId];
            }
        }
        [resultSet close];
    }
}

- (nullable NSNumber *)findDescriptorWithTwincodeOutboundId:(nullable NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId transaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ findDescriptorWithTwincodeOutboundId: %@ sequenceId: %lld", LOG_TAG, twincodeOutboundId, sequenceId);
    
    if (!twincodeOutboundId) {
        return nil;
    }
    
    NSNumber *cid = self.twincodeToConversationIdMap[twincodeOutboundId];
    if (cid == nil) {
        return nil;
    }
    
    NSNumber *twincode = self.objectMap[twincodeOutboundId];
    if (twincode == nil) {
        return nil;
    }
    
    long result = [transaction longForQuery:@"SELECT d.id FROM descriptor AS d"
                   " WHERE d.cid=? AND d.twincodeOutbound=? AND d.sequenceId=?", cid, twincode, [NSNumber numberWithLongLong:sequenceId]];
    
    if (result == 0) {
        return nil;
    }
    
    return [NSNumber numberWithLong:result];
}

- (nullable NSNumber *)findRepositoryObjectIdWithId:(nullable NSUUID *)objectId twincodeOutboundId:(nullable NSUUID *)twincodeOutboundId {
    DDLogVerbose(@"%@ findRepositoryObjectIdWithId: %@ twincodeOutboundId: %@", LOG_TAG, objectId, twincodeOutboundId);
    
    if (objectId) {
        NSNumber *result = self.objectMap[objectId];
        if (result != nil) {
            return result;
        }
    }
    
    if (twincodeOutboundId) {
        return self.objectMap[twincodeOutboundId];
    }
    return nil;
}

- (void)upgradeConversations_V20_WithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion {
    DDLogVerbose(@"%@ upgradeDescriptors_V20_WithTransaction: %@ oldVersion: %d", LOG_TAG, transaction, oldVersion);
    
    // lastConnectDate was introduced in V10 on iOS (and V12 for Android).
    FMResultSet *resultSet;
    if (oldVersion < 10) {
        resultSet = [transaction executeQuery:@"SELECT cid, content FROM conversationConversation"];
    } else {
        resultSet = [transaction executeQuery:@"SELECT cid, content, lastConnectDate FROM conversationConversation"];
    }
    if (!resultSet) {
        return;
    }
    while ([resultSet next]) {
        NSNumber *cid = [NSNumber numberWithLongLong:[resultSet longLongIntForColumnIndex:0]];
        NSData *content = [resultSet dataForColumnIndex:1];
        int64_t lastConnectDate = oldVersion < 10 ? 0 : [resultSet longLongIntForColumnIndex:2];
        
        TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
        NSUUID *schemaId = nil;
        // int schemaVersion = -1;
        NSException *exception = nil;
        @try {
            schemaId = [decoder readUUID];
            /* schemaVersion = */ [decoder readInt];
            
            NSUUID *uuid = nil;
            NSUUID *twincodeOutboundId = nil;
            NSUUID *peerTwincodeOutboundId = nil;
            NSUUID *contactId = nil;
            NSUUID *resourceId = nil;
            NSUUID *peerResourceId = nil;
            int64_t permissions = -1L;
            int64_t joinPermissions = 0L;
            int flags = 0;
            NSObject *groupId = nil;
            
            if ([[TLConversationImpl SCHEMA_ID] isEqual:schemaId]) {
                /*
                 * <pre>
                 * Schema version 4
                 *  Date: 2016/05/19
                 * {
                 *  "type":"record",
                 *  "name":"Conversation",
                 *  "namespace":"org.twinlife.schemas.conversation",
                 *  "fields":
                 *  [
                 *   {"name":"schemaId", "type":"uuid"},
                 *   {"name":"schemaVersion", "type":"int"}
                 *   {"name":"id", "type":"uuid"}
                 *   {"name":"twincodeOutboundId", "type":"uuid"}
                 *   {"name":"peerTwincodeOutboundId", "type":"uuid"}
                 *   {"name":"twincodeInboundId", "type":"uuid"}
                 *   {"name":"contactId", "type":"uuid"}
                 *   {"name":"resourceId", "type":"uuid"}
                 *   {"name":"peerResourceId", [null, "type":"uuid"]}
                 *   {"name":"minSequenceId", "type":"long"}
                 *   {"name":"peerMinSequenceId", "type":"long"}
                 *  ]
                 * }
                 * </pre>
                 */
                uuid = [decoder readUUID];
                twincodeOutboundId = [decoder readUUID];
                peerTwincodeOutboundId = [decoder readUUID];
                /* twincodeInboundId = */ [decoder readUUID];
                contactId = [decoder readUUID];
                resourceId = [decoder readUUID];
                peerResourceId = [decoder readOptionalUUID];
                // unused minSequenceId
                // [decoder readLong];
                // unused peerMminSequenceId
                // [decoder readLong];
                groupId = [NSNull alloc];
                
            } else if ([[TLGroupConversationImpl SCHEMA_ID] isEqual:schemaId]) {
                /*
                 * <pre>
                 * Schema version 2
                 *  Date: 2020/06/19
                 * {
                 *  "type":"record",
                 *  "name":"GroupConversation",
                 *  "namespace":"org.twinlife.schemas.conversation",
                 *  "fields":
                 *  [
                 *   {"name":"schemaId", "type":"uuid"},
                 *   {"name":"schemaVersion", "type":"int"}
                 *   {"name":"id", "type":"uuid"}
                 *   {"name":"twincodeOutboundId", "type":"uuid"}
                 *   {"name":"twincodeInboundId", "type":"uuid"}
                 *   {"name":"groupTwincodeId", "type":"uuid"}
                 *   {"name":"groupId", "type":"uuid"}
                 *   {"name":"minSequenceId", "type":"long"}
                 *   {"name":"peerMinSequenceId", "type":"long"}
                 *   {"name":"permissions", "type":"long"}
                 *   {"name":"joinPermissions", "type":"long"}
                 *   {"name":"state", "type":"int"}
                 *   {"name":"invitations", [
                 *      {"name":"contactId", "type": "uuid"}
                 *      {"name":"twincodeOutboundId", "type": "uuid"}
                 *      {"name":"sequenceId", "type": "long"}
                 *   ]}
                 *  ]
                 * }
                 * </pre>
                 */
                uuid = [decoder readUUID];
                twincodeOutboundId = [decoder readUUID];
                /* twincodeInboundId =*/ [decoder readUUID];
                peerTwincodeOutboundId = [decoder readUUID];
                contactId = [decoder readUUID];
                // unused minSequenceId
                [decoder readLong];
                // unused peerMinSequenceId
                [decoder readLong];
                permissions = [decoder readLong];
                joinPermissions = [decoder readLong];
                flags = [decoder readInt];
                groupId = cid;
                // Drop the invitations because we rely on the descriptors and the invitation table.
                // The resourceId and peerResourceId are nil for the group because they are
                // defined on the GroupMemberConversation.
            }
            NSObject *peerTwincode;
            
            if (peerTwincodeOutboundId && ![[TLTwincode NOT_DEFINED] isEqual:peerTwincodeOutboundId]) {
                peerTwincode = self.objectMap[peerTwincodeOutboundId];
            } else {
                peerTwincode = nil;
            }
            NSNumber *repoObjectId = [self findRepositoryObjectIdWithId:contactId twincodeOutboundId:twincodeOutboundId];
            if (repoObjectId != nil) {
                if (!peerTwincode) {
                    peerTwincode = [NSNull alloc];
                }
                if (!uuid) {
                    uuid = [[NSUUID alloc] init];
                }
                int64_t creationDate = 0;
                [transaction executeUpdate:@"INSERT INTO conversation (id, uuid, subject, creationDate,"
                 " groupId, peerTwincodeOutbound, resourceId, peerResourceId, permissions,"
                 " joinPermissions, lastConnectDate, flags) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", cid, [TLDatabaseService toObjectWithUUID:uuid], repoObjectId, [NSNumber numberWithLongLong:creationDate], groupId, peerTwincode, [TLDatabaseService toObjectWithUUID:resourceId], [TLDatabaseService toObjectWithUUID:peerResourceId], [NSNumber numberWithLongLong:permissions], [NSNumber numberWithLongLong:joinPermissions], [NSNumber numberWithLongLong:lastConnectDate], [NSNumber numberWithInt:flags]];
                
                [self.objectMap setObject:cid forKey:uuid];
                if (twincodeOutboundId) {
                    [self.twincodeToConversationIdMap setObject:cid forKey:twincodeOutboundId];
                }
                if (peerTwincodeOutboundId) {
                    [self.twincodeToConversationIdMap setObject:cid forKey:peerTwincodeOutboundId];
                }
            }
            
        } @catch (NSException *lException) {
            exception = lException;
            DDLogError(@"%@ updateConversation: %@", LOG_TAG, lException);
        }
    }
    [resultSet close];
}

- (void)upgradeGroupMemberConversations_V20_WithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion {
    DDLogVerbose(@"%@ upgradeGroupMemberConversations_V20_WithTransaction: %@ oldVersion: %d", LOG_TAG, transaction, oldVersion);
    
    // lastConnectDate was introduced in V10 on iOS (and V12 for Android).
    FMResultSet *resultSet;
    if (oldVersion < 10) {
        resultSet = [transaction executeQuery:@"SELECT m.cid, m.groupId, g.subject, m.content"
                     " FROM conversationConversation AS m"
                     " INNER JOIN conversation AS g ON m.groupId = g.id AND m.groupId = g.groupId"];
    } else {
        resultSet = [transaction executeQuery:@"SELECT m.cid, m.groupId, g.subject, m.content, m.lastConnectDate"
                     " FROM conversationConversation AS m"
                     " INNER JOIN conversation AS g ON m.groupId = g.id AND m.groupId = g.groupId"];
    }
    if (!resultSet) {
        return;
    }
    while ([resultSet next]) {
        NSNumber *cid = [NSNumber numberWithLongLong:[resultSet longLongIntForColumnIndex:0]];
        NSNumber *groupId = [NSNumber numberWithLongLong:[resultSet longLongIntForColumnIndex:1]];
        NSNumber *subjectId = [NSNumber numberWithLongLong:[resultSet longLongIntForColumnIndex:2]];
        NSData *content = [resultSet dataForColumnIndex:3];
        int64_t lastConnectDate = oldVersion < 10 ? 0 : [resultSet longLongIntForColumnIndex:4];
        
        TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
        NSUUID *schemaId = nil;
        // int schemaVersion = -1;
        NSException *exception = nil;
        @try {
            schemaId = [decoder readUUID];
            /* schemaVersion = */ [decoder readInt];
            
            NSUUID *uuid = nil;
            NSUUID *peerTwincodeOutboundId = nil;
            NSUUID *resourceId = nil;
            NSUUID *peerResourceId = nil;
            NSUUID *invitedContactId = nil;
            int64_t permissions = 0L;
            
            if ([[TLGroupMemberConversationImpl SCHEMA_ID] isEqual:schemaId]) {
                /*
                 * <pre>
                 * Schema version 1
                 *  Date: 2020/06/19
                 * {
                 *  "type":"record",
                 *  "name":"GroupMemberConversation",
                 *  "namespace":"org.twinlife.schemas.conversation",
                 *  "fields":
                 *  [
                 *   {"name":"schemaId", "type":"uuid"},
                 *   {"name":"schemaVersion", "type":"int"}
                 *   {"name":"id", "type":"uuid"}
                 *   {"name":"peerTwincodeOutboundId", "type": "uuid"}
                 *   {"name":"resourceId", "type": "uuid"}
                 *   {"name":"minSequenceId", "type":"long"}
                 *   {"name":"peerMinSequenceId", "type":"long"}
                 *   {"name":"peerResourceId", ["null", "type":"uuid"]}]
                 *   {"name":"invitedContactId", ["null", "type":"uuid"]}]
                 *   {"name":"permissions", "type":"long"}
                 *  ]
                 * }
                 *
                 * </pre>
                 */
                uuid = [decoder readUUID];
                peerTwincodeOutboundId = [decoder readUUID];
                resourceId = [decoder readUUID];
                // unused minSequenceId
                [decoder readLong];
                // unused peerMminSequenceId
                [decoder readLong];
                peerResourceId = [decoder readOptionalUUID];
                invitedContactId = [decoder readOptionalUUID];
                permissions = [decoder readLong];
            }
            NSObject *peerTwincode;
            
            if (peerTwincodeOutboundId) {
                peerTwincode = self.objectMap[peerTwincodeOutboundId];
            } else {
                peerTwincode = nil;
            }
            if (peerTwincode) {
                int64_t creationDate = 0;
                
                [transaction executeUpdate:@"INSERT INTO conversation (id, uuid, subject, creationDate,"
                 " groupId, peerTwincodeOutbound, resourceId, peerResourceId, permissions,"
                 " joinPermissions, lastConnectDate, flags) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 0)", cid, [TLDatabaseService toObjectWithUUID:uuid], subjectId, [NSNumber numberWithLongLong:creationDate], groupId, peerTwincode, [TLDatabaseService toObjectWithUUID:resourceId], [TLDatabaseService toObjectWithUUID:peerResourceId], [NSNumber numberWithLongLong:permissions], [NSNumber numberWithLongLong:lastConnectDate]];
                
                [self.objectMap setObject:groupId forKey:uuid];
                if (peerTwincodeOutboundId) {
                    [self.twincodeToConversationIdMap setObject:groupId forKey:peerTwincodeOutboundId];
                }
            }
            
        } @catch (NSException *lException) {
            exception = lException;
            DDLogError(@"%@ updateConversation: %@", LOG_TAG, lException);
        }
    }
    [resultSet close];
}

- (void)upgradeDescriptors_V20_WithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ upgradeDescriptors_V20_WithTransaction: %@", LOG_TAG, transaction);

    NSMutableSet<NSNumber *> *conversationIds = [[NSMutableSet alloc] initWithArray:[self.twincodeToConversationIdMap allValues]];
    for (NSNumber *conversationId in conversationIds) {
        [self upgradeConversationDescriptors_V20_WithTransaction:transaction cid:conversationId];
    }
}

- (void)upgradeConversationDescriptors_V20_WithTransaction:(nonnull TLTransaction *)transaction cid:(nonnull NSNumber *)cid {
    DDLogVerbose(@"%@ upgradeConversationDescriptors_V20_WithTransaction: %@", LOG_TAG, transaction);
    
    // Scan each descriptor, extract the content and timestamps and insert in the new table.
    // We do this from oldest descriptor to the newest ones so that the `replyTo` references can be re-constructed.
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT sequenceId, createdTimestamp, twincodeOutboundId, "
                              " content, timestamps FROM conversationDescriptor WHERE cid=? ORDER BY createdTimestamp ASC", cid];
    if (!resultSet) {
        return;
    }
    while ([resultSet next]) {
        int64_t sequenceId = [resultSet longLongIntForColumnIndex:0];
        int64_t createdTimestamp = [resultSet longLongIntForColumnIndex:1];
        NSUUID *twincodeOutboundId = [resultSet uuidForColumnIndex:2];
        NSData *content = [resultSet dataForColumnIndex:3];
        NSData *timestamp = [resultSet dataForColumnIndex:4];
        
        if (!twincodeOutboundId || !content) {
            continue;
        }
        NSNumber *twincode = self.objectMap[twincodeOutboundId];
        if (twincode == nil) {
            continue;
        }
        @try {
            TLDescriptor *descriptor = [TLDescriptor extractDescriptorWithContent:content serializerFactory:self.serializerFactory timestamps:timestamp twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId createdTimestamp:createdTimestamp];
            if (descriptor) {
                // If the twincode is not associated with a conversation ID, register it.
                // This is necessary for twinrooms.
                if (self.twincodeToConversationIdMap[twincodeOutboundId] == nil) {
                    [self.twincodeToConversationIdMap setObject:cid forKey:twincodeOutboundId];
                }
                long id = [transaction allocateIdWithTable:TLDatabaseTableDescriptor];
                NSObject *sentTo = nil;
                if (descriptor.sendTo) {
                    sentTo = self.objectMap[descriptor.sendTo];
                }
                if (!sentTo) {
                    sentTo = [NSNull alloc];
                }
                NSObject *replyTo = nil;
                TLDescriptorId *replyToId = descriptor.replyTo;
                if (replyToId) {
                    replyTo = [self findDescriptorWithTwincodeOutboundId:replyToId.twincodeOutboundId sequenceId:replyToId.sequenceId transaction:transaction];
                }
                if (!replyTo) {
                    replyTo = [NSNull alloc];
                }
                NSNumber *descriptorType = [NSNumber numberWithInt:[TLConversationServiceProvider fromDescriptorType:[descriptor getType]]];
                [transaction executeUpdate:@"INSERT INTO descriptor (id, cid, sequenceId, twincodeOutbound,"
                 " sentTo, replyTo, descriptorType, creationDate, sendDate, receiveDate, readDate, updateDate,"
                 " peerDeleteDate, deleteDate, expireTimeout, flags, value, content) VALUES(?, ?, ?, ?,"
                 " ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [NSNumber numberWithLong:id], cid, [NSNumber numberWithLongLong:sequenceId], twincode, sentTo, replyTo, descriptorType, [NSNumber numberWithLongLong:createdTimestamp], [NSNumber numberWithLongLong:descriptor.sentTimestamp], [NSNumber numberWithLongLong:descriptor.receivedTimestamp], [NSNumber numberWithLongLong:descriptor.readTimestamp], [NSNumber numberWithLongLong:descriptor.updatedTimestamp], [NSNumber numberWithLongLong:descriptor.peerDeletedTimestamp], [NSNumber numberWithLongLong:descriptor.deletedTimestamp], [NSNumber numberWithLongLong:descriptor.expireTimeout], [NSNumber numberWithInt:[descriptor flags]], [NSNumber numberWithLongLong:[descriptor value]], [TLDatabaseService toObjectWithString:[descriptor serialize]]];
            }
        } @catch (NSException *lException) {
            DDLogError(@"%@ upgradeDescriptors_V20_WithTransaction: %@", LOG_TAG, lException);
        }
    }
    [resultSet close];
    [transaction executeUpdate:@"DELETE FROM conversationDescriptor WHERE cid=?", cid];
    [transaction commit];
}

- (void)upgradeAnnotations_V20_WithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ upgradeAnnotations_V20_WithTransaction: %@", LOG_TAG, transaction);
    
    // Scan each annotation, apply mapping and insert in the new table.
    long count = 0;
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT sequenceId, twincodeOutboundId,"
                                  " peerTwincodeOutboundId, kind, value FROM conversationDescriptorAnnotation"];
    if (!resultSet) {
        return;
    }
    while ([resultSet next]) {
        int64_t sequenceId = [resultSet longLongIntForColumnIndex:0];
        NSUUID *twincodeOutboundId = [resultSet uuidForColumnIndex:1];
        NSUUID *peerTwincodeOutboundId = [resultSet uuidForColumnIndex:2];
        int kind = [resultSet intForColumnIndex:3];
        int64_t value = [resultSet longLongIntForColumnIndex:4];
        
        if (!twincodeOutboundId) {
            continue;
        }
        NSNumber *cid = self.twincodeToConversationIdMap[twincodeOutboundId];
        if (cid == nil) {
            continue;
        }
        NSNumber *descriptor = [self findDescriptorWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId transaction:transaction];
        if (descriptor == nil) {
            continue;
        }
        @try {
            NSObject *peerTwincode = nil;
            if (peerTwincodeOutboundId) {
                peerTwincode = self.objectMap[peerTwincodeOutboundId];
            }
            if (!peerTwincode) {
                peerTwincode = [NSNull alloc];
            }
            [transaction executeUpdate:@"INSERT INTO annotation (cid, descriptor, peerTwincodeOutbound,"
             " kind, value) VALUES(?, ?, ?, ?, ?)", cid, descriptor, peerTwincode, [NSNumber numberWithInt:kind], [NSNumber numberWithLongLong:value]];
            count++;
        } @catch (NSException *lException) {
            DDLogError(@"%@ upgradeAnnotations_V20_WithTransaction: %@", LOG_TAG, lException);
        }
    }
    [resultSet close];
}

- (void)upgradeOperations_V20_WithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ upgradeOperations_V20_WithTransaction: %@", LOG_TAG, transaction);
    
    // Use only 'id' and 'content' so that we can also migrate V12 at the same time.
    FMResultSet *resultSet = [transaction executeQuery:@"SELECT id, content FROM conversationOperation"];
    if (!resultSet) {
        return;
    }
    while ([resultSet next]) {
        long databaseId = [resultSet longForColumnIndex:0];
        NSData *content = [resultSet dataForColumnIndex:1];
        
        TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
        NSUUID *schemaId = nil;
        int schemaVersion = -1;
        NSException *exception;
        @try {
            schemaId = [decoder readUUID];
            schemaVersion = [decoder readInt];
            
            /* int64_t unusedId = */ [decoder readLong];
            int operationType = [decoder readEnum];
            NSUUID *conversationId = [decoder readUUID];
            uint64_t timestamp = [decoder readLong];
            int64_t chunkStart = 0;
            NSObject *descriptor = [NSNull alloc];
            NSObject *newContent = [NSNull alloc];
            NSNumber *cid = self.objectMap[conversationId];

            if ([TLResetConversationOperation.SCHEMA_ID isEqual:schemaId]) {
                TLResetConversationOperation *operation;
                TLDatabaseIdentifier *databaseId = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid.longValue factory:self.conversationFactory];
                if (TLResetConversationOperation.SCHEMA_VERSION_4 == schemaVersion) {
                    operation = [TLResetConversationOperationSerializer_4 deserializeWithDecoder:decoder conversationId:databaseId];
                } else if (TLResetConversationOperation.SCHEMA_VERSION_3 == schemaVersion) {
                    operation = [TLResetConversationOperationSerializer_3 deserializeWithDecoder:decoder conversationId:databaseId];
                } else if (TLResetConversationOperation.SCHEMA_VERSION_2 == schemaVersion) {
                    operation = [TLResetConversationOperationSerializer_2 deserializeWithDecoder:decoder conversationId:databaseId];
                }
                newContent = [operation serialize];
            } else if ([TLPushObjectOperation.SCHEMA_ID isEqual:schemaId]
                       || [TLPushGeolocationOperation.SCHEMA_ID isEqual:schemaId]
                       || [TLPushTwincodeOperation.SCHEMA_ID isEqual:schemaId]
                       || [TLUpdateAnnotationsOperation.SCHEMA_ID isEqual:schemaId]) {
                NSUUID *twincodeOutboundId = [decoder readUUID];
                int64_t sequenceId = [decoder readLong];
                descriptor = [self findDescriptorWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId transaction:transaction];
                
            } else if ([TLPushFileOperation.SCHEMA_ID isEqual:schemaId]) {
                NSUUID *twincodeOutboundId = [decoder readUUID];
                int64_t sequenceId = [decoder readLong];
                descriptor = [self findDescriptorWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId transaction:transaction];
                chunkStart = [decoder readLong];
                
            } else if ([TLUpdateDescriptorTimestampOperation.SCHEMA_ID isEqual:schemaId]) {
                TLUpdateDescriptorTimestampType timestampType;
                int value = [decoder readEnum];
                switch (value) {
                    case 0:
                        timestampType = TLUpdateDescriptorTimestampTypeRead;
                        break;
                    case 1:
                        timestampType = TLUpdateDescriptorTimestampTypeDelete;
                        break;
                    case 2:
                        timestampType = TLUpdateDescriptorTimestampTypePeerDelete;
                        break;
                        
                    default:
                        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
                        break;
                }
                NSUUID *twincodeOutboundId = [decoder readUUID];
                int64_t sequenceId = [decoder readLong];
                descriptor = [self findDescriptorWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId transaction:transaction];
                int64_t timestamp = [decoder readLong];
                newContent = [TLUpdateDescriptorTimestampOperation serializeOperation:timestampType timestamp:timestamp descriptorId:[[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId]];
                
            } else if ([TLGroupOperation.SCHEMA_ID isEqual:schemaId]) {
                int mode = [decoder readInt];
                if (mode == 0) {
                    NSUUID *groupTwincodeId = [decoder readUUID];
                    NSUUID *memberTwincodeId = [decoder readUUID];
                    int64_t permissions = [decoder readLong];
                    newContent = [TLGroupOperation serializeOperation:groupTwincodeId memberTwincodeId:memberTwincodeId permissions:permissions publicKey:nil signedOffTwincodeId:nil signature:nil];
                    
                } else {
                    int64_t sequenceId = [decoder readLong];
                    NSUUID *twincodeOutboundId = [decoder readUUID];
                    descriptor = [self findDescriptorWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId transaction:transaction];
                }
            }
            
            if (cid != nil) {
                [transaction executeUpdate:@"INSERT INTO operation (id, cid, creationDate,"
                 " type, descriptor, chunkStart, content) VALUES(?, ?, ?, ?, ?, ?, ?)", [NSNumber numberWithLong:databaseId], cid, [NSNumber numberWithLongLong:timestamp], [NSNumber numberWithInt:operationType], descriptor, [NSNumber numberWithLongLong:chunkStart], newContent];
            }
        } @catch (NSException *lException) {
            exception = lException;
            DDLogError(@"%@ upgradeOperations: %@", LOG_TAG, lException);
        }
    }
    [resultSet close];
}

- (void)upgradeNotifications_V20_WithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ upgradeNotifications_V20_WithTransaction: %@", LOG_TAG, transaction);
    
    FMResultSet *resultSet;
    resultSet = [transaction executeQuery:@"select uuid, content from notificationNotification"];
    if (!resultSet) {
        return;
    }
    while ([resultSet next]) {
        NSUUID *notificationId = [resultSet uuidForColumnIndex:0];
        NSData *content = [resultSet dataForColumnIndex:1];
        if (content && notificationId) {
            TLBinaryDecoder *decoder = [[TLBinaryDecoder alloc] initWithData:content];
            // int schemaVersion = -1;
            NSException *exception = nil;
            @try {
                /* schemaId = */ [decoder readUUID];
                /* schemaVersion =*/ [decoder readInt];
                
                /* NSUUID *id = */ [decoder readUUID];
                int notificationType = [decoder readInt];
                NSUUID *originatorId = [decoder readUUID];
                int64_t timestamp = [decoder readLong];
                BOOL acknowledged = [decoder readBoolean];
                /* BOOL isGroup = */ [decoder readBoolean];
                int64_t sequenceId = [decoder readLong];
                NSUUID *twincodeOutboundId = nil;
                if (sequenceId != 0) {
                    twincodeOutboundId = [decoder readUUID];
                }
                NSNumber *repoObjectId = [self findRepositoryObjectIdWithId:originatorId twincodeOutboundId:twincodeOutboundId];
                if (repoObjectId != nil) {
                    NSNumber *descriptorId = nil;
                    if (twincodeOutboundId) {
                        descriptorId = [self findDescriptorWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId transaction:transaction];
                    }
                    int flags = acknowledged ? 1 : 0;
                    long nid = [transaction allocateIdWithTable:TLDatabaseTableNotification];
                    [transaction executeUpdate:@"INSERT INTO notification (id, uuid, type, creationDate,"
                     " flags, subject, descriptor) VALUES(?, ?, ?, ?, ?, ?, ?)", [NSNumber numberWithLong:nid], [TLDatabaseService toObjectWithUUID:notificationId], [NSNumber numberWithInt:notificationType], [NSNumber numberWithLongLong:timestamp], [NSNumber numberWithInt:flags], repoObjectId, descriptorId];
                }
                
            } @catch (NSException *lException) {
                exception = lException;
                DDLogError(@"%@ updateNotifications: %@", LOG_TAG, lException);
            }
        }
    }
    [resultSet close];
}

@end

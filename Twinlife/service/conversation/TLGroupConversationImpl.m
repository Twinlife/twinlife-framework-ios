/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLConversationImpl.h"
#import "TLGroupConversationImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLTwincodeInboundService.h"
#import "TLRepositoryService.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLTwincode.h"

#if 0
static const int ddLogLevel = DDLogLevelWarning;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define FLAG_JOINED    0x01
#define FLAG_LEAVING   0x02
#define FLAG_DELETED   0x04

static NSUUID *GROUP_CONVERSATION_SCHEMA_ID = nil;
static int GROUP_CONVERSATION_SCHEMA_VERSION = 2;

//
// Interface: TLGroupConversationObject ()
//

@interface TLGroupConversationImpl ()

@property (readonly, nonnull) NSMutableDictionary<NSUUID*,TLGroupMemberConversationImpl*> *members;

@end

//
// Implementation: TLGroupConversationFactory
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupConversationFactory"

@implementation TLGroupConversationFactory

+ (void)initialize {
    
    GROUP_CONVERSATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"963f8d06-1a57-4c54-a6ce-0f1fec3064c6"];
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
    return GROUP_CONVERSATION_SCHEMA_ID;
}

- (int)schemaVersion {
    
    // This is informational: the value is not stored in the database (but used in the TLDatabaseIdentifier).
    return GROUP_CONVERSATION_SCHEMA_VERSION;
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
    // We don't use it for the group conversation since we use the GroupMemberConversation for each member.
    // long peerTwincodeOutbound = cursor.getLong(offset + 4);
    NSUUID *resourceId = [cursor uuidForColumnIndex:offset + 5];
    // NSUUID *peerResourceId = [cursor uuidForColumnIndex:offset + 6];
    int64_t permissions = [cursor longLongIntForColumnIndex:offset + 7];
    long joinPermissions = [cursor longLongIntForColumnIndex:offset + 8];
    // int64_t lastConnectDate = [cursor longLongIntForColumnIndex:offset + 9];
    // int64_t lastRetryDate = [cursor longLongIntForColumnIndex:offset + 10];
    int flags = [cursor intForColumnIndex:offset + 11];
    // long descriptorCount = [cursor longForColumnIndex:offset + 12];
    id<TLRepositoryObject> subject = [self.database loadRepositoryObjectWithId:subjectId schemaId:schemaId];
    if (!subject) {
        return nil;
    }
    
    TLGroupConversationImpl *result = [[TLGroupConversationImpl alloc] initWithIdentifier:identifier conversationId:conversationId subject:subject creationDate:creationDate resourceId:resourceId permissions:permissions joinPermissions:joinPermissions flags:flags];
    [self loadMembersWithGroup:result];
    return result;
}

- (BOOL)loadWithObject:(nonnull id<TLDatabaseObject>)object cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ loadWithObject: %@", LOG_TAG, object);
    
    // Ignore fields which are read-only.
    int64_t permissions = [cursor longLongIntForColumnIndex:offset + 7];
    long joinPermissions = [cursor longLongIntForColumnIndex:offset + 8];
    // int64_t lastConnectDate = [cursor longLongIntForColumnIndex:offset + 9];
    // int64_t lastRetryDate = [cursor longLongIntForColumnIndex:offset + 10];
    int flags = [cursor intForColumnIndex:offset + 11];
    
    TLGroupConversationImpl *conversation = (TLGroupConversationImpl *)object;
    [conversation updateWithPermissions:permissions joinPermissions:joinPermissions flags:flags];
    [self loadMembersWithGroup:conversation];
    return YES;
}

- (void)loadMembersWithGroup:(nonnull TLGroupConversationImpl *)group {
    DDLogVerbose(@"%@ loadMembersWithGroup: %@", LOG_TAG, group);

    [self.database inDatabase:^(FMDatabase *database) {
        NSNumber *groupId = [group.identifier identifierNumber];
        FMResultSet *resultSet = [database executeQuery:@"SELECT c.id, c.uuid, c.creationDate,"
                                  " c.peerTwincodeOutbound, c.resourceId, c.peerResourceId, c.permissions,"
                                  " c.lastConnectDate, c.lastRetryDate, c.flags FROM conversation AS c"
                                  " WHERE c.groupId=? AND c.id!=? ORDER BY c.id ASC", groupId, groupId];
        if (!resultSet) {
            return;
        }

        // Get list of existing members in the group.
        NSMutableDictionary<NSUUID *, TLGroupMemberConversationImpl *> *members = [group listMembers];
        while ([resultSet next]) {
            long cid = [resultSet longForColumnIndex:0];
            NSUUID *conversationId = [resultSet uuidForColumnIndex:1];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:2];
            long peerTwincodeOutboundId = [resultSet longForColumnIndex:3];
            NSUUID *resourceId = [resultSet uuidForColumnIndex:4];
            NSUUID *peerResourceId = [resultSet uuidForColumnIndex:5];
            int64_t permissions = [resultSet longLongIntForColumnIndex:6];
            int64_t lastConnectDate = [resultSet longLongIntForColumnIndex:7];
            int64_t lastRetryDate = [resultSet longLongIntForColumnIndex:8];
            int flags = [resultSet intForColumnIndex:9];
            
            TLTwincodeOutbound *peerTwincodeOutbound = [self.database loadTwincodeOutboundWithId:peerTwincodeOutboundId];
            if (peerTwincodeOutbound) {
                NSUUID *memberTwincodeId = peerTwincodeOutbound.uuid;
                TLGroupMemberConversationImpl *member = members[memberTwincodeId];
                if (member) {
                    [members removeObjectForKey:memberTwincodeId];
                    [member updateWithPeerResourceId:peerResourceId permissions:permissions lastConnectDate:lastConnectDate lastRetryDate:lastRetryDate flags:flags];
                } else {
                    TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:cid factory:self];
                    member = [[TLGroupMemberConversationImpl alloc] initWithIdentifier:identifier conversationId:conversationId group:group creationDate:creationDate resourceId:resourceId peerResourceId:peerResourceId permissions:permissions lastConnectDate:lastConnectDate lastRetryDate:lastRetryDate flags:flags peerTwincodeOutbound:peerTwincodeOutbound invitedContactId:nil];
                    member = [group addMemberWithConversation:member];
                    
                    // Make sure the group member is also part of the cache because
                    // we rely on it for getConversationWithId().
                    [self.database putCacheWithObject:member];
                }
            }
        }
        [resultSet close];

        // Remove members that have been deleted from the database.
        if (members.count > 0) {
            for (NSUUID *memberTwincodeId in members) {
                TLGroupMemberConversationImpl *member = [group delMemberWithTwincodeId:memberTwincodeId];
                if (member) {
                    [self.database evictCacheWithIdentifier:member.databaseId];
                }
            }
        }
    }];
}

@end

//
// Implementation: TLGroupConversation
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupConversationImpl"

@implementation TLGroupConversationImpl

@synthesize uuid = _uuid;
@synthesize subject = _subject;
@synthesize joinPermissions = _joinPermissions;

+ (NSUUID *)SCHEMA_ID {
    
    return GROUP_CONVERSATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return GROUP_CONVERSATION_SCHEMA_VERSION;
}

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier conversationId:(nonnull NSUUID *)conversationId subject:(nonnull id<TLRepositoryObject>)subject creationDate:(int64_t)creationDate resourceId:(nonnull NSUUID *)resourceId permissions:(int64_t)permissions joinPermissions:(int64_t)joinPermissions flags:(int)flags {

    self = [super init];
    if (self) {
        _databaseId = identifier;
        _uuid = conversationId;
        _subject = subject;
        _creationDate = creationDate;
        _flags = flags;
        _permissions = permissions;
        _joinPermissions = joinPermissions;
        _members = [[NSMutableDictionary alloc] init];
        _incomingConversation = [[TLGroupMemberConversationImpl alloc] initWithIdentifier:identifier conversationId:conversationId group:self creationDate:creationDate resourceId:resourceId peerResourceId:nil permissions:permissions lastConnectDate:0 lastRetryDate:0 flags:0 peerTwincodeOutbound:subject.twincodeOutbound invitedContactId:nil];
    }

    return self;
}

- (void)updateWithPermissions:(int64_t)permissions joinPermissions:(int64_t)joinPermissions flags:(int)flags {
    DDLogVerbose(@"%@ updateWithPermissions: %lld joinPermissions: %lld flags: %d", LOG_TAG, permissions, joinPermissions, flags);

    @synchronized (self) {
        self.permissions = permissions;
        self.joinPermissions = joinPermissions;
        self.flags = flags;
    }
}

#pragma - mark Members

- (nonnull NSMutableDictionary<NSUUID*,TLGroupMemberConversationImpl*> *)listMembers {
    DDLogVerbose(@"%@ TLGroupMemberConversationImpl", LOG_TAG);

    @synchronized (self) {
        return [[NSMutableDictionary alloc] initWithDictionary:self.members];
    }
}

- (nonnull TLGroupMemberConversationImpl *)addMemberWithConversation:(nonnull TLGroupMemberConversationImpl *)member {
    DDLogVerbose(@"%@ addMemberWithConversation: %@", LOG_TAG, member);

    TLGroupMemberConversationImpl *result;
    @synchronized (self) {
        result = self.members[member.peerTwincodeOutboundId];
        if (!result) {
            result = member;
            [self.members setObject:member forKey:member.peerTwincodeOutboundId];
        }
    }
    return result;
}

- (void)rejoin {
    DDLogVerbose(@"%@ rejoin", LOG_TAG);

    @synchronized (self) {
        self.flags = 0;
        self.permissions = -1L;
        self.joinPermissions = -1L;
    }
}

- (nullable TLGroupMemberConversationImpl *)delMemberWithTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ delMemberWithTwincodeId: %@", LOG_TAG, memberTwincodeId);

    TLGroupMemberConversationImpl *result;
    @synchronized (self) {
        result = self.members[memberTwincodeId];
        if (result) {
            [self.members removeObjectForKey:memberTwincodeId];
        }
    }
    return result;
}

- (nullable TLGroupMemberConversationImpl *)getMemberWithTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ getMemberWithTwincodeId: %@", LOG_TAG, memberTwincodeId);

    @synchronized (self) {
        return self.members[memberTwincodeId];
    }
}

- (nullable TLGroupMemberConversationImpl *)leaveGroupWithTwincodeId:(nonnull NSUUID *)memberTwincodeId {
    DDLogVerbose(@"%@ leaveGroupWithTwincodeId: %@", LOG_TAG, memberTwincodeId);

    @synchronized (self) {
        if ([self.twincodeOutboundId isEqual:memberTwincodeId]) {
            if ((self.flags & (FLAG_LEAVING | FLAG_DELETED)) != 0) {
                return nil;
            }
            self.flags |= FLAG_LEAVING;
            self.permissions = 0;
            self.joinPermissions = 0;
            return self.incomingConversation;
        } else {
            TLGroupMemberConversationImpl *member = self.members[memberTwincodeId];
            if (member) {
                [member markLeaving];
            }
            return member;
        }
    }
}

- (BOOL)isEmpty {
    DDLogVerbose(@"%@ isEmpty", LOG_TAG);

    @synchronized (self) {
        return self.members.count == 0;
    }
}

- (BOOL)hasPeer {
    DDLogVerbose(@"%@ hasPeer", LOG_TAG);

    @synchronized (self) {
        return self.members.count != 0;
    }
}

- (nullable TLGroupMemberConversationImpl *)firstMember {
    DDLogVerbose(@"%@ firstMember", LOG_TAG);

    @synchronized(self) {
        // Get the first member (??? thanks Apple for not providing a first element accessor)
        for (NSUUID *member in self.members) {
            TLGroupMemberConversationImpl *peer = self.members[member];
            if (![member isEqual:peer.peerTwincodeOutboundId]) {
                DDLogVerbose(@"%@ Invalid Twincode: %@", LOG_TAG, member);
            }
            return peer;
        }
    }
    return nil;
}

- (nullable TLGroupMemberConversationImpl *)getConversationWithId:(int64_t)conversationId {
    DDLogVerbose(@"%@ getConversationWithId", LOG_TAG);

    @synchronized(self) {
        for (NSUUID *member in self.members) {
            TLGroupMemberConversationImpl *peer = self.members[member];
            if (peer.databaseId.identifier == conversationId) {
                return peer;
            }
        }
    }
    return nil;
}

- (BOOL)joinWithPermissions:(int64_t)permissions {
    DDLogVerbose(@"%@ joinWithPermissions: %lld", LOG_TAG, permissions);

    @synchronized (self) {
        if ((self.flags & (FLAG_DELETED | FLAG_LEAVING)) != 0) {
            return NO;
        }
        
        // If we are already joined, keep the current permissions.
        if ((self.flags & FLAG_JOINED) == 0) {
            self.flags |= FLAG_JOINED;
            self.permissions = permissions;
            self.joinPermissions = permissions;
            self.incomingConversation.permissions = permissions;
        }
    }
    return YES;
}

- (nonnull NSMutableArray<TLConversationImpl *> *)getConversations:(nullable NSUUID *)sendTo {
    DDLogVerbose(@"%@ getConversations: %@", LOG_TAG, sendTo);

    NSMutableArray<TLConversationImpl *> *result = [[NSMutableArray alloc] init];
    @synchronized (self) {
        for (TLGroupMemberConversationImpl *peer in [self.members allValues]) {
            if (![peer isLeaving] && (!sendTo || [sendTo isEqual:peer.peerTwincodeOutboundId])) {
                [result addObject:peer];
            }
        }
    }
    return result;
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
    
    return true;
}

- (BOOL)isActive {

    @synchronized (self) {
        return (self.flags & (FLAG_DELETED | FLAG_LEAVING)) == 0;
    }
}

- (BOOL)isConversationWithUUID:(NSUUID *)id {
    
    return [self.uuid isEqual:id];
}

- (BOOL)hasPermissionWithPermission:(TLPermissionType)permission {
    
    return (permission != TLPermissionTypeNone) && (self.permissions & (1 << permission)) != 0;
}

- (nullable TLTwincodeOutbound *)peerTwincodeOutbound { 
    
    return [self.subject peerTwincodeOutbound];
}

- (TLGroupConversationStateType) state {
    
    @synchronized (self) {
        int flags = self.flags;
        if ((flags & FLAG_DELETED) != 0) {
            return TLGroupConversationStateDeleted;
        }
        if ((flags & FLAG_LEAVING) != 0) {
            return TLGroupConversationStateLeaving;
        }
        if ((flags & FLAG_JOINED) != 0) {
            return TLGroupConversationStateJoined;
        }
        return TLGroupConversationStateCreated;
    }
}

- (NSMutableArray<id<TLGroupMemberConversation>>*)groupMembersWithFilter:(TLGroupMemberFilterType)filter {
    
    NSMutableArray<id<TLGroupMemberConversation>> *result = [[NSMutableArray alloc] init];
    @synchronized (self) {
        for (NSUUID *uuid in self.members) {
            TLGroupMemberConversationImpl *member = self.members[uuid];
            if (filter == TLGroupMemberFilterTypeAllMembers || ![member isLeaving]) {
                [result addObject:member];
            }
        }
    }
    return result;
}

- (long)activeMemberCount {
    DDLogVerbose(@"%@ activeMemberCount", LOG_TAG);

    long count = 0;
    @synchronized (self) {
        for (NSUUID *memberTwincodeId in self.members) {
            TLGroupMemberConversationImpl *member = self.members[memberTwincodeId];
            if (![member isLeaving]) {
                count++;
            }
        }
    }
    
    return count;
}

#pragma - mark NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"TLGroupConversation[%@ twincodeOutboundId: %@", self.databaseId, [self.twincodeOutboundId UUIDString]];
    [string appendFormat:@" peerTwincodeOutboundId: %@", [self.peerTwincodeOutboundId UUIDString]];
    [string appendFormat:@" twincodeInboundId: %@\n", [self.twincodeInboundId UUIDString]];
    [string appendFormat:@" subject: %@\n", self.subject];
    [string appendFormat:@" groupTwincodeId: %@", [self.peerTwincodeOutboundId UUIDString]];
    [string appendFormat:@" groupState: %d]", self.state];
    return string;
}

@end

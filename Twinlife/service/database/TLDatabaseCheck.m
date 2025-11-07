/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLDatabaseCheck.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#undef LOG_TAG
#define LOG_TAG @"TLDatabaseCheck"

//
// Implementation: TLDatabaseCheck
//

@implementation TLDatabaseCheck

- (nonnull instancetype)initWithException:(nonnull NSException *)exception name:(nonnull NSString *)name {
    
    self = [super init];
    if (self) {
        _name = name;
        _message = [NSString stringWithFormat:@"Exception %@\nReason: %@", exception.name, exception.reason];
    }
    return self;
}

- (nonnull instancetype)initWithMessage:(nonnull NSString *)message name:(nonnull NSString *)name {
    
    self = [super init];
    if (self) {
        _name = name;
        _message = message;
    }
    return self;
}

+ (nonnull NSString *)toDisplay:(nullable NSString *)value {
    
    if (!value) {
        return @"    -   ";
    } else if (value.length <= 6) {
        return value;
    } else {
        return [value substringToIndex:6];
    }
}

+ (nonnull NSString *)toTimeDisplay:(int64_t)timestamp {
    
    return [NSString stringWithFormat:@"%10lld %3d", timestamp / 1000LL, (int) (timestamp % 1000LL)];
}

#define CHECK_CONVERSATION_WITH_REPOSITORY @"Check consistency (PEER != PwID):"

// Query to list conversation not consistent with the repository
// We should have: c.peerTwincodeOutbound == c.subject.peerTwincodeOutbound
+ (nullable TLDatabaseCheck *)checkConversationRepositoryWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ checkConversationRepositoryWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " c.id, c.groupId, c.subject, c.peerTwincodeOutbound,"
                     " r.twincodeOutbound, r.peerTwincodeOutbound, r.schemaId,"
                     " c.flags, r2.id, r2.schemaId"
                     " FROM repository AS r"
                     " LEFT JOIN conversation AS c on c.subject = r.id"
                     " LEFT JOIN repository AS r2 ON r2.peerTwincodeOutbound = c.peerTwincodeOutbound"
                     " WHERE (c.groupId IS NULL OR c.id = c.groupId) AND c.peerTwincodeOutbound != r.peerTwincodeOutbound"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:CHECK_CONVERSATION_WITH_REPOSITORY];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"|  CID |  GRP | SUB | PEER | TID | PID | SCHEMA | FLGS | SUBJ2 | SCHEMA2 |\n"];
            }
            long cid = [resultSet longForColumnIndex:0];
            long gid = [resultSet longForColumnIndex:1];
            long subjectId = [resultSet longForColumnIndex:2];
            long peerTwincodeId = [resultSet longForColumnIndex:3];
            long twincodeId = [resultSet longForColumnIndex:4];
            long repoPeerTwincodeId = [resultSet longForColumnIndex:5];
            NSString *rSchemaId = [resultSet stringForColumnIndex:6];
            int flags = [resultSet intForColumnIndex:7];
            long subject2Id = [resultSet longForColumnIndex:8];
            NSString *r2SchemaId = [resultSet stringForColumnIndex:9];
            
            [content appendFormat:@"| %4ld | %4ld | %3ld | %4ld | %3ld | %3ld | %@ |  %03x | %5ld | %@ |\n", cid, gid, subjectId, peerTwincodeId, twincodeId, repoPeerTwincodeId, [TLDatabaseCheck toDisplay:rSchemaId], flags, subject2Id, [TLDatabaseCheck toDisplay:r2SchemaId]];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:CHECK_CONVERSATION_WITH_REPOSITORY] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:CHECK_CONVERSATION_WITH_REPOSITORY];
    }
}

#define CHECK_ORPHANED_GROUP_CONVERSATION @"Orphaned group member (GRP not found):"

// Query to list the group members without a group conversation.
+ (nullable TLDatabaseCheck *)checkOrphanedGroupMemberConversationWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ checkOrphanedGroupMemberConversationWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                                  " c.id, c.groupId, c.subject, c.peerTwincodeOutbound, c.flags, twout.twincodeId,"
                                  " (SELECT COUNT(d.id) FROM descriptor AS d WHERE d.cid = c.id),"
                                  " (SELECT COUNT(op.id) FROM operation AS op WHERE op.cid = c.id)"
                                  " FROM conversation AS c"
                                  " LEFT JOIN conversation AS g ON c.groupId = g.id"
                                  " LEFT JOIN twincodeOutbound AS twout ON c.peerTwincodeOutbound = twout.id"
                                  " WHERE c.groupId  IS  NOT NULL AND g.id IS NULL"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:CHECK_ORPHANED_GROUP_CONVERSATION];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"| CID  |  GRP | SUB | PID |   TOUT | FLGS | DCNT | OCNT |\n"];
            }
            long cid = [resultSet longForColumnIndex:0];
            long gid = [resultSet longForColumnIndex:1];
            long subjectId = [resultSet longForColumnIndex:2];
            long peerTwincode = [resultSet longForColumnIndex:3];
            int flags = [resultSet intForColumnIndex:4];
            NSString *twincodeId = [resultSet stringForColumnIndex:5];
            int descriptorCount = [resultSet intForColumnIndex:6];
            int opCount = [resultSet intForColumnIndex:7];
            
            [content appendFormat:@"| %4ld | %4ld | %3ld | %3ld | %@ |  %03x | %4d | %4d |\n", cid, gid, subjectId, peerTwincode, [TLDatabaseCheck toDisplay:twincodeId], flags, descriptorCount, opCount];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:CHECK_ORPHANED_GROUP_CONVERSATION] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:CHECK_ORPHANED_GROUP_CONVERSATION];
    }
}

#define CHECK_MISSING_PEER_TWINCODE_CONVERSATION @"Missing peer twincode (PEER not found):"

// Missing peer twincode in conversation
+ (nullable TLDatabaseCheck *)checkMissingPeerTwincodeConversationWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ checkMissingPeerTwincodeConversationWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " c.id, c.groupId, c.flags, c.subject, c.peerTwincodeOutbound"
                     " FROM conversation AS c"
                     " LEFT JOIN twincodeOutbound AS twout ON c.peerTwincodeOutbound = twout.id"
                     " WHERE twout.id IS NULL"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:CHECK_MISSING_PEER_TWINCODE_CONVERSATION];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"| CID  |  GRP | FLGS | SUB | PID |\n"];
            }
            long cid = [resultSet longForColumnIndex:0];
            long gid = [resultSet longForColumnIndex:1];
            int flags = [resultSet intForColumnIndex:2];
            long subjectId = [resultSet longForColumnIndex:3];
            long peerTwincodeId = [resultSet longForColumnIndex:4];
  
            [content appendFormat:@"| %4ld | %4ld |  %03x | %3ld | %3ld |\n", cid, gid, flags, subjectId, peerTwincodeId];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:CHECK_MISSING_PEER_TWINCODE_CONVERSATION] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:CHECK_MISSING_PEER_TWINCODE_CONVERSATION];
    }
}

#define CHECK_MISSING_IDENTITY_TWINCODE_CONVERSATION @"Missing twincode in repository (TID not found):"

// Missing peer twincode in conversation
+ (nullable TLDatabaseCheck *)checkMissingIdentityTwincodeWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ checkMissingIdentityTwincodeWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " r.id, r.owner, r.schemaId, r.flags, r.twincodeOutbound"
                     " FROM repository AS r"
                     " LEFT JOIN twincodeOutbound AS twout ON r.twincodeOutbound = twout.id"
                     " WHERE (r.twincodeOutbound IS NOT NULL AND twout.id IS NULL)"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:CHECK_MISSING_IDENTITY_TWINCODE_CONVERSATION];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"| SUB | OWN | SCHEMA | FLGS | TID |\n"];
            }
            long subjectId = [resultSet longForColumnIndex:0];
            long ownerId = [resultSet longForColumnIndex:1];
            NSString *schemaId = [resultSet stringForColumnIndex:2];
            int flags = [resultSet intForColumnIndex:3];
            long twincodeId = [resultSet longForColumnIndex:4];
  
            [content appendFormat:@"| %3ld | %3ld | %@ |  %03x | %3ld |\n", subjectId, ownerId, [TLDatabaseCheck toDisplay:schemaId], flags, twincodeId];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:CHECK_MISSING_IDENTITY_TWINCODE_CONVERSATION] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:CHECK_MISSING_IDENTITY_TWINCODE_CONVERSATION];
    }
}

#define CHECK_MISSING_PEER_TWINCODE_REPOSITORY @"Missing peer in repository (PID not found):"

// Missing peer twincode in conversation
+ (nullable TLDatabaseCheck *)checkMissingPeerTwincodeRepositoryWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ checkMissingPeerTwincodeRepositoryWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " r.id, r.owner, r.schemaId, r.flags, r.twincodeOutbound, r.peerTwincodeOutbound,"
                     " c.id, c.groupId, c.peerTwincodeOutbound, c.flags"
                     " FROM repository AS r"
                     " LEFT JOIN conversation AS c on r.id = c.subject"
                     " LEFT JOIN twincodeOutbound AS peerOut ON r.peerTwincodeOutbound = peerOut.id"
                     " WHERE (r.peerTwincodeOutbound IS NOT NULL AND peerOut.id IS NULL)"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:CHECK_MISSING_PEER_TWINCODE_REPOSITORY];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"| SUB | OWN | SCHEMA | RFLG | TID | PID |  CID |  GRP | PEER | CFLG |\n"];
            }
            long subjectId = [resultSet longForColumnIndex:0];
            long ownerId = [resultSet longForColumnIndex:1];
            NSString *schemaId = [resultSet stringForColumnIndex:2];
            int flags = [resultSet intForColumnIndex:3];
            long twincodeId = [resultSet longForColumnIndex:4];
            long peerTwincodeId = [resultSet longForColumnIndex:5];
            long cid = [resultSet longForColumnIndex:6];
            long gid = [resultSet longForColumnIndex:7];
            long conversationPeerTwincodeId = [resultSet longForColumnIndex:8];
            int conversationFlags = [resultSet intForColumnIndex:9];

            [content appendFormat:@"| %3ld | %3ld | %6@ |  %03x | %3ld | %3ld | %4ld | %4ld | %4ld | %03x |\n", subjectId, ownerId, [TLDatabaseCheck toDisplay:schemaId], flags, twincodeId, peerTwincodeId, cid, gid, conversationPeerTwincodeId, conversationFlags];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:CHECK_MISSING_PEER_TWINCODE_REPOSITORY] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:CHECK_MISSING_PEER_TWINCODE_REPOSITORY];
    }
}

#define DUMP_REPOSITORY @"Repository:"

+ (nullable TLDatabaseCheck *)dumpRepositoryWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ dumpRepositoryWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " r.id, r.owner, r.schemaId, r.twincodeInbound, r.twincodeOutbound, r.peerTwincodeOutbound,"
                     " r.creationDate, r.modificationDate - r.creationDate"
                     " FROM repository AS r"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:DUMP_REPOSITORY];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"| SUB | OWN | SCHEMA | TIN | TID | PID |    CREATE DATE |         MODIF |\n"];
            }
            long subjectId = [resultSet longForColumnIndex:0];
            long ownerId = [resultSet longForColumnIndex:1];
            NSString *schemaId = [resultSet stringForColumnIndex:2];
            long twincodeInId = [resultSet longForColumnIndex:3];
            long twincodeId = [resultSet longForColumnIndex:4];
            long peerTwincodeId = [resultSet longForColumnIndex:5];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:6];
            int64_t modifDelta = [resultSet longLongIntForColumnIndex:7];

            [content appendFormat:@"| %3ld | %3ld | %@ | %3ld | %3ld | %3ld | %@ | %13lld |\n", subjectId, ownerId, [TLDatabaseCheck toDisplay:schemaId], twincodeInId, twincodeId, peerTwincodeId, [TLDatabaseCheck toTimeDisplay:creationDate], modifDelta];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:DUMP_REPOSITORY] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:DUMP_REPOSITORY];
    }
}

+ (nullable TLDatabaseCheck *)dumpTwincodesWithDatabase:(nonnull FMDatabase *)database secure:(BOOL)secure name:(nonnull NSString *)name sql:(nonnull NSString *)sql {
    DDLogVerbose(@"%@ dumpTwincodesWithDatabase: %@ secure: %d", LOG_TAG, database, secure);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:sql];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:name];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"|  TID |  UUID  |  IMG | FLGS |    CREATE DATE |         MODIF |       REFRESH |\n"];
            }
            long tid = [resultSet longForColumnIndex:0];
            NSString *twincodeId = [resultSet stringForColumnIndex:1];
            long avatarId = [resultSet longForColumnIndex:2];
            int flags = [resultSet intForColumnIndex:3];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:4];
            int64_t modifDelta = [resultSet longLongIntForColumnIndex:5];
            int64_t refreshDelta = [resultSet longLongIntForColumnIndex:6];

            if (secure) {
                twincodeId = @"...";
            }
            [content appendFormat:@"| %4ld | %@ | %4ld | %04x | %@ | %13lld | %13lld |\n", tid, [TLDatabaseCheck toDisplay:twincodeId], avatarId, flags, [TLDatabaseCheck toTimeDisplay:creationDate], modifDelta, refreshDelta];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:name] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:name];
    }
}

#define DUMP_TWINCODES @"TOUT:"

+ (nullable TLDatabaseCheck *)dumpTwincodesWithDatabase:(nonnull FMDatabase *)database secure:(BOOL)secure {
    DDLogVerbose(@"%@ dumpTwincodesWithDatabase: %@ secure: %d", LOG_TAG, database, secure);

    return [self dumpTwincodesWithDatabase:database secure:secure name:DUMP_TWINCODES sql:@"SELECT"
            " t.id, t.twincodeId, t.avatarId, t.flags,"
            " t.creationDate,"
            " t.modificationDate - t.creationDate,"
            " (CASE WHEN t.refreshDate = 0 THEN 0 ELSE t.refreshDate - t.creationDate END)"
            " FROM twincodeOutbound AS t"
            " LEFT JOIN repository AS r1 ON t.id = r1.twincodeOutbound"
            " LEFT JOIN repository AS r2 ON t.id = r2.peerTwincodeOutbound"
            " LEFT JOIN conversation AS c ON t.id = c.peerTwincodeOutbound"
            " LEFT JOIN descriptor AS d ON t.id = d.twincodeOutbound"
            " WHERE (r1.id IS NOT NULL) OR (r2.id IS NOT NULL) OR (c.id IS NOT NULL) OR (d.id IS NOT NULL)"
            " GROUP BY t.id"];
}

#define DUMP_ORPHANED_TWINCODES @"Twincode OUT (TID not referenced):"

+ (nullable TLDatabaseCheck *)dumpOrphanedTwincodesWithDatabase:(nonnull FMDatabase *)database secure:(BOOL)secure {
    DDLogVerbose(@"%@ dumpOrphanedTwincodesWithDatabase: %@ secure: %d", LOG_TAG, database, secure);

    return [self dumpTwincodesWithDatabase:database secure:secure name:DUMP_ORPHANED_TWINCODES sql:@"SELECT"
            " t.id, t.twincodeId, t.avatarId, t.flags,"
            " t.creationDate,"
            " t.modificationDate - t.creationDate,"
            " (CASE WHEN t.refreshDate = 0 THEN 0 ELSE t.refreshDate - t.creationDate END)"
            " FROM twincodeOutbound AS t"
            " LEFT JOIN repository AS r1 ON t.id = r1.twincodeOutbound"
            " LEFT JOIN repository AS r2 ON t.id = r2.peerTwincodeOutbound"
            " LEFT JOIN conversation AS c ON t.id = c.peerTwincodeOutbound"
            " LEFT JOIN descriptor AS d ON t.id = d.twincodeOutbound"
            " WHERE r1.id IS NULL AND r2.id IS NULL AND c.id IS NULL AND d.id IS NULL"];
}

#define CHECK_TWINCODES_MISSING_IMAGE @"Missing image for twincodes (IMG not found):"

+ (nullable TLDatabaseCheck *)checkMissingImagesTwincodesWithDatabase:(nonnull FMDatabase *)database secure:(BOOL)secure {
    DDLogVerbose(@"%@ checkMissingImagesTwincodesWithDatabase: %@ secure: %d", LOG_TAG, database, secure);

    return [self dumpTwincodesWithDatabase:database secure:secure name:CHECK_TWINCODES_MISSING_IMAGE sql:@"SELECT"
            " t.id, t.twincodeId, t.avatarId, t.flags,"
            " t.creationDate,"
            " t.modificationDate - t.creationDate,"
            " (CASE WHEN t.refreshDate = 0 THEN 0 ELSE t.refreshDate - t.creationDate END)"
            " FROM twincodeOutbound AS t"
            " LEFT JOIN image AS img ON t.avatarId = img.id"
            " WHERE t.avatarId IS NOT NULL AND t.avatarId > 0 AND img.id IS NULL"];
}

#define CHECK_TWINCODES_IN @"TIN:"

+ (nullable TLDatabaseCheck *)dumpTwincodesInWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ dumpTwincodesWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " tin.id, tin.twincodeOutbound, tin.twincodeId, tin.factoryId,"
                     " tout.creationDate, tin.modificationDate"
                     " FROM twincodeInbound AS tin"
                     " LEFT JOIN twincodeOutbound AS tout ON tin.twincodeOutbound = tout.id"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:CHECK_TWINCODES_IN];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"|  TIN |  TID |  UUID  |  FACT  |    CREATE DATE |        MODIF  |\n"];
            }
            long tid = [resultSet longForColumnIndex:0];
            long twincodeId = [resultSet longForColumnIndex:1];
            NSString *twincodeInId = [resultSet stringForColumnIndex:2];
            NSString *factoryId = [resultSet stringForColumnIndex:3];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:4];
            int64_t modificationDate = [resultSet longLongIntForColumnIndex:5];
            int64_t modifDelta = creationDate > 0 && modificationDate >= creationDate ? modificationDate - creationDate : modificationDate;

            [content appendFormat:@"| %4ld | %4ld | %@ | %@ | %@ | %13lld |\n", tid, twincodeId, [TLDatabaseCheck toDisplay:twincodeInId], [TLDatabaseCheck toDisplay:factoryId], [TLDatabaseCheck toTimeDisplay:creationDate], modifDelta];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:CHECK_TWINCODES_IN] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:CHECK_TWINCODES_IN];
    }
}

#define DUMP_TWINCODE_KEYS @"KID:"

// List keys and secrets without leaking sensitive information.
+ (nullable TLDatabaseCheck *)dumpTwincodeKeysWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ dumpTwincodeKeysWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " k.id, s.peerTwincodeId, k.creationDate, k.modificationDate - k.creationDate,"
                     " s.creationDate - k.creationDate, s.modificationDate - s.creationDate,"
                     " s.secretUpdateDate - s.creationDate,"
                     " k.flags, k.nonceSequence,"
                     " s.flags, s.nonceSequence,"
                     " LENGTH(k.signingKey), LENGTH(k.encryptionKey),"
                     " LENGTH(s.secret1), LENGTH(s.secret2)"
                   " FROM twincodeKeys AS k"
                   " LEFT JOIN secretKeys  AS  s ON k.id = s.id"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:DUMP_TWINCODE_KEYS];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"|   KID   | KEYS |  KFLG |  SFLG |    CREATE DATE |      MODIF |   SEC DATE |    SEC MOD |    SEC UPD |  K-Nonce |  S-Nonce |\n"];
            }
            long kid = [resultSet longForColumnIndex:0];
            long peerTwincode = [resultSet longForColumnIndex:1];
            int64_t creationDate = [resultSet longLongIntForColumnIndex:2];
            int64_t modifDelta = [resultSet longLongIntForColumnIndex:3];
            int64_t secretCreateDelta = [resultSet longLongIntForColumnIndex:4];
            int64_t secretModifDelta = [resultSet longLongIntForColumnIndex:5];
            int64_t secretUpdateDelta = [resultSet longLongIntForColumnIndex:6];
            int kFlags = [resultSet intForColumnIndex:7];
            long kNonce = [resultSet longForColumnIndex:8];
            int sFlags = [resultSet intForColumnIndex:9];
            long sNonce = [resultSet longForColumnIndex:10];
            NSMutableString *info = [[NSMutableString alloc] initWithCapacity:10];
            int l1 = [resultSet intForColumnIndex:11];
            if (l1 == 32) {
                [info appendString:@"S"];
            } else if (l1 > 0) {
                [info appendString:@"s"];
            } else {
                [info appendString:@" "];
            }
            int l2 = [resultSet intForColumnIndex:12];
            if (l2 == 32) {
                [info appendString:@"E"];
            } else if (l2 > 0) {
                [info appendString:@"e"];
            } else {
                [info appendString:@" "];
            }
            int l3 = [resultSet intForColumnIndex:13];
            if (l3 == 32) {
                [info appendString:@"1"];
            } else if (l3 > 0) {
                [info appendString:@"3"];
            } else {
                [info appendString:@" "];
            }
            int l4 = [resultSet intForColumnIndex:14];
            if (l4 == 32) {
                [info appendString:@"2"];
            } else if (l4 > 0) {
                [info appendString:@"4"];
            } else {
                [info appendString:@" "];
            }

            [content appendFormat:@"| %3ld.%-3ld | %@ | %05x | %05x | %@ | %10lld | %10lld | %10lld | %10lld | %8ld | %8ld |\n", kid, peerTwincode, info, kFlags, sFlags, [TLDatabaseCheck toTimeDisplay:creationDate], modifDelta, secretCreateDelta, secretModifDelta, secretUpdateDelta, kNonce, sNonce];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:DUMP_TWINCODE_KEYS] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:DUMP_TWINCODE_KEYS];
    }
}

#define DUMP_SECURE_CONVERSATIONS @"CID:"

// List secure conversation.
+ (nullable TLDatabaseCheck *)dumpSecureConversationsWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ dumpSecureConversationsWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;

        resultSet = [database executeQuery:@"SELECT"
                     " c.id, c.groupId, c.subject, r.twincodeOutbound, r.peerTwincodeOutbound, c.peerTwincodeOutbound,"
                     " t1.id, t2.id,"
                     " (SELECT COUNT(d.id) FROM descriptor AS d WHERE d.cid = c.id),"
                     " (SELECT COUNT(op.id) FROM operation AS op WHERE op.cid = c.id)"
                   " FROM conversation  AS  c"
                   " LEFT JOIN repository  AS  r  ON c.subject = r.id"
                   " LEFT JOIN twincodeKeys AS t1 ON t1.id = r.twincodeOutbound"
                   " LEFT JOIN twincodeKeys AS t2 ON t2.id = c.peerTwincodeOutbound"];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:DUMP_SECURE_CONVERSATIONS];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"|  CID |  GRP | SUB | TID | PID | PEER |   KID   | DCNT | OCNT |\n"];
            }
            long cid = [resultSet longForColumnIndex:0];
            long gid = [resultSet longForColumnIndex:1];
            long subjectId = [resultSet longForColumnIndex:2];
            long twincodeId = [resultSet longForColumnIndex:3];
            long peerTwincodeId = [resultSet longForColumnIndex:4];
            long convTwincodeId = [resultSet longForColumnIndex:5];
            int k1 = [resultSet intForColumnIndex:6];
            int k2 = [resultSet intForColumnIndex:7];
            int descriptorCount = [resultSet intForColumnIndex:8];
            int opCount = [resultSet intForColumnIndex:9];

            [content appendFormat:@"| %4ld | %4ld | %3ld | %3ld | %3ld | %4ld | %3d.%-3d | %4d | %4d |\n", cid, gid, subjectId, twincodeId, peerTwincodeId, convTwincodeId, k1, k2, descriptorCount, opCount];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:DUMP_SECURE_CONVERSATIONS] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:DUMP_SECURE_CONVERSATIONS];
    }
}

#define DUMP_CONVERSATION_SPEED @"Metrics:"
#define REPORT_SPEED_TIMEFRAME  (7L*86400L*1000L)

// List performance of conversation.
+ (nullable TLDatabaseCheck *)dumpConversationSpeedWithDatabase:(nonnull FMDatabase *)database {
    DDLogVerbose(@"%@ dumpConversationSpeedWithDatabase: %@", LOG_TAG, database);

    @try {
        FMResultSet *resultSet;
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;

        resultSet = [database executeQuery:@"SELECT"
                " d.cid, d.twincodeOutbound,"
                " SUM(CASE WHEN d.receiveDate - d.creationDate < 20000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.receiveDate - d.creationDate < 70000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.receiveDate - d.creationDate < 310000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.receiveDate - d.creationDate > 310000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.receiveDate - d.creationDate > 310000 THEN d.receiveDate - d.creationDate ELSE 0 END),"
                " SUM(CASE WHEN d.sendDate - d.creationDate < 20000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.sendDate - d.creationDate < 70000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.sendDate - d.creationDate < 310000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.sendDate - d.creationDate > 310000 THEN 1 ELSE 0 END),"
                " SUM(CASE WHEN d.sendDate - d.creationDate > 310000 THEN d.sendDate - d.creationDate ELSE 0 END)"
                " FROM descriptor AS d"
                " INNER JOIN conversation AS c on d.cid = c.id"
                " WHERE d.creationDate > ?"
                     " GROUP BY d.cid, d.twincodeOutbound", [NSNumber numberWithLongLong:now - REPORT_SPEED_TIMEFRAME]];
        if (!resultSet) {
            return [[TLDatabaseCheck alloc] initWithMessage:@"SQL query failed" name:DUMP_CONVERSATION_SPEED];
        }

        NSMutableString *content = nil;
        while ([resultSet next]) {
            if (!content) {
                content = [[NSMutableString alloc] initWithCapacity:1024];
                [content appendFormat:@"|  CID |  TID |  REC-1 |  REC-2 |  REC-3 |  REC-4 | REC-TIME |  SND-1 |  SND-2 |  SND-3 |  SND-4 | SND-TIME |\n"];
            }
            long cid = [resultSet longForColumnIndex:0];
            long twincodeId = [resultSet longForColumnIndex:1];
            long recvFastCount = [resultSet longForColumnIndex:2];
            long recv2RetryCount = [resultSet longForColumnIndex:3];
            long recv3RetryCount = [resultSet longForColumnIndex:4];
            long recvCount = [resultSet longForColumnIndex:5];
            long recvTime = [resultSet longForColumnIndex:6] / 1000L;
            long sendFastCount = [resultSet longForColumnIndex:7];
            long send2RetryCount = [resultSet longForColumnIndex:8];
            long send3RetryCount = [resultSet longForColumnIndex:9];
            long sendCount = [resultSet longForColumnIndex:10];
            long sendTime = [resultSet longForColumnIndex:11] / 1000L;

            [content appendFormat:@"| %4ld | %4ld | %6ld | %6ld | %6ld | %6ld | %8ld | %6ld | %6ld | %6ld | %6ld | %8ld |\n", cid, twincodeId, recvFastCount, recv2RetryCount - recvFastCount, recv3RetryCount - recv2RetryCount, recvCount, recvTime, sendFastCount, send2RetryCount - sendFastCount, send3RetryCount - send2RetryCount, sendCount, sendTime];
        }
        [resultSet close];
        return content ? [[TLDatabaseCheck alloc] initWithMessage:content name:DUMP_CONVERSATION_SPEED] : nil;

    } @catch (NSException *exception) {
        
        return [[TLDatabaseCheck alloc] initWithException:exception name:DUMP_CONVERSATION_SPEED];
    }
}

+ (nonnull NSMutableString *)checkConsistencyWithDatabase:(nonnull FMDatabase *)database {

    NSMutableString *content = [[NSMutableString alloc] initWithCapacity:1024];
    NSMutableArray<TLDatabaseCheck *> *checks = [[NSMutableArray alloc] init];
    TLDatabaseCheck *check;

    check = [TLDatabaseCheck checkMissingIdentityTwincodeWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck checkMissingPeerTwincodeRepositoryWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck checkMissingPeerTwincodeConversationWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck checkMissingImagesTwincodesWithDatabase:database secure:NO];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck checkConversationRepositoryWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck checkOrphanedGroupMemberConversationWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck dumpRepositoryWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck dumpTwincodesInWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck dumpTwincodesWithDatabase:database secure:NO];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck dumpOrphanedTwincodesWithDatabase:database secure:NO];
    if (check) {
        [checks addObject:check];
    }

    check = [TLDatabaseCheck dumpTwincodeKeysWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }
    check = [TLDatabaseCheck dumpSecureConversationsWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }
    check = [TLDatabaseCheck dumpConversationSpeedWithDatabase:database];
    if (check) {
        [checks addObject:check];
    }

    for (TLDatabaseCheck *check in checks) {
        [content appendString:check.name];
        [content appendString:@"\n"];
        [content appendString:check.message];
        [content appendString:@"\n"];
    }
    return content;
}

@end

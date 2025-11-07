/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import "TLNotificationServiceProvider.h"
#import "TLConversationService.h"
#import "TLRepositoryService.h"
#import "TLTwincodeOutboundService.h"

#import "TLTwinlifeImpl.h"
#import "TLNotificationServiceImpl.h"
#import "TLConversationServiceProvider.h"
#import "TLFilter.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define NOTIFICATION_SERVICE_PROVIDER_SCHEMA_ID @"1840c20d-b017-48a7-ac20-7c5a16211883"

/**
 * notification table:
 * id INTEGER: local database identifier (primary key)
 * notificationId INTEGER: the system notification id
 * uuid TEXT NOT NULL: the notification UUID
 * subject INTEGER: the repository object key
 * creationDate INTEGER: the notification creation date
 * descriptor INTEGER: the optional descriptor key associated with the notification
 * type INTEGER NOT NULL: the notification type
 * flags INTEGER NOT NULL: notification flags and status
 *
 * Note:
 * - id, notificationId, uuid, creationDate, subject, descriptor, type are readonly.
 */
#define NOTIFICATION_TABLE \
        @"CREATE TABLE IF NOT EXISTS notification (id INTEGER PRIMARY KEY," \
                " notificationId INTEGER, uuid TEXT NOT NULL," \
                " subject INTEGER, creationDate INTEGER NOT NULL, descriptor INTEGER," \
                " type INTEGER NOT NULL, flags INTEGER NOT NULL" \
                ")"

#define NOTIFICATION_CREATE_INDEX_1 \
        @"CREATE INDEX IF NOT EXISTS idx_subject_notification ON notification (subject)"

#define NOTIFICATION_CREATE_INDEX_2 \
        @"CREATE INDEX IF NOT EXISTS idx_creationDate_notification ON notification (creationDate)"

/**
 * Table from V7 to V19:
 * "CREATE TABLE IF NOT EXISTS notificationNotification (uuid TEXT PRIMARY KEY NOT NULL, " +
 *                     "originatorId TEXT, timestamp INTEGER, acknowledged INTEGER, content BLOB);";
 */

//
// Interface: TLNotificationServiceProvider ()
//

@interface TLNotificationServiceProvider ()

@property (readonly, nonnull) TLNotificationService *notificationService;

+ (TLNotificationType)toNotificationType:(int)type;

+ (int)fromNotificationType:(TLNotificationType)type;

@end

//
// Implementation: TLNotificationServiceProvider
//

#undef LOG_TAG
#define LOG_TAG @"TLNotificationServiceProvider"

@implementation TLNotificationServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLNotificationService *)service database:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@: initWithService: %@", LOG_TAG, service);

    self = [super initWithService:service database:database sqlCreate:NOTIFICATION_TABLE table:TLDatabaseTableNotification];
    if (self) {
        _notificationService = service;
    }
    return self;
}

- (void)onCreateWithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ onCreateWithTransaction: %@", LOG_TAG, transaction);

    [super onCreateWithTransaction:transaction];
    [transaction createSchemaWithSQL:NOTIFICATION_CREATE_INDEX_1];
    [transaction createSchemaWithSQL:NOTIFICATION_CREATE_INDEX_2];
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);

    // Note: migration for V20 is done by the TLMigrationConversation.
    [self onCreateWithTransaction:transaction];
}

#pragma mark - TLDatabaseObjectFactory

- (nullable id<TLDatabaseObject>)createObjectWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ createObjectWithIdentifier: %@ offset: %d", LOG_TAG, identifier, offset);

    // n.id, n.notificationId, n.uuid, n.creationDate, n.type, n.flags, n.subject, r.schemaId,
    // n.descriptor, d.sequenceId, d.twincodeOutbound
    // int sysId = [cursor intForColumnIndex:offset];
    NSUUID *notificationId = [cursor uuidForColumnIndex:offset + 1];
    int64_t creationDate = [cursor longLongIntForColumnIndex:offset + 2];
    TLNotificationType type = [TLNotificationServiceProvider toNotificationType:[cursor intForColumnIndex:offset + 3]];
    if (type == TLNotificationTypeUnknown) {
        return nil;
    }
    int flags = [cursor intForColumnIndex:offset + 4];
    long subjectId = [cursor longForColumnIndex:offset + 5];
    NSUUID* schemaId = [cursor uuidForColumnIndex:offset + 6];
    long descriptor = [cursor longForColumnIndex:offset + 7];
    long sequenceId = [cursor longForColumnIndex:offset + 8];
    long twincodeOutboundId = [cursor longLongIntForColumnIndex:offset + 9];
    long userTwincodeId = [cursor longLongIntForColumnIndex:offset + 10];
    TLDescriptorAnnotationType annotationType = [TLConversationServiceProvider toDescriptorAnnotationType:[cursor intForColumnIndex:offset + 11]];
    int annotationValue = [cursor intForColumnIndex:offset + 12];
    id<TLRepositoryObject> subject = [self.database loadRepositoryObjectWithId:subjectId schemaId:schemaId];
    if (!subject) {
        // No object: this notification is now obsolete and must be removed.
        return nil;
    }

    TLDescriptorId *descriptorId;
    if (descriptor > 0) {
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithId:twincodeOutboundId];
        if (!twincodeOutbound) {
            // No peer twincode: the contact or group member is revoked, the notification is obsolete and must be removed.
            return nil;
        }
        descriptorId = [[TLDescriptorId alloc] initWithId:descriptor twincodeOutboundId:twincodeOutbound.uuid sequenceId:sequenceId];
    } else {
        descriptorId = nil;
    }
    TLTwincodeOutbound *userTwincode;
    if (userTwincodeId > 0) {
        userTwincode = [self.database loadTwincodeOutboundWithId:userTwincodeId];
    } else {
        userTwincode = nil;
    }
    // The annotation associated with this notification is no longer valid, we must drop that notification.
    if (type == TLNotificationTypeUpdatedAnnotation && !userTwincode) {
        return nil;
    }
    return [[TLNotification alloc] initWithIdentifier:identifier notificationType:type uuid:notificationId subject:subject creationDate:creationDate descriptorId:descriptorId flags:flags userTwincode:userTwincode annotationType:annotationType annotationValue:annotationValue];
}

- (BOOL)loadWithObject:(nonnull id<TLDatabaseObject>)object cursor:(nonnull FMResultSet *)cursor offset:(int)offset {
    DDLogVerbose(@"%@ loadWithObject: %@ offset: %d", LOG_TAG, object, offset);

    // Not used.
    return NO;
}

- (nullable id<TLDatabaseObject>)storeObjectWithTransaction:(nonnull TLTransaction *)transaction identifier:(nonnull TLDatabaseIdentifier *)identifier twincodeId:(nonnull NSUUID *)twincodeId attributes:()attributes flags:(int)flags modificationDate:(int64_t)modificationDate refreshPeriod:(int64_t)refreshPeriod refreshDate:(int64_t)refreshDate refreshTimestamp:(int64_t)refreshTimestamp {
    DDLogVerbose(@"%@ storeObjectWithDatabase: %@ twincodeId: %@", LOG_TAG, identifier, twincodeId);

    // Not used
    return nil;
}

- (BOOL)isLocal {
    
    return YES;
}

- (nonnull NSUUID *)schemaId {

    return [[NSUUID alloc] initWithUUIDString:NOTIFICATION_SERVICE_PROVIDER_SCHEMA_ID];
}

- (int)schemaVersion {

    return 0;
}

#pragma mark - TLNotificationsCleaner

- (void)deleteNotificationsWithTransaction:(nonnull TLTransaction *)transaction subjectId:(nullable NSNumber *)subjectId twincodeId:(nullable NSNumber *)twincodeId descriptorId:(nullable NSNumber *)descriptorId {
    DDLogVerbose(@"%@ deleteNotificationsWithTransaction: %@ subjectId: %@ twincodeId: %@ descriptorId: %@", LOG_TAG, transaction, subjectId, twincodeId, descriptorId);

    NSMutableArray<NSUUID *> *deletedNotifications;
    if (subjectId && descriptorId) {
        deletedNotifications = [transaction listUUIDWithSQL:@"SELECT uuid"
                                " FROM notification WHERE subject=? AND flags=0 AND descriptor=?", subjectId, descriptorId];

        [transaction executeUpdate:@"DELETE FROM notification WHERE subject=? AND descriptor=?", subjectId, descriptorId];

    } else if (subjectId && twincodeId) {
        deletedNotifications = [transaction listUUIDWithSQL:@"SELECT uuid FROM notification AS n"
                                " INNER JOIN descriptor AS d ON n.descriptor=d.id"
                                " WHERE n.subject=? AND n.flags=0 AND d.twincodeOutbound=?", subjectId, twincodeId];

        [transaction executeUpdate:@"DELETE FROM notification WHERE id IN (SELECT n.id FROM notification AS n"
                                " INNER JOIN descriptor AS d ON n.descriptor=d.id"
                                " WHERE n.subject=? AND d.twincodeOutbound=?)", subjectId, twincodeId];
    } else {
        deletedNotifications = [transaction listUUIDWithSQL:@"SELECT uuid"
                                " FROM notification WHERE subject=? AND flags=0", subjectId];

        [transaction executeUpdate:@"DELETE FROM notification WHERE subject=?", subjectId];
    }

    if (deletedNotifications.count > 0) {
        [self.notificationService notifyCanceledWithList:deletedNotifications];
    }
}

#pragma mark - TLNotificationServiceProvider

- (nullable TLNotification *)loadNotification:(nonnull NSUUID *)notificationId {
    DDLogVerbose(@"%@ loadNotification: %@", LOG_TAG, notificationId);

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"n.id, n.notificationId, n.uuid, n.creationDate,"
                    " n.type, n.flags, n.subject, r.schemaId, n.descriptor, d.sequenceId, d.twincodeOutbound,"
                    " a.peerTwincodeOutbound, a.kind, a.value"
                    " FROM notification AS n INNER JOIN repository AS r ON n.subject=r.id"
                    " LEFT JOIN descriptor AS d ON n.descriptor=d.id"
                    " LEFT JOIN annotation AS a ON n.type=17 AND a.descriptor=d.id AND a.notificationId=n.id AND a.kind=4"];
    [query filterUUID:notificationId field:@"n.uuid"];

    __block TLNotification *notification = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (database) {
            FMResultSet *resultSet = [database executeQuery:query.sql withArgumentsInArray:query.sqlParams];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
                return;
            }
            if ([resultSet next]) {
                TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:[resultSet longForColumnIndex:0] factory:self];
                notification = (TLNotification *)[self createObjectWithIdentifier:identifier cursor:resultSet offset:1];
            }
            [resultSet close];
        }
    }];
    return notification;
}

- (nonnull NSMutableArray<TLNotification *> *)listNotificationsWithFilter:(nonnull TLFilter *)filter maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ listNotificationsWithFilter: %@ maxDescriptors: %d", LOG_TAG, filter, maxDescriptors);

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"n.id, n.notificationId, n.uuid, n.creationDate,"
                    " n.type, n.flags, n.subject, r.schemaId, n.descriptor, d.sequenceId, d.twincodeOutbound,"
                    " a.peerTwincodeOutbound, a.kind, a.value"
                    " FROM notification AS n INNER JOIN repository AS r ON n.subject=r.id"
                    " LEFT JOIN descriptor AS d ON n.descriptor=d.id"
                    " LEFT JOIN annotation AS a ON n.type=17 AND a.descriptor=d.id AND a.notificationId=n.id AND a.kind=4"];
    [query filterBefore:filter.before field:@"n.creationDate"];
    [query filterOwner:filter.owner field:@"r.owner"];
    [query filterName:filter.name field:@"r.name"];
    [query order:@"n.creationDate DESC"];
    [query limit:maxDescriptors];
    return [self listNotificationsWithQuery:query filter:filter];
}

- (nonnull NSMutableArray<TLNotification *> *)loadPendingNotifications:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ loadPendingNotifications: %@", LOG_TAG, subject);

    TLQueryBuilder *query = [[TLQueryBuilder alloc] initWithSQL:@"n.id, n.notificationId, n.uuid, n.creationDate,"
                    " n.type, n.flags, n.subject, r.schemaId, n.descriptor, d.sequenceId, d.twincodeOutbound,"
                    " a.peerTwincodeOutbound, a.kind, a.value"
                    " FROM notification AS n INNER JOIN repository AS r ON n.subject=r.id"
                    " LEFT JOIN descriptor AS d ON n.descriptor=d.id"
                    " LEFT JOIN annotation AS a ON n.type=17 AND a.descriptor=d.id AND a.notificationId=n.id AND a.kind=4"];
    [query filterOwner:subject field:@"n.subject"];
    [query filterLong:0 field:@"n.flags"];
    [query order:@"n.creationDate DESC"];
    return [self listNotificationsWithQuery:query filter:nil];
}

- (nonnull NSMutableArray<TLNotification *> *)listNotificationsWithQuery:(nonnull TLQueryBuilder *)query filter:(nullable TLFilter *)filter {
    DDLogVerbose(@"%@ listNotificationsWithQuery: %@ filter: %@", LOG_TAG, query, filter);
    
    __block NSMutableArray<NSNumber *> *toBeDeletedNotifications = nil;
    __block NSMutableArray<TLNotification *> *notifications = [[NSMutableArray alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        if (database) {
            FMResultSet *resultSet = [database executeQuery:query.sql withArgumentsInArray:query.sqlParams];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
                return;
            }
            while ([resultSet next]) {
                TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:[resultSet longForColumnIndex:0] factory:self];
                id<TLDatabaseObject> notification = [self createObjectWithIdentifier:identifier cursor:resultSet offset:1];
                if (notification) {
                    if (!filter || !filter.acceptWithObject || filter.acceptWithObject(notification)) {
                        [notifications addObject:(TLNotification *)notification];
                    }
                } else {
                    if (!toBeDeletedNotifications) {
                        toBeDeletedNotifications = [[NSMutableArray alloc] init];
                    }
                    [toBeDeletedNotifications addObject:[identifier identifierNumber]];
                }
            }
            [resultSet close];
        }
    }];

    // There are some obsolete notifications: delete them.
    if (toBeDeletedNotifications) {
        [self inTransaction:^(TLTransaction *transaction) {
            [transaction deleteWithList:toBeDeletedNotifications table:TLDatabaseTableNotification];
            [transaction commit];
        }];
    }
    return notifications;
}

- (nonnull NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *)getNotificationStats {
    DDLogVerbose(@"%@ getNotificationStats", LOG_TAG);
    
    __block NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *result = [[NSMutableDictionary alloc] init];
    [self inDatabase:^(FMDatabase *database) {
        if (database) {
            FMResultSet *resultSet = [database executeQuery:@"SELECT owner.uuid, SUM(CASE WHEN n.flags = 1 THEN 1 ELSE 0 END),"
                                      " SUM(case WHEN n.flags != 1 THEN 1 ELSE 0 END) FROM notification AS n"
                                      " INNER JOIN repository AS r ON n.subject=r.id"
                                      " LEFT JOIN repository AS owner ON r.owner=owner.id"
                                      " GROUP BY owner.uuid"];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
                return;
            }
            while ([resultSet next]) {
                NSUUID *uuid = [resultSet uuidForColumnIndex:0];
                long ackCount = [resultSet longForColumnIndex:1];
                long pendingCount = [resultSet longForColumnIndex:2];
                
                if (uuid) {
                    [result setObject:[[TLNotificationServiceNotificationStat alloc] initWithPendingCount:pendingCount acknowledgedCount:ackCount] forKey:uuid];
                }
            }
            [resultSet close];
        }
    }];

    return result;
}

- (nullable TLNotification *)createNotificationWithType:(TLNotificationType)type notificationId:(nonnull NSUUID *)notificationId subject:(nonnull id<TLRepositoryObject>)subject descriptorId:(nullable TLDescriptorId *)descriptorId annotatingUser:(nullable TLTwincodeOutbound *)annotatingUser {
    DDLogVerbose(@"%@ createNotificationWithType: %d notificationId: %@ subject: %@ descriptorId: %@ annotatingUser: %@", LOG_TAG, type, notificationId, subject, descriptorId, annotatingUser);

    __block TLNotification *result = nil;
    [self inTransaction:^(TLTransaction *transaction) {
        int annotationValue = 0;
        TLDescriptorAnnotationType annotationType = TLDescriptorAnnotationTypeInvalid;
        if (annotatingUser && descriptorId) {
            annotationValue = (int) [transaction longForQuery:@"SELECT value FROM annotation WHERE descriptor=? AND peerTwincodeOutbound=? AND kind=4", [NSNumber numberWithLong:descriptorId.id], [annotatingUser.identifier identifierNumber]];
            annotationType = TLDescriptorAnnotationTypeLike;
        }
        long ident = [transaction allocateIdWithTable:TLDatabaseTableNotification];
        TLDatabaseIdentifier *identifier = [[TLDatabaseIdentifier alloc] initWithIdentifier:ident factory:self];
        int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;

        NSObject *uuid = [TLDatabaseService toObjectWithUUID:notificationId];
        NSObject *subjectId = [TLDatabaseService toObjectWithObject:subject];
        [transaction executeUpdate:@"INSERT INTO notification (id, uuid, subject,"
            " creationDate, descriptor, type, flags)"
            " VALUES(?, ?, ?, ?, ?, ?, ?)", [identifier identifierNumber], uuid, subjectId, [NSNumber numberWithLongLong:now], [NSNumber numberWithLong:descriptorId.id], [NSNumber numberWithInt:[TLNotificationServiceProvider fromNotificationType:type]], [NSNumber numberWithInt:0]];

        // Associate the LIKE annotation with the notification so that we can retrieve it.
        if (annotatingUser && descriptorId) {
            [transaction executeUpdate:@"UPDATE annotation SET notificationId=? WHERE descriptor=? AND peerTwincodeOutbound=? AND kind=4", [identifier identifierNumber], [NSNumber numberWithLong:descriptorId.id], [annotatingUser.identifier identifierNumber]];
        }
        [transaction commit];
        result = [[TLNotification alloc] initWithIdentifier:identifier notificationType:type uuid:notificationId subject:subject creationDate:now descriptorId:descriptorId flags:0 userTwincode:annotatingUser annotationType:annotationType annotationValue:annotationValue];
    }];
    return result;
}

- (void)acknowledgeWithNotification:(nonnull TLNotification *)notification {
    DDLogVerbose(@"%@ acknowledgeWithNotification: %@", LOG_TAG, notification);

    [self inTransaction:^(TLTransaction *transaction) {
        notification.flags = 1;
        TLDatabaseIdentifier *identifier = [notification identifier];

        [transaction executeUpdate:@"UPDATE notification SET flags=? WHERE id=?", [NSNumber numberWithInt:notification.flags], [identifier identifierNumber]];
        [transaction commit];
    }];
}

- (void)deleteWithSubject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ deleteWithSubject: %@", LOG_TAG, subject);

    [self inTransaction:^(TLTransaction *transaction) {
        [self deleteNotificationsWithTransaction:transaction subjectId:[subject.identifier identifierNumber] twincodeId:nil descriptorId:nil];
        [transaction commit];
    }];
}

+ (TLNotificationType)toNotificationType:(int)type {
    switch (type) {
        case 0:
            return TLNotificationTypeNewContact;
        case 1:
            return TLNotificationTypeUpdatedContact;
        case 2:
            return TLNotificationTypeDeletedContact;
        case 3:
            return TLNotificationTypeMissedAudioCall;
        case 4:
            return TLNotificationTypeMissedVideoCall;
        case 5:
            return TLNotificationTypeResetConversation;
        case 6:
            return TLNotificationTypeNewTextMessage;
        case 7:
            return TLNotificationTypeNewImageMessage;
        case 8:
            return TLNotificationTypeNewAudioMessage;
        case 9:
            return TLNotificationTypeNewVideoMessage;
        case 10:
            return TLNotificationTypeNewFileMessage;
        case 11:
            return TLNotificationTypeNewGroupInvitation;
        case 12:
            return TLNotificationTypeNewGroupJoined;
        case 13:
            return TLNotificationTypeDeletedGroup;
        case 14:
            return TLNotificationTypeUpdatedAvatarContact;
        case 15:
            return TLNotificationTypeNewGeolocation;
        case 16:
            return TLNotificationTypeNewContactInvitation;
        case 17:
            return TLNotificationTypeUpdatedAnnotation;
        default:
            return TLNotificationTypeUnknown;
    }
}

+ (int)fromNotificationType:(TLNotificationType)type {
    switch (type) {
        case TLNotificationTypeNewContact:
            return 0;
        case TLNotificationTypeUpdatedContact:
            return 1;
        case TLNotificationTypeDeletedContact:
            return 2;
        case TLNotificationTypeMissedAudioCall:
            return 3;
        case TLNotificationTypeMissedVideoCall:
            return 4;
        case TLNotificationTypeResetConversation:
            return 5;
        case TLNotificationTypeNewTextMessage:
            return 6;
        case TLNotificationTypeNewImageMessage:
            return 7;
        case TLNotificationTypeNewAudioMessage:
            return 8;
        case TLNotificationTypeNewVideoMessage:
            return 9;
        case TLNotificationTypeNewFileMessage:
            return 10;
        case TLNotificationTypeNewGroupInvitation:
            return 11;
        case TLNotificationTypeNewGroupJoined:
            return 12;
        case TLNotificationTypeDeletedGroup:
            return 13;
        case TLNotificationTypeUpdatedAvatarContact:
            return 14;
        case TLNotificationTypeNewGeolocation:
            return 15;
        case TLNotificationTypeNewContactInvitation:
            return 16;
        case TLNotificationTypeUpdatedAnnotation:
            return 17;
        default:
            return -1;
    }
}

@end

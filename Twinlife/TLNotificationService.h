/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"
#import "TLDatabase.h"
#import "TLConversationService.h"

@protocol TLRepositoryObject;
@class TLDescriptorId;
@class TLFilter;

//
// Interface: TLNotificationServiceNotification
//

typedef enum {
    TLNotificationTypeUnknown,
    TLNotificationTypeNewContact,
    TLNotificationTypeUpdatedContact,
    TLNotificationTypeUpdatedAvatarContact,
    TLNotificationTypeDeletedContact,
    TLNotificationTypeMissedAudioCall,
    TLNotificationTypeMissedVideoCall,
    TLNotificationTypeResetConversation,
    TLNotificationTypeNewTextMessage,
    TLNotificationTypeNewImageMessage,
    TLNotificationTypeNewAudioMessage,
    TLNotificationTypeNewVideoMessage,
    TLNotificationTypeNewFileMessage,
    TLNotificationTypeNewGeolocation,
    TLNotificationTypeNewGroupInvitation,
    TLNotificationTypeNewGroupJoined,
    TLNotificationTypeNewContactInvitation,
    TLNotificationTypeDeletedGroup,
    TLNotificationTypeUpdatedAnnotation
} TLNotificationType;

//
// Interface: TLNotificationServiceNotification
//

@interface TLNotification : NSObject <TLDatabaseObject>

@property (nonatomic, readonly, nonnull) NSUUID *uuid;
@property (nonatomic, readonly) TLNotificationType notificationType;
@property (nonatomic, readonly, nonnull) id<TLRepositoryObject> subject;
@property (nonatomic, readonly) int64_t timestamp;
@property (nonatomic, readonly, nullable) TLDescriptorId *descriptorId;
@property (nonatomic, readonly, nullable) TLTwincodeOutbound *user;
@property (nonatomic, readonly) int annotationValue;
@property (nonatomic, readonly) TLDescriptorAnnotationType annotationType;

- (BOOL)acknowledged;

@end

//
// Interface: TLNotificationServiceDelegate
//

@protocol TLNotificationServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onCanceledNotificationsWithList:(nonnull NSArray<NSUUID *> *)list;

@end

//
// Interface: TLNotificationServiceNotificationStat
//

@interface TLNotificationServiceNotificationStat : NSObject

@property long pendingCount;
@property long acknowledgedCount;

- (nonnull instancetype)initWithPendingCount:(long)pendingCount acknowledgedCount:(long)acknowledgedCount;

@end

//
// Interface: TLNotificationServiceConfiguration
//

@interface TLNotificationServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Interface: TLNotificationService
//

@interface TLNotificationService : TLBaseService

+ (nonnull NSString *)VERSION;

/// Get the notification with the given notification id.
- (nullable TLNotification *)getNotificationWithNotificationId:(nonnull NSUUID *)notificationId;

/// Get for each originator the statistics about their notification.  It is intended to know if a given originator has some pending notifications.
- (nonnull NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *)getNotificationStats;

/// Get the notifications filtered by the given selection.  The list is sorted on the creation date (newest first).
- (nonnull NSMutableArray<TLNotification *> *)listNotificationsWithFilter:(nonnull TLFilter *)filter maxDescriptors:(int)maxDescriptors;

/// Get the active notifications associated with the given subject.
- (nonnull NSMutableArray<TLNotification *> *)getPendingNotificationsWithSubject:(nonnull id<TLRepositoryObject>)subject;

/// Create a new notification with the given type for the subject.  If the notificationId is null, a unique id is allocated.
- (nullable TLNotification *)createNotificationWithType:(TLNotificationType)type notificationId:(nullable NSUUID *)notificationId subject:(nonnull id<TLRepositoryObject>)subject descriptorId:(nullable TLDescriptorId *)descriptorId annotatingUser:(nullable TLTwincodeOutbound *)annotatingUser;

/// Acknowledge the notification.
- (void)acknowledgeWithNotification:(nonnull TLNotification *)notification;

/// Delete the notification.
- (void)deleteWithNotification:(nonnull TLNotification *)notification;

/// Delete all the notifications associated with the given subject.
- (void)deleteWithSubject:(nonnull id<TLRepositoryObject>)subject;

@end

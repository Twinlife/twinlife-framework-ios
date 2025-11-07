/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLDatabaseServiceProvider.h"
#import "TLNotificationService.h"

//
// Interface: TLNotificationServiceProvider
//

@class TLFilter;
@class TLNotification;
@class TLNotificationServiceNotificationStat;
@class TLNotificationService;

@protocol TLNotificationServiceNotification;

@interface TLNotificationServiceProvider : TLDatabaseServiceProvider <TLDatabaseObjectFactory, TLNotificationsCleaner>

- (nonnull instancetype)initWithService:(nonnull TLNotificationService *)service database:(nonnull TLDatabaseService *)database;

- (nonnull NSMutableArray<TLNotification *> *)listNotificationsWithFilter:(nonnull TLFilter *)filter maxDescriptors:(int)maxDescriptors;

- (nonnull NSMutableArray<TLNotification *> *)loadPendingNotifications:(nonnull id<TLRepositoryObject>)subject;

- (nullable TLNotification *)loadNotification:(nonnull NSUUID *)notificationId;

- (nonnull NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *)getNotificationStats;

- (nullable TLNotification *)createNotificationWithType:(TLNotificationType)type notificationId:(nonnull NSUUID *)notificationId subject:(nonnull id<TLRepositoryObject>)subject descriptorId:(nullable TLDescriptorId *)descriptorId annotatingUser:(nullable TLTwincodeOutbound *)annotatingUser;

- (void)acknowledgeWithNotification:(nonnull TLNotification *)notification;

- (void)deleteWithSubject:(nonnull id<TLRepositoryObject>)subject;

@end

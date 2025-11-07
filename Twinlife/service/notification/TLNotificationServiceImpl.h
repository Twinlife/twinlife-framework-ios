/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLNotificationService.h"
#import "TLBaseServiceImpl.h"

//
// Interface: TLNotification ()
//

@interface TLNotification ()

@property (readonly, nonnull) TLDatabaseIdentifier *databaseId;
@property int flags;

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier notificationType:(TLNotificationType)notificationType uuid:(nonnull NSUUID *)uuid subject:(nonnull id<TLRepositoryObject>)subject creationDate:(int64_t)creationDate descriptorId:(nullable TLDescriptorId *)descriptorId flags:(int)flags userTwincode:(nullable TLTwincodeOutbound *)userTwincode annotationType:(TLDescriptorAnnotationType)annotationType annotationValue:(int)annotationValue;

@end

//
// Interface: TLNotificationService ()
//

@class TLNotificationServiceProvider;

@interface TLNotificationService ()

@property (readonly, nonnull) TLNotificationServiceProvider *serviceProvider;

- (void)notifyCanceledWithList:(nonnull NSArray<NSUUID *> *)list;

@end

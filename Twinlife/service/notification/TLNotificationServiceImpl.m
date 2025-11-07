/*
 *  Copyright (c) 2017-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLNotificationServiceImpl.h"
#import "TLNotificationServiceProvider.h"
#import "TLTwinlifeImpl.h"

#define NOTIFICATION_SERVICE_VERSION @"2.1.1"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLNotification
//

#undef LOG_TAG
#define LOG_TAG @"TLNotification"

@implementation TLNotification

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier notificationType:(TLNotificationType)notificationType uuid:(nonnull NSUUID *)uuid subject:(nonnull id<TLRepositoryObject>)subject creationDate:(int64_t)creationDate descriptorId:(nullable TLDescriptorId *)descriptorId flags:(int)flags userTwincode:(nullable TLTwincodeOutbound *)userTwincode annotationType:(TLDescriptorAnnotationType)annotationType annotationValue:(int)annotationValue {
    DDLogVerbose(@"%@ initWithIdentifier: %@ notificationType: %d uuid: %@ subject: %@ creationDate: %lld descriptorId: %@ flags: %d", LOG_TAG, identifier, notificationType, uuid, subject, creationDate, descriptorId, flags);

    self = [super init];
    if (self) {
        _databaseId = identifier;
        _notificationType = notificationType;
        _subject = subject;
        _uuid = uuid;
        _timestamp = creationDate;
        _descriptorId = descriptorId;
        _flags = flags;
        _user = userTwincode;
        _annotationType = annotationType;
        _annotationValue = annotationValue;
    }
    return self;
}

- (BOOL)acknowledged {
    
    return (self.flags & 1) != 0;
}

- (nonnull TLDatabaseIdentifier *)identifier {
    
    return self.databaseId;
}

- (nonnull NSUUID *)objectId {
    
    return self.uuid;
}

- (BOOL)isEqual:(nullable id)object {
    
    if (self == object) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[TLNotification class]]) {
        return NO;
    }
    TLNotification* notification = (TLNotification *)object;
    return [notification.uuid isEqual:self.uuid];
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    result = 31 * result + self.uuid.hash;
    return result;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendFormat:@"[%@]", self.identifier];
    return string;
}

@end

//
// Implementation: TLNotificationServiceNotificationStat
//

#undef LOG_TAG
#define LOG_TAG @"TLNotificationServiceNotificationStat"

@implementation TLNotificationServiceNotificationStat

- (instancetype)initWithPendingCount:(long)pendingCount acknowledgedCount:(long)acknowledgedCount {
    DDLogVerbose(@"%@ initWithPendingCount: %ld acknowledgedCount: %ld", LOG_TAG, pendingCount, acknowledgedCount);
    
    self = [super init];
    if (self) {
        _pendingCount = pendingCount;
        _acknowledgedCount = acknowledgedCount;
    }
    
    return self;
}

@end

//
// Implementation: TLNotificationServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLNotificationServiceConfiguration"

@implementation TLNotificationServiceConfiguration

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithBaseServiceId:TLBaseServiceIdNotificationService version:[TLNotificationService VERSION] serviceOn:NO];
    
    return self;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLNotificationService"

@implementation TLNotificationService

+ (NSString *)VERSION {
    
    return NOTIFICATION_SERVICE_VERSION;
}

- (instancetype)initWithTwinlife:(TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super initWithTwinlife:twinlife];
    
    if (self) {
        _serviceProvider = [[TLNotificationServiceProvider alloc] initWithService:self database:twinlife.databaseService];
    }
    return self;
}

- (void)configure:(TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLNotificationServiceConfiguration* notificationServiceConfiguration = [[TLNotificationServiceConfiguration alloc] init];
    TLNotificationServiceConfiguration* serviceConfiguration = (TLNotificationServiceConfiguration *) baseServiceConfiguration;
    notificationServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.serviceConfiguration = notificationServiceConfiguration;
    self.serviceOn = YES;
}

#pragma mark - TLNotificationService

- (nullable TLNotification *)getNotificationWithNotificationId:(nonnull NSUUID *)notificationId {
    
    if (!self.serviceOn) {
        return nil;
    }
    
    return [self.serviceProvider loadNotification:notificationId];
}

- (nonnull NSMutableArray<TLNotification *> *)listNotificationsWithFilter:(nonnull TLFilter *)filter maxDescriptors:(int)maxDescriptors {
    DDLogVerbose(@"%@ listNotificationsWithFilter: %@ maxDescriptors: %d", LOG_TAG, filter, maxDescriptors);
    
    if (!self.serviceOn) {
        return [[NSMutableArray alloc] init];
    }
    
    return [self.serviceProvider listNotificationsWithFilter:filter maxDescriptors:maxDescriptors];
}

- (nonnull NSMutableArray<TLNotification *> *)getPendingNotificationsWithSubject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ getPendingNotificationsWithSubject: %@", LOG_TAG, subject);
    
    if (!self.serviceOn) {
        return [[NSMutableArray alloc] init];
    }
    
    return [self.serviceProvider loadPendingNotifications:subject];
}

- (nonnull NSMutableDictionary<NSUUID *, TLNotificationServiceNotificationStat *> *)getNotificationStats {
    DDLogVerbose(@"%@ getNotificationStats", LOG_TAG);
    
    if (!self.serviceOn) {
        return [[NSMutableDictionary alloc] init];
    }
    
    return [self.serviceProvider getNotificationStats];
}

- (nullable TLNotification *)createNotificationWithType:(TLNotificationType)type notificationId:(nullable NSUUID *)notificationId subject:(nonnull id<TLRepositoryObject>)subject descriptorId:(nullable TLDescriptorId *)descriptorId annotatingUser:(nullable TLTwincodeOutbound *)annotatingUser {
    DDLogVerbose(@"%@ createNotificationWithType: %d notificationId: %@ subject: %@ descriptorId: %@ annotatingUser: %@", LOG_TAG, type, notificationId, subject, descriptorId, annotatingUser);
    
    if (!self.serviceOn) {
        return nil;
    }
    
    if (!notificationId) {
        notificationId = [NSUUID UUID];
    }
    return [self.serviceProvider createNotificationWithType:type notificationId:notificationId subject:subject descriptorId:descriptorId annotatingUser:annotatingUser];
}

- (void)acknowledgeWithNotification:(nonnull TLNotification *)notification {
    DDLogVerbose(@"%@ acknowledgeWithNotification: %@", LOG_TAG, notification);
    
    if (!self.serviceOn) {
        return;
    }
    
    [self.serviceProvider acknowledgeWithNotification:notification];
}

- (void)deleteWithNotification:(nonnull TLNotification *)notification {
    DDLogVerbose(@"%@ deleteWithNotification: %@", LOG_TAG, notification);
    
    if (!self.serviceOn) {
        return;
    }
    
    [self.serviceProvider deleteWithObject:notification];
}

- (void)deleteWithSubject:(nonnull id<TLRepositoryObject>)subject {
    DDLogVerbose(@"%@ deleteWithSubject: %@", LOG_TAG, subject);
    
    if (!self.serviceOn) {
        return;
    }
    
    [self.serviceProvider deleteWithSubject:subject];
}

- (void)notifyCanceledWithList:(nonnull NSArray<NSUUID *> *)list {
    DDLogVerbose(@"%@ notifyCanceledWithList: %@", LOG_TAG, list);

    for (id<TLBaseServiceDelegate> delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onCanceledNotificationsWithList:)]) {
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [(id<TLNotificationServiceDelegate>)delegate onCanceledNotificationsWithList:list];
            });
        }
    }
}

@end

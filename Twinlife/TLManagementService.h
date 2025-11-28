/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

#define TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_APNS_VARIANT  @"APNS"
#define TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_VOIP_VARIANT  @"VoIP:2"
#define TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_REMOTE_VARIANT  @"Remote"
#define TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_FIREBASE_VARIANT  @"Firebase"

#define TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_APNS_ERROR @"error"
#define TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_APNS_WAIT  @"wait"
#define TL_MANAGEMENT_SERVICE_PUSH_NOTIFICATION_VOIP_DISABLED @"disabled"

//
// Inteface: TLManagementServiceConfiguration
//

@interface TLManagementServiceConfiguration : TLBaseServiceConfiguration

@property BOOL saveEnvironment;

@end

//
// Protocol: TLManagementServiceDelegate
//

@protocol TLManagementServiceDelegate <TLBaseServiceDelegate>

- (void)onValidateConfigurationWithRequestId:(int64_t)requestId;

@end

//
// Interface: TLManagementService
//

@interface TLManagementService:TLBaseService

+ (nonnull NSString *)VERSION;

- (void)setPushNotificationWithVariant:(nonnull NSString *)variant token:(nonnull NSString *)token;

- (void)validateConfigurationWithRequestId:(int64_t)requestId;

- (void)updateConfigurationWithRequestId:(int64_t)requestId;

- (nonnull NSData *)notificationKey;

- (void)sendFeedbackWithDescription:(nonnull NSString *)description email:(nonnull NSString *)email subject:(nonnull NSString *)subject logReport:(nullable NSString *)logReport withBlock:(nonnull void (^)(TLBaseServiceErrorCode errorCode))block;

- (void)logEventWithEventId:(nonnull NSString *)eventId key:(nonnull NSString *)key value:(nonnull NSString *)value flush:(BOOL)flush;

- (void)logEventWithEventId:(nonnull NSString *)eventId attributes:(nonnull NSDictionary<NSString *, NSString *> *)attributes flush:(BOOL)flush;

/// Build a log report to add in the feedback message.
- (nonnull NSString *)buildLogReport;

@end

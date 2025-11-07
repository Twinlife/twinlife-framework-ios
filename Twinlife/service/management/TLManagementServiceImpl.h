/*
 *  Copyright (c) 2013-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Leiqiang Zhong (Leiqiang.Zhong@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLManagementService.h"
#import "TLJobService.h"
#import "TLAssertion.h"

#define MANAGEMENT_SERVICE_PREFERENCES_ENVIRONMENT_ID @"EnvironmentId"

//
// Interface: TLConversationServiceAssertPoint ()
//

@interface TLManagementServiceAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)ENVIRONMENT;

@end

//
// Interface: TLEvent
//

@interface TLEvent: NSObject

@property (nonnull) NSString *eventId;
@property NSInteger timestamp;
@property (nullable) NSString *key;
@property (nullable) NSString *value;
@property (nullable, readonly) NSDictionary *attributes;

- (nonnull instancetype)initWithEventId:(nonnull NSString *)eventId attributes:(nullable NSDictionary *)attributes;

- (nonnull instancetype)initWithEventId:(nonnull NSString *)eventId key:(nullable NSString *)key value:(nullable NSString *)value;

@end

//
// Interface: TLManagementPendingRequest ()
//

@interface TLManagementPendingRequest : NSObject

@property (readonly, nonnull) NSArray<TLEvent *> *events;

- (nonnull instancetype)initWithEvents:(nonnull NSArray<TLEvent *> *)events;

@end

//
// Inteface: TLManagementService ()
//

@class TLJobId;
@class TLBaseServiceImplConfiguration;
@class TLSerializerFactory;
@class TLBinaryPacketIQ;
@class TLAssertPoint;

@interface TLManagementService ()

@property (nullable) TLBaseServiceImplConfiguration* configuration;

- (void)configure:(TLBaseServiceConfiguration *)baseServiceConfiguration applicationId:(nonnull NSUUID *)applicationId;

- (BOOL)hasValidatedConfiguration;

- (void)onValidateConfigurationWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onUpdateConfigurationWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onSetPushTokenWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onLogEventWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)onFeedbackWithIQ:(nonnull TLBinaryPacketIQ *)iq;

- (void)errorWithErrorCode:(TLBaseServiceErrorCode)errorCode errorParameter:(nullable NSString *)errorParameter;

- (void)assertionWithAssertPoint:(nonnull TLAssertPoint *)assertPoint exception:(nullable NSException *)exception vaList:(va_list)vaList;

@end

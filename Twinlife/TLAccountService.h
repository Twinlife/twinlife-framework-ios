/*
 *  Copyright (c) 2014-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

typedef enum {
    TLAccountServiceAuthenticationAuthorityUnregistered, // Account is not registered yet.
    TLAccountServiceAuthenticationAuthorityDevice,       // Using the device account model.
    TLAccountServiceAuthenticationAuthorityTwinlife,     // Using the user+password model (not used anymore/legacy).
    TLAccountServiceAuthenticationAuthorityDisabled,     // Account is disabled.
} TLAccountServiceAuthenticationAuthority;

typedef enum {
    TLAccountServicePresenceAvailable,
    TLAccountServicePresenceBusy,
    TLAccountServicePresenceDnd,
    TLAccountServicePresenceOffline
} TLAccountServicePresence;

typedef enum {
    TLAccountServiceAttributeNickname,
    TLAccountServiceAttributeFirstname,
    TLAccountServiceAttributeLastname,
    TLAccountServiceAttributeEmail,
    TLAccountServiceAttributePassword
} TLAccountAttribute;

typedef enum {
    // Feature is subscribed through Apple store.
    TLMerchantIdentificationTypeApple,

    // Feature is subscribe with an externa site.
    TLMerchantIdentificationTypeExternal
} TLMerchantIdentificationType;

//
// Interface: TLAccountServiceConfiguration
//

@interface TLAccountServiceConfiguration : TLBaseServiceConfiguration

@property TLAccountServiceAuthenticationAuthority defaultAuthenticationAuthority;

@end

//
// Protocol: TLAccountServiceDelegate
//

@protocol TLAccountServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onSignIn;

- (void)onSignInErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onSignOut;

- (void)onCreateAccountWithRequestId:(int64_t)requestId;

- (void)onDeleteAccountWithRequestId:(int64_t)requestId;

- (void)onSubscribeUpdateWithRequestId:(int64_t)requestId errorCode:(TLBaseServiceErrorCode)errorCode;

@end

//
// Interface: TLAccountService
//

@interface TLAccountService:TLBaseService

+ (nonnull NSString *)VERSION;

- (TLAccountServiceAuthenticationAuthority)getAuthenticationAuthority;

- (BOOL)isReconnectable;

- (BOOL)isFeatureSubscribedWithName:(nonnull NSString *)name;

- (void)createAccountWithRequestId:(int64_t)requestId etoken:(nullable NSString *)etoken;

- (void)signOut;

- (void)deleteAccountWithRequestId:(int64_t)requestId;

- (void)subscribeFeatureWithRequestId:(int64_t)requestId merchantId:(TLMerchantIdentificationType)merchantId purchaseProductId:(nonnull NSString *)purchaseProductId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId;

- (void)cancelFeatureWithRequestId:(int64_t)requestId merchantId:(TLMerchantIdentificationType)merchantId purchaseToken:(nonnull NSString *)purchaseToken purchaseOrderId:(nonnull NSString *)purchaseOrderId;

@end

/*
 *  Copyright (c) 2014-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

@class TLProxyDescriptor;

//
// Interface: TLConnectivityServiceConfiguration
//

@interface TLConnectivityServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Protocol: TLConnectivityServiceDelegate
//

@protocol TLConnectivityServiceDelegate <TLBaseServiceDelegate>
@optional

- (void)onNetworkConnect;

- (void)onNetworkDisconnect;

- (void)onConnect;

- (void)onDisconnect;

@end

//
// Interface: TLConnectivityService
//

@interface TLConnectivityService : TLBaseService

+ (nonnull NSString *)VERSION;

+ (int)MAX_PROXIES;

- (BOOL)isConnectedNetwork;

/// Check if user proxies are enabled.
- (BOOL)isProxyEnabled;

/// Get a list of proxy that was configured by the user.
- (nonnull NSMutableArray<TLProxyDescriptor *> *)getUserProxies;

/// Save the list of proxies configured by the user.
- (void)saveWithUserProxies:(nonnull NSArray<TLProxyDescriptor *> *)userProxies;

/// Save the user proxy enable configuration.
- (void)saveWithProxyEnabled:(BOOL)proxyEnabled;

/// Get the current proxy descriptor or nil if we are either not connected or connected directly to the signaling server.
- (nullable TLProxyDescriptor *)currentProxyDescriptor;

@end

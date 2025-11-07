/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import <SystemConfiguration/SystemConfiguration.h>

#import "TLConnectivityService.h"
#import "TLProxyDescriptor.h"

@class TLTwinlife;

//
// Interface: TLConnectivityService ()
//

@interface TLConnectivityService ()

@property (readonly, nonnull) NSCondition *connectedCondition;
@property (nullable) NSArray<TLProxyDescriptor *> *proxyDescriptors;
@property (readonly, nonnull) NSMutableArray<TLSNIProxyDescriptor *> *userProxies;
@property (nullable) NSString *userProxyConfig;
@property (nullable) TLProxyDescriptor *lastProxyDescriptor;
@property BOOL connectedNetwork;
@property BOOL proxyEnabled;
@property int proxyDescriptorLease;
@property int activeProxyIndex;

- (nonnull instancetype)initWithTwinlife:(nonnull TLTwinlife *)twinlife;

- (BOOL)isConnectedNetwork;

- (BOOL)waitForConnectedNetworkWithTimeout:(NSTimeInterval)timeout;

- (void)signalAll;

- (void)reachabilityCallback:(SCNetworkReachabilityFlags)flags;

- (nonnull NSArray<TLProxyDescriptor *> *)systemProxies;

- (void)saveLastProxyDescriptor:(nullable TLProxyDescriptor *)proxyDescriptor;

@end

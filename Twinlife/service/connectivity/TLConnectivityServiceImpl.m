/*
 *  Copyright (c) 2015-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>

#import <CocoaLumberjack.h>

#import "TLConnectivityServiceImpl.h"
#import "TLTwinlifeImpl.h"
#import "TLBaseServiceImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define CONNECTIVITY_SERVICE_VERSION @"1.2.0"
#define WEB_SOCKET_CONNECTION_PREFERENCES_ACTIVE_PROXY_DESCRIPTOR_INDEX @"ActiveProxyDescriptorIndex"
#define WEB_SOCKET_CONNECTION_PREFERENCES_ACTIVE_PROXY_DESCRIPTOR_LEASE @"ActiveProxyDescriptorLease"
#define WEB_SOCKET_CONNECTION_PREFERENCES_USER_PROXIES                  @"UserProxies"
#define WEB_SOCKET_CONNECTION_PREFERENCES_USER_PROXY_ENABLE             @"UserProxyEnable"
#define CONNECTIVITY_SERVICE_MAX_PROXIES 4
#define MAX_LEASE 64

static SCNetworkReachabilityRef reachability;

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
    TLConnectivityService *object = (__bridge TLConnectivityService *)info;

    [object reachabilityCallback:flags];
}

//
// Implementation: TLConnectivityServiceConfiguration
//

#undef LOG_TAG
#define LOG_TAG @"TLConnectivityServiceConfiguration"

@implementation TLConnectivityServiceConfiguration

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithBaseServiceId:TLBaseServiceIdConnectivityService version:[TLConnectivityService VERSION] serviceOn:NO];
    return self;
}

@end

//
// Implementation: TLConnectivityService
//

#undef LOG_TAG
#define LOG_TAG @"TLConnectivityService"

@implementation TLConnectivityService

+ (NSString *)VERSION {
    
    return CONNECTIVITY_SERVICE_VERSION;
}

+ (int)MAX_PROXIES {
    
    return CONNECTIVITY_SERVICE_MAX_PROXIES;
}

- (instancetype)initWithTwinlife:(TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    if (self = [super initWithTwinlife:twinlife]) {
        _connectedCondition = [[NSCondition alloc] init];
        _userProxies = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - TLBaseServiceImpl

- (void)configure:(TLBaseServiceConfiguration *)baseServiceConfiguration {
    DDLogVerbose(@"%@ configure: %@", LOG_TAG, baseServiceConfiguration);
    
    TLConnectivityServiceConfiguration* connectivityServiceConfiguration = [[TLConnectivityServiceConfiguration alloc] init];
    TLConnectivityServiceConfiguration* serviceConfiguration = (TLConnectivityServiceConfiguration *) baseServiceConfiguration;
    connectivityServiceConfiguration.serviceOn = serviceConfiguration.isServiceOn;
    self.configured = YES;
    self.serviceConfiguration = connectivityServiceConfiguration;
    self.proxyDescriptors = self.twinlife.twinlifeConfiguration.proxies;
    
    NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
    self.proxyEnabled = [userDefaults boolForKey:WEB_SOCKET_CONNECTION_PREFERENCES_USER_PROXY_ENABLE];
    self.userProxyConfig = [userDefaults stringForKey:WEB_SOCKET_CONNECTION_PREFERENCES_USER_PROXIES];
    if (self.userProxyConfig && self.userProxyConfig.length > 0) {
        NSArray<NSString *> *proxies = [self.userProxyConfig componentsSeparatedByString:@" "];
        for (NSString *proxy in proxies) {
            TLSNIProxyDescriptor *proxyDescriptor = [TLSNIProxyDescriptor createWithProxyDescription:proxy];
            if (proxyDescriptor) {
                [self.userProxies addObject:proxyDescriptor];
            }
        }
    }

    self.activeProxyIndex = (int)[userDefaults integerForKey:WEB_SOCKET_CONNECTION_PREFERENCES_ACTIVE_PROXY_DESCRIPTOR_INDEX];
    self.proxyDescriptorLease = (int)[userDefaults integerForKey:WEB_SOCKET_CONNECTION_PREFERENCES_ACTIVE_PROXY_DESCRIPTOR_LEASE];
    if (self.activeProxyIndex < 0) {
        self.lastProxyDescriptor = nil;
    } else if (self.activeProxyIndex < self.userProxies.count) {
        self.lastProxyDescriptor = self.userProxies[self.activeProxyIndex];
    } else {
        int index = self.activeProxyIndex - (int)self.userProxies.count;
        if (self.proxyDescriptors && index < self.proxyDescriptors.count) {
            self.lastProxyDescriptor = self.proxyDescriptors[index];
        } else {
            self.lastProxyDescriptor = nil;
            self.activeProxyIndex = -1;
            [userDefaults setObject:[NSNumber numberWithInt:-1] forKey:WEB_SOCKET_CONNECTION_PREFERENCES_ACTIVE_PROXY_DESCRIPTOR_INDEX];
            [userDefaults synchronize];
        }
    }

    // Get initial network state.
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachability, &flags)) {
        self.connectedNetwork = flags & kSCNetworkReachabilityFlagsReachable;
    } else {
        self.connectedNetwork = NO;
    }
    self.serviceOn = connectivityServiceConfiguration.serviceOn;
}

- (BOOL)activate:(TLServerConnection *)stream {
    DDLogVerbose(@"%@: activate: %@", LOG_TAG, stream);

    struct sockaddr_in6 zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin6_len = sizeof(zeroAddress);
    zeroAddress.sin6_family = AF_INET6;

    reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(reachability, ReachabilityCallback, &context)) {
        SCNetworkReachabilitySetDispatchQueue(reachability, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    }
    return YES;
}

- (void)onConnect {
    DDLogVerbose(@"%@: onConnect", LOG_TAG);
    
    [super onConnect];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onConnect)]) {
            id<TLConnectivityServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onConnect];
            });
        }
    }
}

- (void)onDisconnect {
    DDLogVerbose(@"%@: onDisconnect", LOG_TAG);
    
    [super onDisconnect];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onDisconnect)]) {
            id<TLConnectivityServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onDisconnect];
            });
        }
    }
}

#pragma mark - TLConnectivityService ()

- (BOOL)isConnectedNetwork {
    DDLogVerbose(@"%@: isConnectedNetwork %d", LOG_TAG, self.connectedNetwork);
    
    return self.connectedNetwork;
}

- (BOOL)isProxyEnabled {
 
    @synchronized (self) {
        return self.proxyEnabled;
    }
}

- (nonnull NSMutableArray<TLProxyDescriptor *> *)getUserProxies {
    DDLogVerbose(@"%@: getUserProxies", LOG_TAG);

    @synchronized (self) {
        return [[NSMutableArray alloc] initWithArray:self.userProxies];
    }
}

- (void)saveWithUserProxies:(nonnull NSArray<TLProxyDescriptor *> *)userProxies {
    DDLogVerbose(@"%@: saveWithUserProxies: %@", LOG_TAG, userProxies);
    
    NSMutableString *list;
    @synchronized (self) {
        list = [[NSMutableString alloc] initWithCapacity:512];
        [self.userProxies removeAllObjects];
        for (TLProxyDescriptor *proxy in userProxies) {
            if ([proxy isUserProxy] && [proxy isKindOfClass:[TLSNIProxyDescriptor class]]) {
                [self.userProxies addObject:(TLSNIProxyDescriptor *)proxy];
                if (list.length > 0) {
                    [list appendString:@" "];
                }
                [list appendString:[proxy proxyDescription]];
            }
        }
        if ([list isEqualToString:self.userProxyConfig]) {
            return;
        }
        self.userProxyConfig = list;
    }

    NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
    if (self.lastProxyDescriptor) {
        [self saveWithUserDefaults:userDefaults proxyDescriptor:self.lastProxyDescriptor];
    }
    [userDefaults setObject:list forKey:WEB_SOCKET_CONNECTION_PREFERENCES_USER_PROXIES];
    [userDefaults synchronize];
}

- (void)saveWithProxyEnabled:(BOOL)proxyEnabled {
    DDLogVerbose(@"%@: saveWithProxyEnabled: %d", LOG_TAG, proxyEnabled);

    @synchronized (self) {
        if (self.proxyEnabled != proxyEnabled) {
            self.proxyEnabled = proxyEnabled;

            NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
            [userDefaults setBool:proxyEnabled forKey:WEB_SOCKET_CONNECTION_PREFERENCES_USER_PROXY_ENABLE];
            [userDefaults synchronize];
        }
    }
}

- (nullable TLProxyDescriptor *)currentProxyDescriptor {
    
    return self.lastProxyDescriptor;
}

- (nonnull NSArray<TLProxyDescriptor *> *)systemProxies {
    DDLogVerbose(@"%@: systemProxies", LOG_TAG);

    NSMutableArray<TLProxyDescriptor *> *result = [[NSMutableArray alloc] initWithArray:self.proxyDescriptors];
    for (int i = (int) result.count - 1; i >= 1; i--) {
        int j = arc4random_uniform(i);
        TLProxyDescriptor *p = result[i];
        result[i] = result[j];
        result[j] = p;
    }
    return result;
}

- (void)saveLastProxyDescriptor:(nullable TLProxyDescriptor *)proxyDescriptor {
    DDLogVerbose(@"%@: saveLastProxyDescriptor: %@", LOG_TAG, proxyDescriptor);

    NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
    if ([self saveWithUserDefaults:userDefaults proxyDescriptor:proxyDescriptor]) {
        [userDefaults synchronize];
    }
}

- (BOOL)waitForConnectedNetworkWithTimeout:(NSTimeInterval)timeout {
    DDLogVerbose(@"%@: waitForConnectedNetworkWithTimeout: %f", LOG_TAG, timeout);
    
    // Get the network reachability state and detect changes.
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachability, &flags)) {
        [self reachabilityCallback:flags];
    }
    if (self.connectedNetwork) {
        return YES;
    }
    
    [self.connectedCondition lock];
    [self.connectedCondition waitUntilDate:[[NSDate alloc] initWithTimeIntervalSinceNow:timeout]];
    [self.connectedCondition unlock];
    
    // We were suspended for some time, the network could have changed, get its status again.
    if (SCNetworkReachabilityGetFlags(reachability, &flags)) {
        [self reachabilityCallback:flags];
    }
    return self.connectedNetwork;
}

- (void)signalAll {
    DDLogVerbose(@"%@: signalAll", LOG_TAG);
    
    [self.connectedCondition lock];
    [self.connectedCondition signal];
    [self.connectedCondition unlock];
}

#pragma mark - Private methods

- (BOOL)saveWithUserDefaults:(nonnull NSUserDefaults *)userDefaults proxyDescriptor:(nullable TLProxyDescriptor *)proxyDescriptor {
    DDLogVerbose(@"%@: saveWithUserDefaults: %@ proxyDescriptor: %@", LOG_TAG, userDefaults, proxyDescriptor);

    int index = -1;
    BOOL needSave;
    @synchronized (self) {
        if (proxyDescriptor) {
            BOOL found = NO;
            for (TLProxyDescriptor *proxy in self.userProxies) {
                index++;
                if (proxy == proxyDescriptor) {
                    found = YES;
                    break;
                }
            }
            if (!found) {
                if (self.proxyDescriptors) {
                    // Important note: the proxyDescriptor instance can contain a SNI configuration that is random
                    // and therefore we may not find in mProxyDescriptors the instance that the WebSocketConnection
                    // is giving us, and we must record in mLastProxyDescriptor the instance we have and not what we received.
                    for (TLProxyDescriptor *proxy in self.proxyDescriptors) {
                        index++;
                        if (proxy == proxyDescriptor || [proxy isSameWithProxy:proxyDescriptor]) {
                            found = YES;
                            proxyDescriptor = proxy;
                            break;
                        }
                    }
                }
                if (!found) {
                    index = -1;
                }
            }
        }
        self.lastProxyDescriptor = proxyDescriptor;
        if (index != self.activeProxyIndex) {
            self.proxyDescriptorLease = index < 0 ? 0 : MAX_LEASE;
            needSave = YES;
        } else if (index >= 0) {
            self.proxyDescriptorLease--;
            if (self.proxyDescriptorLease <= 0) {
                index = -1;
            }
            needSave = YES;
        } else {
            needSave = NO;
        }
        self.activeProxyIndex = index;
    }

    if (needSave) {
        [userDefaults setInteger:self.proxyDescriptorLease forKey:WEB_SOCKET_CONNECTION_PREFERENCES_ACTIVE_PROXY_DESCRIPTOR_LEASE];
        [userDefaults setInteger:index forKey:WEB_SOCKET_CONNECTION_PREFERENCES_ACTIVE_PROXY_DESCRIPTOR_INDEX];
    }
    return needSave;
}

- (void)reachabilityCallback:(SCNetworkReachabilityFlags)flags {
    DDLogVerbose(@"%@: reachabilityCallback: %u", LOG_TAG, flags);
    
    BOOL connectedNetwork = flags & kSCNetworkReachabilityFlagsReachable;
    if (self.connectedNetwork == connectedNetwork) {
        return;
    }
    
    self.connectedNetwork = connectedNetwork;
    if (connectedNetwork) {
        [self onNetworkConnect];
    } else {
        [self onNetworkDisconnect];
    }
}

- (void)onNetworkConnect {
    DDLogVerbose(@"%@: onNetworkConnect", LOG_TAG);
    
    [self.connectedCondition lock];
    [self.connectedCondition broadcast];
    [self.connectedCondition unlock];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onNetworkConnect)]) {
            id<TLConnectivityServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onNetworkConnect];
            });
        }
    }
}

- (void)onNetworkDisconnect {
    DDLogVerbose(@"%@: onNetworkDisconnect", LOG_TAG);
    
    [self.twinlife disconnect];
    
    for (id delegate in self.delegates) {
        if ([delegate respondsToSelector:@selector(onNetworkDisconnect)]) {
            id<TLConnectivityServiceDelegate> lDelegate = delegate;
            dispatch_async([self.twinlife twinlifeQueue], ^{
                [lDelegate onNetworkDisconnect];
            });
        }
    }
}

@end

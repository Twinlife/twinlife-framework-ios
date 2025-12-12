/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */
#import <CocoaLumberjack.h>
#include <stdatomic.h>

#import "TLServerConnection.h"
#import "TLConnectivityServiceImpl.h"
#import "TLTwinlife.h"

#ifdef DEBUG
static const int ddLogLevel = DDLogLevelInfo;
#else
#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif
#endif

#define MAX_PROXIES 6
#define PROXY_START_DELAY        (((5000 / 8) << 12) & 0x003FF000)  // around 5000ms, see wscontainer.h in libwebsockets
#define PROXY_FIRST_START_DELAY  (((500 / 8) << 22) & 0x7FC00000)   // around 500ms

@interface TLSocketProxyDescriptor ()

- (nonnull instancetype)initWithHostname:(nonnull NSString *)hostname port:(int)port customSNI:(nullable NSString *)customSNI;

- (nonnull instancetype)initWithHostname:(nonnull NSString *)hostname port:(int)port path:(nullable NSString *)path;

@end

@implementation TLSocketProxyDescriptor

- (nonnull instancetype)initWithHostname:(nonnull NSString *)hostname port:(int)port customSNI:(nullable NSString *)customSNI {
    
    self = [super init];
    if (self) {
        _proxyAddress = hostname;
        _proxyPort = port;
        _proxyPath = customSNI;
        _method = (customSNI ? TL_CONFIG_SNI_PASSTHROUGH |TL_CONFIG_SNI_OVERRIDE : TL_CONFIG_SNI_PASSTHROUGH);
    }
    return self;
}

- (nonnull instancetype)initWithHostname:(nonnull NSString *)hostname port:(int)port path:(nullable NSString *)path {
    
    self = [super init];
    if (self) {
        _proxyAddress = hostname;
        _proxyPort = port;
        _proxyPath = path;
        _method = 0;
    }
    return self;
}

@end

@interface TLServerConnection () <TLWebSocketDelegate>

@property (readonly, nonnull) TLWebSocketContainer *container;
@property (readonly, nonnull) id<TLServerConnectionDelegate> delegate;
@property (readonly, nonnull) NSString *hostName;
@property (readonly) UInt16 hostPort;
@property (readonly, nonnull) TLConnectivityService *connectivityService;
@property (readonly, nonnull) NSMutableArray<TLProxyDescriptor *> *proxies;
@property (readonly, nonnull) NSMutableArray<TLKeyProxyDescriptor *> *keyProxies;
@property (readonly, nonnull) NSMutableArray<TLSNIProxyDescriptor *> *sniProxies;
@property (readonly) int shuffledProxyCount;
@property (nullable) NSMutableArray<TLSNIProxyDescriptor *> *userProxies;
@property (nonnull) NSMutableArray<TLProxyDescriptor *> *shuffledProxies;
@property (nullable) TLProxyDescriptor *lastProxy;
@property (nullable) TLProxyDescriptor *activeProxy;
@property (nullable) NSMutableDictionary<NSString *, NSNumber *> *interfaces;
@property NSTimeInterval lastSendReceiveTime;
@property uint64_t connectStartTime;
@property (nullable) TLWebSocket *session;
@property (nullable) TLConnectionStats *currentStats;
@property BOOL isConnected;
@property BOOL disconnecting;
@property long sessionId;
@property long dnsErrorCount;
@property long tcpErrorCount;
@property long tlsErrorCount;
@property long txnErrorCount;
@property long tlsHostErrorCount;
@property long certificatErrorCount;
@property long proxyErrorCount;
@property atomic_int connecting;
@property int64_t shuffledDeadline;

/// Generate a random SNI out of a list of hosts, domain, TLDs.
+ (nonnull NSString *)createSNIWithList:(nonnull NSArray<NSString *> *)hostList domainList:(nonnull NSArray<NSString *> *)domainList tldList:(nonnull NSArray<NSString *> *)tldList;

/// Setup a new list of random proxies if needed.
- (void)setupProxiesWithLastProxy:(nullable TLProxyDescriptor *)lastProxy;

@end

@implementation TLErrorStats

- (nonnull instancetype)initWithConnection:(nonnull TLServerConnection *)connection {
    
    self = [super init];
    if (self) {
        _dnsErrorCount = connection.dnsErrorCount;
        _tcpErrorCount = connection.tcpErrorCount;
        _tlsErrorCount = connection.tlsErrorCount;
        _txnErrorCount = connection.txnErrorCount;
        _tlsHostErrorCount = connection.tlsHostErrorCount;
        _certificatErrorCount = connection.certificatErrorCount;
        _proxyErrorCount = connection.proxyErrorCount;
        _createCounter = connection.sessionId;
    }
    return self;
}

@end

#undef LOG_TAG
#define LOG_TAG @"TLServerConnection"

@implementation TLServerConnection

+ (nonnull NSString *)createSNIWithList:(nonnull NSArray<NSString *> *)hostList domainList:(nonnull NSArray<NSString *> *)domainList tldList:(nonnull NSArray<NSString *> *)tldList {
    
    int hostIdx = (int)arc4random_uniform((uint32_t)hostList.count);
    int domainIdx = (int)arc4random_uniform((uint32_t)domainList.count);
    int tldIdx = (int)arc4random_uniform((uint32_t)tldList.count);
    
    return [NSString stringWithFormat:@"%@.%@.%@", hostList[hostIdx], domainList[domainIdx], tldList[tldIdx]];
}

- (nonnull instancetype)initWithDomainName:(nonnull NSString *)domainName serverURL:(nonnull NSString *)serverURL delegate:(nonnull id<TLServerConnectionDelegate>)delegate connectivityService:(nonnull TLConnectivityService *)connectivityService twinlifeConfiguration:(nonnull TLTwinlifeConfiguration *)twinlifeConfiguration {
    DDLogVerbose(@"%@ initWithDomainName: %@ serverURL: %@", LOG_TAG, domainName, serverURL);
    
    self = [super init];
    if (self) {
        _hostPort = 443;
        _hostName = serverURL;
        _delegate = delegate;
        _connectTime = 0;
        _connectCount = 0;
        _connectivityService = connectivityService;
        _sessionId = 0;
        _container = [[TLWebSocketContainer alloc] initWithLevel:0];
        _proxies = [[NSMutableArray alloc] initWithCapacity:MAX_PROXIES];
        _keyProxies = [[NSMutableArray alloc] init];
        _sniProxies = [[NSMutableArray alloc] init];
        _dnsErrorCount = 0;
        _tcpErrorCount = 0;
        _tlsErrorCount = 0;
        _txnErrorCount = 0;
        _tlsHostErrorCount = 0;
        _certificatErrorCount = 0;
        _proxyErrorCount = 0;
        _connecting = NO;
        _isConnected = NO;
        _disconnecting = NO;
        _activeProxy = nil;
        _shuffledDeadline = 0;
        _shuffledProxies = nil;
        _lastProxy = nil;
        
        // Separate the Keyed proxies vs the SNI ones.
        NSArray<TLProxyDescriptor *> *proxies = connectivityService.proxyDescriptors;
        if (proxies) {
            NSArray<NSString *> *tokens = twinlifeConfiguration.tokens;
            NSMutableArray<NSString *> *tldList;
            NSMutableArray<NSString *> *domainList;
            NSMutableArray<NSString *> *hostList;
            if (tokens) {
                tldList = [[NSMutableArray alloc] initWithCapacity:tokens.count];
                domainList = [[NSMutableArray alloc] initWithCapacity:tokens.count];
                hostList = [[NSMutableArray alloc] initWithCapacity:tokens.count];
                
                for (NSString *token in tokens) {
                    NSArray<NSString *> *parts = [token componentsSeparatedByString:@"."];
                    [tldList addObject:parts[2]];
                    [domainList addObject:parts[1]];
                    [hostList addObject:parts[0]];
                }
            }
            for (TLProxyDescriptor *proxy in proxies) {
                if ([proxy isKindOfClass:[TLKeyProxyDescriptor class]]) {
                    [_keyProxies addObject:(TLKeyProxyDescriptor *)proxy];
                    
                } else if ([proxy isKindOfClass:[TLSNIProxyDescriptor class]]) {
                    TLSNIProxyDescriptor *sniProxyDescriptor = (TLSNIProxyDescriptor *)proxy;
                    NSString *sni = [TLServerConnection createSNIWithList:hostList domainList:domainList tldList:tldList];
                    [_sniProxies addObject:[[TLSNIProxyDescriptor alloc] initWithHost:sniProxyDescriptor.host port:sniProxyDescriptor.port stunPort:sniProxyDescriptor.stunPort customSNI:sni isUserProxy:NO]];
                }
            }
        }
        
        // See how many proxies we can use for the setupProxies() algorithm where we try
        // to allocate one SNI proxy and one keyed proxy randomly until we fill the MAX_PROXIES.
        int count = (int) MIN(_keyProxies.count, _sniProxies.count);
        if (count > 0) {
            count = count * 2;
        } else {
            count = (int) MAX(_keyProxies.count, _sniProxies.count);
        }
        if (count > MAX_PROXIES) {
            count = MAX_PROXIES;
        }
        _shuffledProxyCount = count;
        _shuffledProxies = [[NSMutableArray alloc] initWithCapacity:_shuffledProxyCount];
    }
    return self;
}

- (void)setupProxiesWithLastProxy:(nullable TLProxyDescriptor *)lastProxy {
    DDLogVerbose(@"%@ setupProxiesWithLastProxy: %@", LOG_TAG, lastProxy);
    
    // Shuffle the proxy descriptors randomly each 4 hours and try to get one keyed proxy
    // followed by one SNI proxy to increase the chance to try different proxy modes.
    // However, if the last proxy was changed, re-build the list.
    int64_t now = [[NSDate date] timeIntervalSince1970] * 1000;
    if ((now < self.shuffledDeadline || self.shuffledProxyCount == 0) && lastProxy == self.lastProxy) {
        return;
    }
    
    self.shuffledDeadline = now + (3 * 3600L * 1000L) + arc4random_uniform(4L * 3600L * 1000L);
    self.lastProxy = lastProxy;
    NSMutableArray<TLKeyProxyDescriptor *> *ksList = [[NSMutableArray alloc] initWithArray:self.keyProxies];
    NSMutableArray<TLSNIProxyDescriptor *> *sList = [[NSMutableArray alloc] initWithArray:self.sniProxies];
    
    // Remove the last proxy that will be tried as first proxy from the list (to make sure we don't make another connection to it).
    if (lastProxy) {
        for (int i = 0; i < ksList.count; i++) {
            if ([ksList[i] isSameWithProxy:lastProxy]) {
                [ksList removeObjectAtIndex:i];
                lastProxy = nil;
                break;
            }
        }
    }
    if (lastProxy) {
        for (int i = 0; i < sList.count; i++) {
            if ([sList[i] isSameWithProxy:lastProxy]) {
                [sList removeObjectAtIndex:i];
                lastProxy = nil;
                break;
            }
        }
    }
    [self.shuffledProxies removeAllObjects];
    for (int i = 0; i < self.shuffledProxyCount; i++) {
        TLProxyDescriptor *proxy = nil;
        if (ksList.count > 0 && ((i & 0x01) != 0 || sList.count == 0)) {
            int idx = (int) arc4random_uniform((uint32_t)ksList.count);
            proxy = ksList[idx];
            [ksList removeObjectAtIndex:idx];
        }
        if (sList.count > 0 && ((i & 0x01) == 0 || !proxy)) {
            int idx = (int) arc4random_uniform((uint32_t)sList.count);
            proxy = sList[idx];
            [sList removeObjectAtIndex:idx];
        }
        if (proxy) {
            [self.shuffledProxies addObject:proxy];
        }
    }
}

- (BOOL)isConnecting {
    DDLogVerbose(@"%@ isConnecting (session: %ld)", LOG_TAG, self.sessionId);
    
    return self.isConnecting;
}

- (BOOL)isOpened {
    DDLogVerbose(@"%@ isOpened (session=%ld)", LOG_TAG, self.sessionId);
    
    return self.session != nil && [self.session isConnected];
}

- (BOOL)isDisconnecting {
    
    return self.disconnecting;
}

- (TLConnectionStatus)connectionStatus {
    
    TLConnectionStatus result;
    @synchronized (self) {
        if (self.isConnected) {
            result = TLConnectionStatusConnected;
        } else if (self.connecting) {
            result = TLConnectionStatusConnecting;
        } else {
            result = TLConnectionStatusNoService;
        }
    }
    
    DDLogVerbose(@"%@ connectionStatus %d", LOG_TAG, result);
    return result;
}

- (BOOL)connect {
    DDLogVerbose(@"%@ connect to %@:%d", LOG_TAG, self.hostName, self.hostPort);
    
    @synchronized (self) {
        if (self.connecting || self.isConnected) {
            return YES;
        }
        self.connecting = YES;
        self.disconnecting = NO;
        self.activeProxy = nil;
    }
    
    TLProxyDescriptor *lastProxy = [self.connectivityService lastProxyDescriptor];
    [self setupProxiesWithLastProxy:lastProxy];
    
    // Build a list of proxies to use for the connection and put the last proxy as first proxy in the list.
    [self.proxies removeAllObjects];
    if (lastProxy) {
        // This is one of our SNI proxy, the connectivity service gives us an instance without a pseudo random SNI.
        // Look without our list for the instance with assigned SNI.
        if ([lastProxy isKindOfClass:[TLSNIProxyDescriptor class]] && ![lastProxy isUserProxy]) {
            for (TLSNIProxyDescriptor *sniProxy in self.sniProxies) {
                if ([sniProxy isSameWithProxy:lastProxy]) {
                    lastProxy = sniProxy;
                    break;
                }
            }
        }
        [self.proxies addObject:lastProxy];
    }
    if ([self.connectivityService isProxyEnabled]) {
        self.userProxies = [self.connectivityService userProxies];
        for (TLSNIProxyDescriptor *proxy in self.userProxies) {
            if (proxy != lastProxy && ![proxy isSameWithProxy:lastProxy]) {
                [self.proxies addObject:proxy];
            }
        }
    } else {
        self.userProxies = nil;
    }
    for (TLProxyDescriptor *proxy in self.shuffledProxies) {
        if (proxy != lastProxy && ![proxy isSameWithProxy:lastProxy]) {
            [self.proxies addObject:proxy];
        }
    }
    
    NSMutableArray<TLSocketProxyDescriptor *> *proxies = [[NSMutableArray alloc] init];
    for (TLProxyDescriptor *proxy in self.proxies) {
        if ([proxy isKindOfClass:[TLSNIProxyDescriptor class]]) {
            TLSNIProxyDescriptor *sniProxy = (TLSNIProxyDescriptor *)proxy;
            [proxies addObject:[[TLSocketProxyDescriptor alloc] initWithHostname:sniProxy.host port:sniProxy.port customSNI:sniProxy.customSNI]];
            
        } else if ([proxy isKindOfClass:[TLKeyProxyDescriptor class]]) {
            TLKeyProxyDescriptor *keyProxy = (TLKeyProxyDescriptor *)proxy;
            NSString *path = [keyProxy proxyPathWithHost:self.hostName port:self.hostPort];
            [proxies addObject:[[TLSocketProxyDescriptor alloc] initWithHostname:keyProxy.host port:keyProxy.port path:path]];
        }
    }
    
    self.sessionId++;
    int method = TL_CONFIG_SECURE | TL_CONFIG_DIRECT_CONNECT | PROXY_START_DELAY;
    if (lastProxy) {
        method |= TL_CONFIG_FIRST_PROXY | PROXY_FIRST_START_DELAY;
    }
    self.currentStats = nil;
    
    DDLogInfo(@"%@ connecting to %@:%d as session %ld", LOG_TAG, self.hostName, self.hostPort, self.sessionId);
    self.session = [self.container createWithSession:self.sessionId delegate:self port:self.hostPort host:self.hostName customSNI:nil path:@"/twinlife/server" method:method timeout:20000 proxies:proxies];
    if (self.session == nil) {
        DDLogInfo(@"%@ connection to %@:%d failed (network issue)", LOG_TAG, self.hostName, self.hostPort);
        
        // When a nil session is returned, it means the connection failed immediately due to network
        // connectivity issues.
        @synchronized (self) {
            self.connecting = NO;
        }
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)disconnect {
    DDLogVerbose(@"%@ disconnect", LOG_TAG);
    
    DDLogInfo(@"%@ disconnecting session %ld from %@", LOG_TAG, self.sessionId, self.hostName);
    BOOL wasConnected;
    TLWebSocket *session;
    @synchronized (self) {
        session = self.session;
        wasConnected = self.isConnected;
        self.disconnecting = wasConnected;
        self.session = nil;
        self.connecting = NO;
        self.isConnected = NO;
        self.activeProxy = nil;
    }
    if (session) {
        [session close];
    } else {
        [self.delegate onDisconnectWithError:TLConnectionErrorNone];
        
    }
    return !wasConnected;
}

- (BOOL)sendWithData:(NSData *)message {
    DDLogVerbose(@"%@ sendWithData: %lu", LOG_TAG, message.length);
    
    // Protect the sendWithMessage because it can be called by any thread (PeerConnectionService)
    // while another thread is closing the session.
    @synchronized (self) {
        if (self.session) {
            return [self.session sendWithMessage:message binary:YES];
        } else {
            return NO;
        }
    }
}

- (void)serviceWithTimeout:(long)timeout {
    DDLogVerbose(@"%@ serviceWithTimeout: %ld", LOG_TAG, timeout);
    
    [self.container serviceWithTimeout:(int)timeout];
}

- (nonnull TLErrorStats *)errorStats {
    
    @synchronized (self) {
        return [[TLErrorStats alloc] initWithConnection:self];
    }
}

- (nullable TLConnectionStats *)currentConnectionStats {
    
    return self.currentStats;
}

- (nullable TLProxyDescriptor *)currentProxyDescriptor {
    
    return self.activeProxy;
}

- (void)triggerWorker {
    DDLogVerbose(@"%@ triggerWorker", LOG_TAG);
    
    [self.container triggerWorker];
}

#pragma mark TLWebSocketDelegate Delegate

- (void)onPathUpdateWithInterfaces:(nonnull NSMutableDictionary<NSString *, NSNumber *> *)interfaces {
    DDLogVerbose(@"%@ onPathUpdateWithInterfaces: %@", LOG_TAG, interfaces);

    // Check if the interfaces were changed and we must reconnect.
    BOOL needReconnect = NO;
    @synchronized (self) {
        if (self.interfaces) {
            for (NSString *interface in interfaces) {
                if (self.interfaces[interface]) {
                    [self.interfaces removeObjectForKey:interface];
                } else {
                    needReconnect = YES;
                    break;
                }
            }
            needReconnect = needReconnect || self.interfaces.count > 0;
        } else {
            needReconnect = YES;
        }
        self.interfaces = interfaces;
        needReconnect = needReconnect && self.isConnected;
    }
    if (needReconnect) {
        [self disconnect];
        [self triggerWorker];
    }
}

#pragma mark TLWebSocketDelegate Delegate

/// Called when a socket connects and is ready for reading and writing. "host" will be an IP address, not a DNS name.
- (void)onConnect:(nonnull TLWebSocket *)websocket stats:(nonnull NSArray<TLConnectionStats *> *)stats active:(int)active {
    DDLogVerbose(@"%@ onConnect: %ld active: %d", LOG_TAG, [websocket sessionId], active);

    TLProxyDescriptor *proxyDescriptor = nil;
    @synchronized (self) {
        self.connecting = NO;
        self.isConnected = YES;
        self.disconnecting = NO;
        self.connectCount++;
        if (active >= 0) {
            self.currentStats = stats[active];
            // self.proxies is the list that we gave to libwebsocket and the proxyIndex gives us the proxy descriptor used.
            if (self.currentStats.proxyIndex >= 0 && self.currentStats.proxyIndex < self.proxies.count) {
                proxyDescriptor = self.proxies[self.currentStats.proxyIndex];
                proxyDescriptor.proxyStatus = self.currentStats.lastError;
            }
        } else {
            self.currentStats = nil;
        }
        self.activeProxy = proxyDescriptor;
    }
    DDLogInfo(@"%@ session %ld connected to %@%@%@ in %lld us", LOG_TAG, self.sessionId, stats[active].ipAddr, (proxyDescriptor ? @" with proxy " : @""), (proxyDescriptor ? [proxyDescriptor proxyDescription] : @""), stats[active].txnResponseTime);

    [self.connectivityService saveLastProxyDescriptor:proxyDescriptor];

    [self.delegate onConnect];
}

- (void)onClose:(nonnull TLWebSocket *)websocket {
    DDLogVerbose(@"%@ onClose: %@", LOG_TAG, websocket);
    
    DDLogInfo(@"%@ session %ld connection to %@ closed", LOG_TAG, self.sessionId, self.hostName);
    @synchronized (self) {
        self.session = nil;
        self.connecting = NO;
        self.isConnected = NO;
        self.currentStats = nil;
        self.disconnecting = YES;
        self.activeProxy = nil;
    }
    
    [self.delegate onDisconnectWithError:TLConnectionErrorNone];

    @synchronized (self) {
        self.disconnecting = NO;
    }
}

- (void)onMessage:(nonnull TLWebSocket *)websocket message:(nonnull NSData *)data binary:(BOOL)binary {
    DDLogVerbose(@"%@ onMessage: %lu", LOG_TAG, data.length);

    self.lastSendReceiveTime = [NSDate timeIntervalSinceReferenceDate];
    
    [self.delegate didReceiveBinaryWithData:data];
}

- (void)onConnectError:(nonnull TLWebSocket *)websocket stats:(nonnull NSArray<TLConnectionStats *> *)stats error:(int)error {
    DDLogVerbose(@"%@ onConnectError: %ld error: %d", LOG_TAG, [websocket sessionId], error);
    
    DDLogInfo(@"%@ session %ld connection to %@ failed: %d", LOG_TAG, self.sessionId, self.hostName, error);

    @synchronized (self) {
        self.connecting = NO;
        self.isConnected = NO;
        self.disconnecting = NO;
        self.currentStats = nil;
        self.session = nil;
        self.activeProxy = nil;
        self.disconnecting = YES;
        switch (error) {
            case TLConnectionErrorNone:
                break;
            case TLConnectionErrorDNS:
                self.dnsErrorCount++;
                break;
            case TLConnectionErrorConnect:
            case TLConnectionErrorTCP:
                self.tcpErrorCount++;
                break;
            case TLConnectionErrorTLS:
                self.tlsErrorCount++;
                break;
            case TLConnectionErrorTLSHostname:
                self.tlsHostErrorCount++;
                break;
            case TLConnectionErrorInvalidCA:
                self.certificatErrorCount++;
                break;
            case TLConnectionErrorProxy:
                self.proxyErrorCount++;
                break;
            case TLConnectionErrorWebSocket:
            case TLConnectionErrorResource:
            case TLConnectionErrorIO:
            case TLConnectionErrorTimeout:
                self.tcpErrorCount++;
                break;
        }
        // Record the status of proxy errors.
        for (int i = 1; i < stats.count; i++) {
            if (i - 1 <= self.proxies.count) {
                TLConnectionStats *st = stats[i];
                TLProxyDescriptor *proxyDescriptor = self.proxies[i - 1];
                proxyDescriptor.proxyStatus = st.lastError;
            }
        }
    }
    
    // Reconnect after a delay that depends on the error we got.
    // A random delay is added to make sure devices will not reconnect at the same time
    // in case the error is triggered by the server.
    int64_t timeout;
    switch (error) {
        case TLConnectionErrorNone:
            // Connection was closed by us or by the server.
            timeout = 500 + arc4random_uniform(8000);
            break;
            
        case TLConnectionErrorDNS:
        case TLConnectionErrorIO:
        case TLConnectionErrorTimeout:
            // For transient error, we can retry more aggressively.
            timeout = 2000 + arc4random_uniform(2000);
            break;
            
        case TLConnectionErrorTLSHostname:
        case TLConnectionErrorInvalidCA:
            // Trying to connect to a wrong server, no need to retry very often.
            timeout = 60000 + arc4random_uniform(60000);
            break;
            
        default:
            
            timeout = 10000 + arc4random_uniform(10000);
            break;
    }
    
    self.reconnectionTime = [TLTwinlife timestamp] + timeout * 1000LL * 1000LL;
    DDLogVerbose(@"%@ onDisconnect retry: %lld ms", LOG_TAG, timeout);

    [self.delegate onDisconnectWithError:error];

    @synchronized (self) {
        self.disconnecting = NO;
    }
}

- (void)onWritable:(nonnull TLWebSocket *)websocket {
    DDLogVerbose(@"%@ onWritable: %@", LOG_TAG, websocket);

}

@end

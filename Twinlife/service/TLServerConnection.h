/*
 *  Copyright (c) 2023-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <WebRTC/TLWebSocket.h>
#import "TLBaseService.h"

@class TLConnectivityService;
@class TLProxyDescriptor;
@class TLTwinlifeConfiguration;

@protocol TLServerConnectionDelegate

/// Called when we are connected to the server.
- (void)onConnect;

/// Called when a binary data message was received from the server.
- (void)didReceiveBinaryWithData:(nonnull NSData *)data;

/// The server connection failed or was disconnected.
- (void)onDisconnectWithError:(TLConnectionError)error;

@end

@interface TLErrorStats : NSObject

@property (readonly) long dnsErrorCount;
@property (readonly) long tcpErrorCount;
@property (readonly) long tlsErrorCount;
@property (readonly) long txnErrorCount;
@property (readonly) long tlsHostErrorCount;
@property (readonly) long certificatErrorCount;
@property (readonly) long proxyErrorCount;
@property (readonly) long createCounter;

@end

/**
 * Management of the WebSocket connection to the server.
 * - there is only one instance of TLServerConnection object and it is created during application setup (by `TLTwinlifeImpl start`),
 * - the `TLServerConnectionDelegate` methods are executed by the thread that calls `serviceWithTimeout`.
 */
@interface TLServerConnection : NSObject

@property int64_t connectCount;
@property int64_t connectTime;
@property int64_t reconnectionTime;

/// Create the server connection instance during application start.
- (nonnull instancetype)initWithDomainName:(nonnull NSString *)domainName serverURL:(nonnull NSString *)serverURL delegate:(nonnull id<TLServerConnectionDelegate>)delegate connectivityService:(nonnull TLConnectivityService *)connectivityService twinlifeConfiguration:(nonnull TLTwinlifeConfiguration *)twinlifeConfiguration;

/// Returns YES is the connection is currently connecting
- (BOOL)isConnecting;

/// Returns YES if the websocket connect is open and established.
- (BOOL)isOpened;

/// Returns YES if the websocket is being closed.
- (BOOL)isDisconnecting;

- (TLConnectionStatus)connectionStatus;

/// Connect to the server (configured by `initWithDomainName`) through the proxy if necessary.
- (BOOL)connect;

/// Disconnects from the remote host by closing the underlying TCP socket connection.
- (BOOL)disconnect;

/// Send the binary data message to the server.
/// Returns YES if the message was put on the write queue and NO if we are not connected.
- (BOOL)sendWithData:(nonnull NSData *)message;

- (void)serviceWithTimeout:(long)timeout;

/// Get the statistics about connection errors.
- (nonnull TLErrorStats *)errorStats;

/// Get the statistics about the current websocket connection or null if we are not connected.
- (nullable TLConnectionStats *)currentConnectionStats;

/// Get the current proxy descriptor used by the websocket connection or null if we are connected directly.
- (nullable TLProxyDescriptor *)currentProxyDescriptor;

/// Trigger the worker so that the service thread that executes the serviceWithTimeout can return earlier.
- (void)triggerWorker;

- (void)onPathUpdateWithInterfaces:(nonnull NSMutableDictionary<NSString *, NSNumber *> *)interfaces;

@end

/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <WebRTC/TLWebSocket.h>

//
// Interface: TLProxyDescriptor
//

@interface TLProxyDescriptor : NSObject

@property (readonly, nonnull) NSString *host;
@property (readonly) int port;
@property (readonly) int stunPort;
@property (readonly) BOOL isUserProxy;
@property TLConnectionError proxyStatus;

- (nonnull instancetype)initWithHost:(nonnull NSString *)host port:(int)port stunPort:(int)stunPort isUserProxy:(BOOL)isUserProxy;

/// Get the proxy description that can be saved to restore the proxy information.
- (nonnull NSString *)proxyDescription;

/// Check if the two proxies are almost the same.  This is not a isEqual() we only want to  compare the address and port.
- (BOOL)isSameWithProxy:(nullable TLProxyDescriptor *)proxy;

@end

//
// Interface: TLKeyProxyDescriptor
//

@interface TLKeyProxyDescriptor : TLProxyDescriptor

@property (readonly, nullable) NSString *key;

- (nonnull instancetype)initWithAddress:(nonnull NSString *)address port:(int)port stunPort:(int)stunPort key:(nonnull NSString *)key;

- (nullable NSString *)proxyPathWithHost:(nonnull NSString *)host port:(int)port;

@end

//
// Interface: TLSNIProxyDescriptor
//

@interface TLSNIProxyDescriptor : TLProxyDescriptor

@property (readonly, nullable) NSString *customSNI;

- (nonnull instancetype)initWithHost:(nonnull NSString *)host port:(int)port stunPort:(int)stunPort customSNI:(nullable NSString *)customSNI isUserProxy:(BOOL)isUserProxy;

+ (nullable TLSNIProxyDescriptor *)createWithProxyDescription:(nonnull NSString *)proxyDescription;

@end

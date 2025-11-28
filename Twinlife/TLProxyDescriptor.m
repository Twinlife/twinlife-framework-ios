/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CommonCrypto/CommonDigest.h>
#import "TLProxyDescriptor.h"

//
// Implementation: TLProxyDescriptor
//

@implementation TLProxyDescriptor

- (nonnull instancetype)initWithHost:(nonnull NSString *)host port:(int)port stunPort:(int)stunPort isUserProxy:(BOOL)isUserProxy {
    
    self = [super init];
    if (self) {
        _host = host;
        _port = port;
        _stunPort = stunPort;
        _isUserProxy = isUserProxy;
        _proxyStatus = TLConnectionErrorNone;
    }
    return self;
}

- (nonnull NSString *)proxyDescription {
    
    if (self.port == 443) {
        return self.host;
    } else {
        return [NSString stringWithFormat:@"%@:%d", self.host, self.port];
    }
}

- (BOOL)isSameWithProxy:(nullable TLProxyDescriptor *)proxy {
    
    return proxy != nil && self.port == proxy.port && [self.host isEqual:proxy.host];
}

- (NSString *)description {
    
    return [NSString stringWithFormat:@"%@:%d", self.host, self.port];
}

@end

//
// Implementation: TLKeyProxyDescriptor
//

@implementation TLKeyProxyDescriptor

- (nonnull instancetype)initWithAddress:(nonnull NSString *)address port:(int)port stunPort:(int)stunPort key:(nonnull NSString *)key {
    
    self = [super initWithHost:address port:port stunPort:stunPort isUserProxy:NO];
    if (self) {
        _key = key;
    }
    return self;
}

- (nullable NSString *)proxyPathWithHost:(nonnull NSString *)host port:(int)port {

    if (!self.key) {

        return nil;
    }

    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];
    int len = (int) self.key.length;
    for (int i = 0; i < len; i++) {
        char c = [self.key characterAtIndex:i];
        if (c < 'a' || c > 'z') {
            
            return nil;
        }

        uint8_t value = (uint8_t) (c - 'a');
        value += arc4random_uniform(8) * 29;
        [result appendFormat:@"%c", (char) ('a' + value / 16)];
        [result appendFormat:@"%c", (char) ('a' + value % 16)];
    }
    [result appendString:@"/"];

    NSData *data = [[NSString stringWithFormat:@"%@:%d", host, port] dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        uint8_t value = digest[i];
        uint8_t value1 = value / 16;
        uint8_t value2 = value % 16;

        value1 += arc4random_uniform(8) * 29;
        [result appendFormat:@"%c", (char) ('a' + value1 / 16)];
        [result appendFormat:@"%c", (char) ('a' + value1 % 16)];

        value2 += arc4random_uniform(8) * 29;
        [result appendFormat:@"%c", (char) ('a' + value2 / 16)];
        [result appendFormat:@"%c", (char) ('a' + value2 % 16)];
    }

    [result appendString:@".html"];
    return result;
}

@end

//
// Implementation: TLSNIProxyDescriptor
//

@implementation TLSNIProxyDescriptor

- (nonnull instancetype)initWithHost:(nonnull NSString *)host port:(int)port stunPort:(int)stunPort customSNI:(nullable NSString *)customSNI isUserProxy:(BOOL)isUserProxy {
    
    self = [super initWithHost:host port:port stunPort:stunPort isUserProxy:isUserProxy];
    if (self) {
        _customSNI = customSNI;
    }
    return self;
}

- (nonnull NSString *)proxyDescription {
    
    NSString *proxy = [super proxyDescription];
    if (self.customSNI && self.stunPort > 0) {
        return [NSString stringWithFormat:@"%@,%@,%d", proxy, self.customSNI, self.stunPort];
    }
    return self.customSNI ? [NSString stringWithFormat:@"%@,%@", proxy, self.customSNI] : proxy;
}

+ (nullable TLSNIProxyDescriptor *)createWithProxyDescription:(nonnull NSString *)proxyDescription {
    
    NSArray<NSString *> *parts = [proxyDescription componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/,"]];
    if (parts.count != 1 && parts.count != 2 && parts.count != 3) {
        return nil;
    }
    NSString *customSNI = (parts.count >= 2 ? parts[1] : nil);
    NSString *hostPort = parts[0];
    int port = 443;
    int stunPort = 0;
    NSRange pos = [hostPort rangeOfString:@":"];
    if (pos.location != NSNotFound) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        NSNumber *num = [formatter numberFromString:[hostPort substringFromIndex:pos.location + 1]];
        if (!num || num.intValue <= 0 || num.intValue >= 65536) {
            return nil;
        }
        port = num.intValue;
        hostPort = [hostPort substringToIndex:pos.location];
    }
    if (parts.count == 3) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        NSNumber *num = [formatter numberFromString:parts[2]];
        if (!num || num.intValue <= 0 || num.intValue >= 65536) {
            return nil;
        }
        stunPort = num.intValue;
    }
    return [[TLSNIProxyDescriptor alloc] initWithHost:hostPort port:port stunPort:stunPort customSNI:customSNI isUserProxy:YES];
}

@end

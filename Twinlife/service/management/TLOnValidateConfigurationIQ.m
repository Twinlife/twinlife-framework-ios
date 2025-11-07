/*
 *  Copyright (c) 2021-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnValidateConfigurationIQ.h"
#import <WebRTC/RTCHostname.h>

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Validate configuration response IQ.
 *
 * Schema version 2
 * <pre>
 * {
 *  "schemaId":"A0589646-2B24-4D22-BE5B-6215482C8748",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnValidateConfigurationIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"environmentId", "type":"uuid"},
 *     {"name":"features", [null, "type":"string"]},
 *     {"name":"webrtcDisableAEC", [null, "type":"boolean"]},
 *     {"name":"webrtcDisableNS", [null, "type":"boolean"]},
 *     {"name":"turnTTL", "type":"int"},
 *     {"name":"turnServerCount", "type":"int"}, [
 *        {"name":"turnURL", "type":"string"},
 *        {"name":"turnUsername", "type":"string"},
 *        {"name":"turnPassword", "type":"string"},
 *     ]},
 *     {"name":"hostnames", "type":"int"}, [
 *        {"name":"hostname", "type":"string"},
 *        {"name":"ipv4", "type":"string"},
 *        {"name":"ipv6", "type":"string"},
 *     ]}
 *  ]
 * }
 * </pre>
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"A0589646-2B24-4D22-BE5B-6215482C8748",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnValidateConfigurationIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"environmentId", "type":"uuid"},
 *     {"name":"features", [null, "type":"string"]},
 *     {"name":"webrtcDisableAEC", [null, "type":"boolean"]},
 *     {"name":"webrtcDisableNS", [null, "type":"boolean"]},
 *     {"name":"turnTTL", "type":"int"},
 *     {"name":"turnServerCount", "type":"int"}, [
 *        {"name":"turnURL", "type":"string"},
 *        {"name":"turnUsername", "type":"string"},
 *        {"name":"turnPassword", "type":"string"},
 *     ]}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnValidateConfigurationIQSerializer
//

@implementation TLOnValidateConfigurationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnValidateConfigurationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {

    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *environmentId = [decoder readUUID];
    NSString *features = [decoder readOptionalString];
    [decoder readEnum];
    [decoder readEnum];
    int turnTTL = [decoder readInt];
    int count = [decoder readInt];
    NSMutableArray<TLTurnServer *> *turnServers = [[NSMutableArray alloc] initWithCapacity:count];
    while (count > 0) {
        count--;
        NSString *turnURL = [decoder readString];
        NSString *turnUsername = [decoder readString];
        NSString *turnPassword = [decoder readString];
        
        [turnServers addObject:[[TLTurnServer alloc] initWithUrl:turnURL username:turnUsername password:turnPassword]];
    }
    count = [decoder readInt];
    NSMutableArray<RTC_OBJC_TYPE(RTCHostname) *> *hostnames = [[NSMutableArray alloc] initWithCapacity:count];
    while (count > 0) {
        count--;
        NSString *hostname = [decoder readString];
        NSString *ipv4 = [decoder readString];
        NSString *ipv6 = [decoder readString];
        
        [hostnames addObject:[[RTC_OBJC_TYPE(RTCHostname) alloc] initWithHostname:hostname ipv4:ipv4 ipv6:ipv6]];
    }

    return [[TLOnValidateConfigurationIQ alloc] initWithSerializer:self iq:iq environmentId:environmentId features:features webrtcDisableAEC:nil webrtcDisableNS:nil turnTTL:turnTTL turnServers:turnServers hostnames:hostnames];
}

@end

//
// Implementation: TLOnValidateConfigurationIQ
//

@implementation TLOnValidateConfigurationIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq environmentId:(nonnull NSUUID *)environmentId features:(nullable NSString *)features webrtcDisableAEC:(nullable BOOL *)webrtcDisableAEC webrtcDisableNS:(nullable BOOL *)webrtcDisableNS turnTTL:(int)turnTTL turnServers:(nonnull NSArray<TLTurnServer *> *)turnServers hostnames:(nonnull NSArray<RTC_OBJC_TYPE(RTCHostname) *> *)hostnames {

    self = [super initWithSerializer:serializer iq:iq];
    
    if (self) {
        _environmentId = environmentId;
        _features = features;
        _webrtcDisableAEC = webrtcDisableAEC;
        _webrtcDisableNS = webrtcDisableNS;
        _turnTTL = turnTTL;
        _turnServers = turnServers;
        _hostnames = hostnames;
    }
    return self;
}

@end

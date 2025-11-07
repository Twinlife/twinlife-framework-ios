/*
 *  Copyright (c) 2021-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <WebRTC/RTCMacros.h>
#import "TLBinaryPacketIQ.h"

@class TLTurnServer;
@class RTC_OBJC_TYPE(RTCHostname);

//
// Interface: TLOnValidateConfigurationIQSerializer
//

@interface TLOnValidateConfigurationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnValidateConfigurationIQ
//

@interface TLOnValidateConfigurationIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *environmentId;
@property (readonly, nullable) NSString *features;
@property (readonly, nullable) BOOL *webrtcDisableAEC;
@property (readonly, nullable) BOOL *webrtcDisableNS;
@property (readonly) int turnTTL;
@property (readonly, nonnull) NSArray<TLTurnServer *> *turnServers;
@property (readonly, nonnull) NSArray<RTC_OBJC_TYPE(RTCHostname) *> *hostnames;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq environmentId:(nonnull NSUUID *)environmentId features:(nullable NSString *)features webrtcDisableAEC:(nullable BOOL *)webrtcDisableAEC webrtcDisableNS:(nullable BOOL *)webrtcDisableNS turnTTL:(int)turnTTL turnServers:(nonnull NSArray<TLTurnServer *> *)turnServers hostnames:(nonnull NSArray<RTC_OBJC_TYPE(RTCHostname) *> *)hostnames;

@end

/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLValidateConfigurationIQSerializer
//

@interface TLValidateConfigurationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLValidateConfigurationIQ
//

@interface TLValidateConfigurationIQ : TLBinaryPacketIQ

@property (readonly) int deviceState;
@property (readonly, nullable) NSUUID *environmentId;
@property (readonly, nullable) NSString *pushVariant;
@property (readonly, nullable) NSString *pushToken;
@property (readonly, nullable) NSString *pushRemoteToken;
@property (readonly, nonnull) NSDictionary<NSString *, NSString *> *services;
@property (readonly, nonnull) NSDictionary<NSString *, NSString *> *configs;
@property (readonly, nonnull) NSString *hardwareName;
@property (readonly, nonnull) NSString *osName;
@property (readonly, nonnull) NSString *capabilities;
@property (readonly, nonnull) NSString *locale;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState environmentId:(nullable NSUUID *)environmentId pushVariant:(nullable NSString *)pushVariant pushToken:(nullable NSString *)pushToken pushRemoteToken:(nullable NSString *)pushRemoteToken services:(nonnull NSDictionary<NSString *, NSString *> *)services hardwareName:(nonnull NSString *)hardwareName osName:(nonnull NSString *)osName locale:(nonnull NSString *)locale capabilities:(nonnull NSString *)capabilities configs:(nonnull NSDictionary<NSString *, NSString *> *)configs;

@end

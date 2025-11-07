/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLUpdatePermissionsIQSerializer
//

@interface TLUpdatePermissionsIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLUpdatePermissionsIQ
//

@interface TLUpdatePermissionsIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSUUID *groupTwincodeId;
@property (readonly, nonnull) NSUUID *memberTwincodeId;
@property (readonly) int64_t permissions;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_2;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId permissions:(int64_t)permissions;

@end

//
// Interface: TLOnUpdatePermissionsIQ
//

@interface TLOnUpdatePermissionsIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_1;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1;

@end

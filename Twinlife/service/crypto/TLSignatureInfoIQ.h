/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryPacketIQ.h"

#define SIGNATURE_INFO_SCHEMA_ID       [[NSUUID alloc] initWithUUIDString:@"e08a0f39-fb5c-4e54-9f4c-eb0fd60b5a37"]
#define SIGNATURE_INFO_SCHEMA_VERSION  1
//
// Interface: TLSignatureInfoIQSerializer
//

@interface TLSignatureInfoIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLSignatureInfoIQ
//

@interface TLSignatureInfoIQ : TLBinaryPacketIQ

@property (nonatomic, readonly, nonnull) NSUUID *twincodeOutboundId;
@property (nonatomic, readonly, nonnull) NSString *publicKey;
@property (nonatomic, readonly, nonnull) NSData *secret;
@property (nonatomic, readonly) int keyIndex;

+ (nonnull NSUUID *)SCHEMA_ID;
+ (int)SCHEMA_VERSION;
+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER;


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey keyIndex:(int)keyIndex secret:(nonnull NSData *)secret;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId publicKey:(nonnull NSString *)publicKey keyIndex:(int)keyIndex secret:(nonnull NSData *)secret;

@end

//
// Interface: TLOnSignatureInfoIQ
//

@interface TLOnSignatureInfoIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER;

@end

//
// Interface: TLAckSignatureInfoIQ
//

@interface TLAckSignatureInfoIQ : NSObject

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER;

@end

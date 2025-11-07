/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLInvokeTwincodeIQSerializer
//

@interface TLInvokeTwincodeIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLInvokeTwincodeIQ
//

@interface TLInvokeTwincodeIQ : TLBinaryPacketIQ

@property (readonly) int invocationOptions;
@property (readonly, nullable) NSUUID *invocationId;
@property (readonly, nonnull) NSUUID *twincodeId;
@property (readonly, nonnull) NSString *actionName;
@property (readonly, nullable) NSMutableArray<TLAttributeNameValue *> *attributes;
@property (readonly, nullable) NSData *data;
@property (readonly) int64_t deadline;
@property (readonly) int dataLength;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId twincodeId:(nonnull NSUUID *)twincodeId invocationOptions:(int)invocationOptions invocationId:(nullable NSUUID *)invocationId actionName:(nonnull NSString *)actionName attributes:(nullable NSMutableArray<TLAttributeNameValue *> *)attributes data:(nullable NSData *)data dataLength:(int)dataLength deadline:(int64_t)deadline;

@end

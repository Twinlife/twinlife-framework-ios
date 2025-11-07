/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLMemberSessionInfo
//

@interface TLMemberSessionInfo : NSObject

@property (readonly, nonnull) NSString *memberId;
@property (readonly, nullable) NSUUID *sessionId;

- (nonnull instancetype)initWithMemberId:(nonnull NSString *)memberId sessionId:(nullable NSUUID *)sessionId;

+ (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder members:(nullable NSArray<TLMemberSessionInfo *> *)members;

+ (nullable NSArray<TLMemberSessionInfo *> *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder;

@end

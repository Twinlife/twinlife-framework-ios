/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <Foundation/Foundation.h>

@interface TLMemberInfo : NSObject

@property (readonly, nonnull) NSUUID *memberTwincodeId;
@property (readonly) int64_t memberPermission;
@property (readonly, nonnull) NSData *memberPublicKey;
@property (readonly, nonnull) NSData *signature;
@property (readonly, nullable) NSData *rosterKeySignature;

- (nonnull instancetype)initWithNewMemberTwincodeId:(nonnull NSUUID *)newMemberTwincodeId
                             newMemberPermission:(int64_t)newMemberPermission
                            newMemberPublicKey:(nonnull NSData *)newMemberPublicKey
                                       signature:(nonnull NSData *)signature
                            rosterKeySignature:(nullable NSData *)rosterKeySignature;

@end

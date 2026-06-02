/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLMemberInfo.h"

@implementation TLMemberInfo

- (nonnull instancetype)initWithNewMemberTwincodeId:(nonnull NSUUID *)newMemberTwincodeId
                             newMemberPermission:(int64_t)newMemberPermission
                            newMemberPublicKey:(nonnull NSData *)newMemberPublicKey
                                       signature:(nonnull NSData *)signature
                            rosterKeySignature:(nullable NSData *)rosterKeySignature {

    self = [super init];
    if (self) {
        _memberTwincodeId = newMemberTwincodeId;
        _memberPermission = newMemberPermission;
        _memberPublicKey = newMemberPublicKey;
        _signature = signature;
        _rosterKeySignature = rosterKeySignature;
    }
    return self;
}

@end

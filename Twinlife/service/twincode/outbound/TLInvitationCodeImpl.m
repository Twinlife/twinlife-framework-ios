/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLInvitationCode.h"

//
// Implementation: TLInvitationCode
//

@implementation TLInvitationCode

- (nonnull instancetype)initWithCreationDate:(int64_t)creationDate validityPeriod:(int)validityPeriod code:(nonnull NSString *)code publicKey:(nullable NSString *)publicKey {
    
    self = [super init];
    
    if (self) {
        _creationDate = creationDate;
        _validityPeriod = validityPeriod;
        _code = code;
        _publicKey = publicKey;
    }
    
    return self;
}

@end

/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSecureRosterService.h"
#import "TLBaseServiceImpl.h"

@class TLTwincodeOutbound;
@protocol TLGroupConversation;

//
// Forward declarations for pending requests
//
@class TLSecureRosterPendingRequest;
@class TLCreateRosterPendingRequest;
@class TLListRosterPendingRequest;
@class TLRosterPendingRequest;

//
// Interface: TLSecureRosterService ()
//

@interface TLSecureRosterService ()

+ (void)initialize;

- (void)addMembersWithRosterId:(nonnull TLRosterId *)rosterId
                     signingMember:(nonnull TLTwincodeOutbound *)signingMember
                          members:(nonnull NSArray<TLMemberIdentity *> *)members
                          complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

@end

/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationProtocol.h"

#define INVOKE_TWINCODE_ACTION_CONVERSATION_SYNCHRONIZE       @"twinlife::conversation::synchronize"
#define INVOKE_TWINCODE_ACTION_CONVERSATION_NEED_SECRET       @"twinlife::conversation::need-secret"
#define INVOKE_TWINCODE_ACTION_MEMBER_TWINCODE_OUTBOUND_ID    @"memberTwincodeOutboundId"

//
// Implementation: TLConversationProtocol
//

@implementation TLConversationProtocol

+ (nonnull NSString *)ACTION_CONVERSATION_SYNCHRONIZE {
    
    return INVOKE_TWINCODE_ACTION_CONVERSATION_SYNCHRONIZE;
}

+ (nonnull NSString *)ACTION_CONVERSATION_NEED_SECRET {
    
    return INVOKE_TWINCODE_ACTION_CONVERSATION_NEED_SECRET;
}

+ (nonnull NSString *)invokeTwincodeActionMemberTwincodeOutboundId {
    
    return INVOKE_TWINCODE_ACTION_MEMBER_TWINCODE_OUTBOUND_ID;
}

@end

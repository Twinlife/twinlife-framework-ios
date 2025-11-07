/*
 *  Copyright (c) 2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGroupProtocol.h"
#import "TLAttributeNameValue.h"

#define INVOKE_TWINCODE_ACTION_GROUP_SUBSCRIBE @"twinlife::conversation::subscribe"
#define INVOKE_TWINCODE_ACTION_GROUP_REGISTERED @"twinlife::conversation::registered"
#define INVOKE_TWINCODE_ACTION_MEMBER_TWINCODE_ID @"memberTwincodeId"
#define INVOKE_TWINCODE_ACTION_ADMIN_PERMISSIONS @"adminPermissions"
#define INVOKE_TWINCODE_ACTION_MEMBER_PERMISSIONS @"memberPermissions"
#define INVOKE_TWINCODE_ACTION_ADMIN_TWINCODE_ID @"adminTwincodeId"

//
// Implementation: TLConversationProtocol
//

@implementation TLGroupProtocol

+ (void) setInvokeTwincodeActionGroupSubscribeMemberTwincodeId:(NSMutableArray *)attributes memberTwincodeId:(NSUUID *)memberTwincodeId {
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:INVOKE_TWINCODE_ACTION_MEMBER_TWINCODE_ID stringValue:memberTwincodeId.UUIDString]];
}

+ (nonnull NSString *)invokeTwincodeActionGroupSubscribe {

    return INVOKE_TWINCODE_ACTION_GROUP_SUBSCRIBE;
}

+ (nonnull NSString *)invokeTwincodeActionGroupRegistered {
    
    return INVOKE_TWINCODE_ACTION_GROUP_REGISTERED;
}

+ (nonnull NSString *)invokeTwincodeActionAdminPermissions {
    
    return INVOKE_TWINCODE_ACTION_ADMIN_PERMISSIONS;
}

+ (nonnull NSString *)invokeTwincodeActionMemberPermissions {
    
    return INVOKE_TWINCODE_ACTION_MEMBER_PERMISSIONS;
}

+ (nonnull NSString *)invokeTwincodeActionAdminTwincodeId {
    
    return INVOKE_TWINCODE_ACTION_ADMIN_TWINCODE_ID;
}

@end

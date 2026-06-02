/*
 *  Copyright (c) 2019-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGroupProtocol.h"
#import "TLAttributeNameValue.h"
#import "TLTwincodeOutboundService.h"
#import "TLSecureRosterService.h"

#define INVOKE_TWINCODE_ACTION_GROUP_SUBSCRIBE @"twinlife::conversation::subscribe"
#define INVOKE_TWINCODE_ACTION_GROUP_REGISTERED @"twinlife::conversation::registered"
#define INVOKE_TWINCODE_ACTION_MEMBER_TWINCODE_ID @"memberTwincodeId"
#define INVOKE_TWINCODE_ACTION_ADMIN_PERMISSIONS @"adminPermissions"
#define INVOKE_TWINCODE_ACTION_MEMBER_PERMISSIONS @"memberPermissions"
#define INVOKE_TWINCODE_ACTION_ADMIN_TWINCODE_ID @"adminTwincodeId"

#define TL_GROUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"a70f964c-7147-4825-afe2-d14da222f181"]
#define TL_LEGACY_GROUP_SCHEMA_ID [[NSUUID alloc] initWithUUIDString:@"e3eab04a-263f-4e5d-95b8-e18252f49f7b"]

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

+ (nonnull NSUUID *)ROSTER_SCHEMA_ID {

    return TL_GROUP_SCHEMA_ID;
}

+ (nonnull NSUUID *)LEGACY_SCHEMA_ID {
    
    return TL_LEGACY_GROUP_SCHEMA_ID;
}

+ (nonnull NSString *)ACTION_ROSTER_UPDATE {
    
    return @"roster::update";
}

+ (nonnull NSString *)ACTION_ROSTER_LEAVE {
    
    return @"roster::leave";
}

+ (nullable TLRosterId *)getSecureRosterIdWithTwincode:(nullable TLTwincodeOutbound *)twincode {
    if (!twincode) {
        return nil;
    }

    NSString *rosterId = (NSString *)[twincode getAttributeWithName:TL_ROSTER_ID];
    if (!rosterId) {
        return nil;
    }

    NSArray<NSString *> *parts = [rosterId componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
    if (parts.count != 2) {
        return nil;
    }

    NSUUID *rId = [NSUUID toUUID:parts[0]];
    NSUUID *schemaId = [NSUUID toUUID:parts[1]];
    return rId && schemaId ? [[TLRosterId alloc] initWithId:rId schemaId:schemaId] : nil;
}

+ (void)setSecureRosterId:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes rosterId:(nonnull TLRosterId *)rosterId {
    
    [attributes addObject:[[TLAttributeNameStringValue alloc] initWithName:TL_ROSTER_ID stringValue:[NSString stringWithFormat:@"%@:%@", [rosterId.rosterId toString], [rosterId.schemaId toString]]]];
}

@end

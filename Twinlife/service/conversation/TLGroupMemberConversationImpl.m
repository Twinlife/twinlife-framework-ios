/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLConversationImpl.h"
#import "TLGroupConversationImpl.h"
#import "TLGroupMemberConversationImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLRepositoryService.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"

#if 0
static const int ddLogLevel = DDLogLevelWarning;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

static NSUUID *GROUP_MEMBER_CONVERSATION_SCHEMA_ID = nil;

//
// Interface: TLGroupMemberConversationImpl
//

@interface TLGroupMemberConversationImpl ()

@property (nullable) NSUUID *invitationContactId;

@end

//
// Implementation: TLGroupMemberConversationImpl
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupMemberConversationImpl"

@implementation TLGroupMemberConversationImpl

+ (void)initialize {
 
    GROUP_MEMBER_CONVERSATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"a25aa6c7-e0d3-4959-997f-2dd820b0ce74"];
}
 
+ (NSUUID *)SCHEMA_ID {
 
    return GROUP_MEMBER_CONVERSATION_SCHEMA_ID;
}

- (nonnull instancetype)initWithIdentifier:(nonnull TLDatabaseIdentifier *)identifier conversationId:(nonnull NSUUID *)conversationId group:(nonnull TLGroupConversationImpl *)group creationDate:(int64_t)creationDate resourceId:(nonnull NSUUID *)resourceId peerResourceId:(nullable NSUUID *)peerResourceId permissions:(int64_t)permissions lastConnectDate:(int64_t)lastConnectDate lastRetryDate:(int64_t)lastRetryDate flags:(int)flags peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound invitedContactId:(nullable NSUUID *)invitedContactId {
    DDLogVerbose(@"%@ initWithIdentifier: %@ conversationId: %@ group: %@", LOG_TAG, identifier, conversationId, group);
    
    self = [super initWithIdentifier:identifier conversationId:conversationId subject:group.subject creationDate:creationDate resourceId:resourceId peerResourceId:peerResourceId permissions:permissions lastConnectDate:lastConnectDate lastRetryDate:lastRetryDate flags:flags];
    if (self) {
        _group = group;
        _peerTwincodeOutbound = peerTwincodeOutbound;
        _invitationContactId = invitedContactId;
    }
    
    return self;
}

- (nonnull NSUUID *)peerTwincodeOutboundId {

    TLTwincodeOutbound *peerTwincodeOutbound = self.peerTwincodeOutbound;
    if (peerTwincodeOutbound) {
        return [peerTwincodeOutbound uuid];
    } else {
        return [TLTwincode NOT_DEFINED];
    }
}

- (NSUUID*)memberTwincodeId {
    
    TLTwincodeOutbound *peerTwincodeOutbound = self.peerTwincodeOutbound;
    if (peerTwincodeOutbound) {
        return [self.peerTwincodeOutbound uuid];
    } else {
        return [TLTwincode NOT_DEFINED];
    }
}

- (NSUUID*)invitedContactId {
    
    return self.invitationContactId;
}

- (BOOL)isLeaving {
    
    return self.permissions == 0;
}

- (void)markLeaving {
    
    self.permissions = 0;
}

- (id<TLGroupConversation>)groupConversation {
    
    return self.group;
}

- (nonnull id<TLConversation>)mainConversation {
    
    return self.group;
}

- (BOOL)isGroup {
    
    return YES;
}

- (BOOL)hasPeer {

    return YES;
}

- (BOOL)isConversationWithUUID:(NSUUID *)id {

    return [self.group.uuid isEqual:id];
}

- (nonnull NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLGroupMemberConversation["];
    [self appendTo:string];
    [string appendString:@"]"];
    return string;
}

@end

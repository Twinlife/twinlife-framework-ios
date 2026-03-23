/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLGroupConversationHandler.h"
#import "TLGroupConversationImpl.h"
#import "TLGroupMemberConversationImpl.h"
#import "TLRepositoryService.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLGroupConversationRestorerV1
//

@interface TLGroupConversationRestorerV1 : TLRestorer<id<TLConversation>>

@property (nonatomic, nonnull, readonly) TLConversationService *conversationService;

- (nonnull instancetype)initWithConversationService:(nonnull TLConversationService *)conversationService;

@end

//
// Implementation: TLGroupConversationRestorerV1
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupConversationRestorerV1"

@implementation TLGroupConversationRestorerV1

+ (nonnull NSNumber *) VERSION {
    return @1;
}

- (nonnull instancetype)initWithConversationService:(nonnull TLConversationService *)conversationService {
    self = [super init];
    
    if (self) {
        _conversationService = conversationService;
    }
    
    return self;
}

- (nullable id<TLConversation>) restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");

    int64_t dbId = [decoder readLong];
    NSUUID *conversationId = [decoder readUUID];
    int64_t creationDate = [decoder readLong];
    int64_t groupId = [decoder readLong];
    int64_t subjectId = [decoder readLong];
    NSUUID *peerTwincodeOutboundId = [decoder readUUID];
    NSUUID *resourceId = [decoder readUUID];
    NSUUID *peerResourceId = [decoder readOptionalUUID];
    NSUUID *invitedContactId = [decoder readOptionalUUID];
    int64_t permissions = [decoder readLong];
    int64_t joinPermissions = [decoder readLong];
    int flags = [decoder readInt];
    
    id<TLConversation> conversation = [self.conversationService restoreGroupConversationWithDatabaseId:dbId conversationId:conversationId creationDate:creationDate groupId:groupId subjectId:subjectId peerTwincodeOutboundId:peerTwincodeOutboundId resourceId:resourceId peerResourceId:peerResourceId invitedContactId:invitedContactId permissions:permissions joinPermissions:joinPermissions flags:flags];
    
    if (!conversation) {
        //TODO BKP error handling
        DDLogWarn(@"%@ could not restore conversation %@", LOG_TAG, conversationId);
        return nil;
    }
    
    DDLogVerbose(@"%@ Restored conversation: %@", LOG_TAG, conversation);
    
    return conversation;
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);
    
    @throw [NSException exceptionWithName:@"TLDecoderException" reason:@"TODO BKP: implement before activating group backup/restore." userInfo:nil];
}

@end

@interface TLGroupConversationHandler ()

@property (nonatomic, nonnull, readonly) TLConversationService *conversationService;

@end

//
// Implementation: TLGroupConversationHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLGroupConversationHandler"

@implementation TLGroupConversationHandler

- (nonnull instancetype)initWithConversationService:(TLConversationService *)conversationService {
    self = [super initWithRestorers:@{
        TLGroupConversationRestorerV1.VERSION : [[TLGroupConversationRestorerV1 alloc] initWithConversationService:conversationService]
    }];
    
    if (self) {
        _conversationService = conversationService;
    }
    
    return self;
}


- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogVerbose(@"%@ backupWithBinaryEncoder: %@", LOG_TAG, encoder);

    for (id<TLConversation> conversation in [self.conversationService listGroupConversations]) {
        
        if (![conversation isKindOfClass:TLGroupConversationImpl.class]) {
            DDLogWarn(@"%@ conversation %@ is not a group conversation, ignoring", LOG_TAG, conversation.uuid.UUIDString);
            continue;
        }
        
        TLGroupConversationImpl *groupConv = (TLGroupConversationImpl *)conversation;
        
        [encoder writeUUID:TL_GROUP_CONVERSATION_BACKUP_SCHEMA_ID];
        [encoder writeInt:TL_GROUP_CONVERSATION_BACKUP_SCHEMA_VERSION];
        [encoder writeLong:groupConv.identifier.identifier];
        [encoder writeUUID:groupConv.uuid];
        [encoder writeLong:groupConv.creationDate];
        [encoder writeLong:groupConv.subject.identifier.identifier]; // groupId
        [encoder writeLong:groupConv.subject.identifier.identifier]; //subjectId
        [encoder writeUUID:groupConv.peerTwincodeOutboundId];
        
        TLGroupMemberConversationImpl *incomingConversation = groupConv.incomingConversation;
        [encoder writeUUID:incomingConversation.resourceId];
        [encoder writeOptionalUUID:incomingConversation.peerResourceId];
        [encoder writeOptionalUUID:incomingConversation.invitedContactId];
        [encoder writeLong:groupConv.permissions];
        [encoder writeLong:groupConv.joinPermissions];
        [encoder writeInt:groupConv.flags];
        
        for (TLGroupMemberConversationImpl *groupMemberConv in [groupConv groupMembersWithFilter:TLGroupMemberFilterTypeAllMembers]) {
            [encoder writeUUID:TL_GROUP_CONVERSATION_BACKUP_SCHEMA_ID];
            [encoder writeInt:TL_GROUP_CONVERSATION_BACKUP_SCHEMA_VERSION];
            [encoder writeLong:groupMemberConv.identifier.identifier];
            [encoder writeUUID:groupMemberConv.uuid];
            [encoder writeLong:groupMemberConv.creationDate];
            [encoder writeLong:groupMemberConv.subject.identifier.identifier]; // groupId
            [encoder writeLong:groupMemberConv.subject.identifier.identifier]; //subjectId
            [encoder writeUUID:groupMemberConv.peerTwincodeOutboundId];
            
            [encoder writeUUID:groupMemberConv.resourceId];
            [encoder writeOptionalUUID:groupMemberConv.peerResourceId];
            [encoder writeOptionalUUID:groupMemberConv.invitedContactId];
            [encoder writeLong:groupMemberConv.permissions];
            [encoder writeLong:0L]; // join permissions
            [encoder writeInt:groupMemberConv.flags];
        }
    }
}
@end

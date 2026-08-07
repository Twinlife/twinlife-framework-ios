/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLContactShareDescriptorImpl.h"
#import "TLConversationService.h"
#import "TLImageId.h"
#import "TLInvitationDescriptorImpl.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLContactShareDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLContactShareDescriptor"

@implementation TLContactShareDescriptor

+ (nonnull NSUUID *)CONTACT_SHARE_SCHEMA_ID {
    return [NSUUID toUUID:@"95EAAFDA-9660-4D77-88F5-413510451C21"];
}

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeContactShareDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLContactShareDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" name: %@ status:%u invitationTwincodeOutboundId: %@\n", self.name, self.status, self.invitationTwincodeOutboundId.UUIDString];
}

#pragma mark - TLContactShareDescriptor ()


- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout name:(nonnull NSString *)name contactId:(nonnull NSUUID *)contactId {
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil expireTimeout:expireTimeout];
    
    if (self) {
        _name = name;
        _status = TLInvitationDescriptorStatusTypePending;
        _autoAnswer = NO;
        _invitationTwincodeOutboundId = nil;
        _targetContactId = contactId;
        _invitationTwincodeOutboundPubkey = nil;
    }
    
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString *)content value:(int64_t)value {
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    
    if (self) {
        
        NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];
        
        _name = [TLDescriptor extractStringWithArgs:args position:0 defaultValue:@""];
                        
        NSString *invitationTwincodeOutboundId = [TLDescriptor extractStringWithArgs:args position:1 defaultValue:nil];
        
        if (invitationTwincodeOutboundId && invitationTwincodeOutboundId.length > 0) {
            _invitationTwincodeOutboundId = [NSUUID toUUID:invitationTwincodeOutboundId];
        }
        
        NSString *targetContactId = [TLDescriptor extractStringWithArgs:args position:2 defaultValue:nil];
        
        if (targetContactId && targetContactId.length > 0) {
            _targetContactId = [NSUUID toUUID:targetContactId];
        }
        
        _invitationTwincodeOutboundPubkey = [TLDescriptor extractStringWithArgs:args position:3 defaultValue:nil];
        
        _autoAnswer = [TLDescriptor extractLongWithArgs:args position:4 defaultValue:0L] == 1L;
        
        _status = [TLInvitationDescriptor toInvitationStatus:(int)value];
    }
    
    return self;
}

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp name:(nonnull NSString *)name status:(TLInvitationDescriptorStatusType)status{

    self = [super initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:replyTo expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    
    if (self) {
        _name = name;
        _status = status;
        _autoAnswer = NO;
        _invitationTwincodeOutboundId = nil;
        _targetContactId = nil;
        _invitationTwincodeOutboundPubkey = nil;
    }
    
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    NSMutableString *result = [NSMutableString string];
    [result appendString:self.name];
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    if (self.invitationTwincodeOutboundId) {
        [result appendString:self.invitationTwincodeOutboundId.UUIDString];
    } else {
        [result appendString:@""];
    }
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    if (self.targetContactId) {
        [result appendString:self.targetContactId.UUIDString];
    } else {
        [result appendString:@""];
    }
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    if (self.invitationTwincodeOutboundPubkey) {
        [result appendString:self.invitationTwincodeOutboundPubkey];
    } else {
        [result appendString:@""];
    }
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    [result appendString:(self.autoAnswer ? @"1" : @"0")];
    
    return result;
}


- (int)flags {
    return 0;
}

- (void)markEdited {
    // NOOP
}

- (int64_t)value {
    
    return [TLInvitationDescriptor fromInvitationStatus:self.status];
}

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder {
    // NOOP
}

- (void)deleteDescriptor {
    DDLogVerbose(@"%@ deleteDescriptor", LOG_TAG);

    NSString *avatarPath = self.getAvatarPath;
    
    [[NSFileManager defaultManager] removeItemAtPath:avatarPath error:nil];
}

- (nullable NSData *)loadAvatarData {
    DDLogVerbose(@"%@ loadAvatarData", LOG_TAG);

    NSURL *fileURL = [NSURL fileURLWithPath:self.getAvatarPath];
    return [NSData dataWithContentsOfURL:fileURL];
}

- (void)saveAvatarWithData:(nullable NSData *)data {
    DDLogVerbose(@"%@ saveAvatarWithData: %@", LOG_TAG, data);

    if (!data || data.length == 0) {
        return;
    }
    
    NSString *avatarPath = self.getAvatarPath;
    NSString *conversationPath = [avatarPath stringByDeletingLastPathComponent];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:conversationPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSURL *fileURL = [NSURL fileURLWithPath:avatarPath];
    NSError *error = nil;
    [data writeToURL:fileURL options:NSDataWritingAtomic error:&error];
    
    if (error) {
        DDLogError(@"Failed to save avatar: %@", error);
    }
}

- (nonnull NSString *)getAvatarPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"Conversations/%@/%lld", [self.descriptorId.twincodeOutboundId UUIDString], self.descriptorId.sequenceId];

    return [TLTwinlife getAppGroupPath:fileManager path:path];
}

@end

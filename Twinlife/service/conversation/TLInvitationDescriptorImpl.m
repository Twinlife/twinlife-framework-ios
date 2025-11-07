/*
 *  Copyright (c) 2018-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLInvitationDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLSerializerFactory.h"
#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLTwincode.h"

/*
 * <pre>
 *
 * Schema version 1
 *  Date: 2018/07/09
 *
 * {
 *  "schemaId":"751761ce-2d1c-4af4-ba85-6c0764f21ed0",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"InvitationDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor"
 *  "fields":
 *  [
 *   {"name":"groupTwincode", "type":"uuid"}
 *   {"name":"memberTwincode", "type":"uuid"}
 *   {"name":"inviterTwincode", "type":"uuid"}
 *   {"name":"name", "type":"string"}
 *   {"name":"status", "type":"InvitationDescriptor.Status"}
 *  ]
 * }
 *
 * </pre>
 */

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLInvitationDescriptorSerializer
//

static NSUUID *INVITATION_DESCRIPTOR_SCHEMA_ID = nil;
static const int INVITATION_DESCRIPTOR_SCHEMA_VERSION_1 = 1;
static TLSerializer *INVITATION_DESCRIPTOR_SERIALIZER_1 = nil;

#undef LOG_TAG
#define LOG_TAG @"TLInvitationDescriptorSerializer_1"

@implementation TLInvitationDescriptorSerializer_1

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super initWithSchemaId:TLInvitationDescriptor.SCHEMA_ID schemaVersion:TLInvitationDescriptor.SCHEMA_VERSION_1 class:[TLInvitationDescriptor class]];
    return self;
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    DDLogVerbose(@"%@ serializeWithSerializerFactory: %@ encoder: %@ object: %@", LOG_TAG, serializerFactory, encoder, object);
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLInvitationDescriptor *invitationDescriptor = (TLInvitationDescriptor *)object;
    [encoder writeUUID:invitationDescriptor.groupTwincodeId];
    [encoder writeUUID:invitationDescriptor.memberTwincodeId];
    [encoder writeUUID:invitationDescriptor.inviterTwincodeId];
    [encoder writeString:invitationDescriptor.name];
    [encoder writeEnum:[TLInvitationDescriptor fromInvitationStatus:invitationDescriptor.status]];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    DDLogVerbose(@"%@ deserializeWithSerializerFactory: %@ decoder: %@", LOG_TAG, serializerFactory, decoder);
    
    TLDescriptor *descriptor = (TLDescriptor *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSUUID *groupTwincodeId = [decoder readUUID];
    NSUUID *memberTwincodeId = [decoder readUUID];
    NSUUID *inviterTwincodeId = [decoder readUUID];
    NSString *name = [decoder readString];
    int value = [decoder readEnum];
    
    TLInvitationDescriptorStatusType status = [TLInvitationDescriptor toInvitationStatus:value];
    return [[TLInvitationDescriptor alloc] initWithDescriptor:descriptor groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId inviterTwincodeId:inviterTwincodeId name:name status:status];
}

@end

//
// Implementation: TLInvitationDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLInvitationDescriptor"

@implementation TLInvitationDescriptor

+ (void)initialize {
    
    INVITATION_DESCRIPTOR_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"751761ce-2d1c-4af4-ba85-6c0764f21ed0"];
    INVITATION_DESCRIPTOR_SERIALIZER_1 = [[TLInvitationDescriptorSerializer_1 alloc] init];
}

+ (NSUUID *)SCHEMA_ID {
    
    return INVITATION_DESCRIPTOR_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION_1 {
    
    return INVITATION_DESCRIPTOR_SCHEMA_VERSION_1;
}

+ (TLSerializer *)SERIALIZER_1 {
    
    return INVITATION_DESCRIPTOR_SERIALIZER_1;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString *string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLInvitationDescriptor\n"];
    [self appendTo:string];
    [string appendFormat:@" groupName: %@\n", self.name];
    [string appendFormat:@" groupTwincodeId: %@\n", [self.groupTwincodeId UUIDString]];
    [string appendFormat:@" memberTwincodeId: %@\n", [self.memberTwincodeId UUIDString]];
    [string appendFormat:@" status: %u\n", self.status];
    return string;
}

#pragma mark - TLDescriptor ()

- (TLDescriptorType)getType {
    
    return TLDescriptorTypeInvitationDescriptor;
}

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
}

#pragma mark - TLInvitationDescriptor ()

+ (int)fromInvitationStatus:(TLInvitationDescriptorStatusType)status {
    switch (status) {
        case TLInvitationDescriptorStatusTypePending:
            return 0;
        case TLInvitationDescriptorStatusTypeAccepted:
            return 1;
        case TLInvitationDescriptorStatusTypeRefused:
            return 2;
        case TLInvitationDescriptorStatusTypeWithdrawn:
            return 3;
        case TLInvitationDescriptorStatusTypeJoined:
            return 4;
        default:
            return -1;
    }
}

+ (TLInvitationDescriptorStatusType)toInvitationStatus:(int)value {
    switch (value) {
        case 0:
            return TLInvitationDescriptorStatusTypePending;
        case 1:
            return TLInvitationDescriptorStatusTypeAccepted;
        case 2:
            return TLInvitationDescriptorStatusTypeRefused;
        case 3:
            return TLInvitationDescriptorStatusTypeWithdrawn;
        case 4:
            return TLInvitationDescriptorStatusTypeJoined;
        default:
            return TLInvitationDescriptorStatusTypeWithdrawn;
    }
}

- (instancetype)initWithDescriptorId:(TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId groupTwincodeId:(NSUUID *)groupTwincodeId inviterTwincodeId:(NSUUID *)inviterTwincodeId name:(NSString *)name publicKey:(nullable NSString *)publicKey {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld groupTwincodeId: %@ inviterTwincodeId: %@ name: %@", LOG_TAG, descriptorId, conversationId, groupTwincodeId, inviterTwincodeId, name);
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil expireTimeout:0];
    
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = nil;
        _inviterTwincodeId = inviterTwincodeId; // The twincode outbound of the group member who sent the invitation.
        _name = name;
        _publicKey = publicKey;
        _status = TLInvitationDescriptorStatusTypePending;
    }
    return self;
}

- (instancetype)initWithDescriptor:(TLDescriptor *)descriptor groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId inviterTwincodeId:(NSUUID *)inviterTwincodeId name:(NSString *)name status:(TLInvitationDescriptorStatusType)status {
    DDLogVerbose(@"%@ initWithDescriptor: %@ groupTwincodeId: %@ memberTwincodeId: %@ inviterTwincodeId: %@ name: %@ status: %u", LOG_TAG, descriptor, groupTwincodeId, memberTwincodeId, inviterTwincodeId, name, status);
    
    self = [super initWithDescriptor:descriptor];
    
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _inviterTwincodeId = inviterTwincodeId;
        _name = name;
        _status = status;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId groupTwincodeId:(nonnull NSUUID *)groupTwincodeId inviterTwincodeId:(nullable NSUUID *)inviterTwincodeId name:(nonnull NSString *)name publicKey:(nullable NSString *)publicKey creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate expireTimeout:(int64_t)expireTimeout {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ groupTwincodeId: %@ inviterTwincodeId: %@ name: %@ publicKey: %@ creationDate: %lld", LOG_TAG, descriptorId, groupTwincodeId, inviterTwincodeId, name, publicKey, creationDate);

    self = [super initWithDescriptorId:descriptorId conversationId:0 sendTo:nil replyTo:nil creationDate:creationDate sendDate:sendDate receiveDate:0 readDate:0 updateDate:0 peerDeleteDate:0 deleteDate:0 expireTimeout:expireTimeout];
    if(self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = nil;
        _inviterTwincodeId = inviterTwincodeId;
        _name = name;
        _status = TLInvitationDescriptorStatusTypePending;
        _publicKey = publicKey;
    }
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId sendTo:(nullable NSUUID *)sendTo replyTo:(nullable TLDescriptorId *)replyTo creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString*)content status:(int64_t)status {
    DDLogVerbose(@"%@ initWithDescriptorId: %@ conversationId: %lld creationDate: %lld flags: %d content: %@ status: %lld", LOG_TAG, descriptorId, conversationId, creationDate, flags, content, status);

    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:sendTo replyTo:replyTo creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    if(self) {
        NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];
        _groupTwincodeId = [TLDescriptor extractUUIDWithArgs:args position:0 defaultValue:[TLTwincode NOT_DEFINED]];
        _memberTwincodeId = [TLDescriptor extractUUIDWithArgs:args position:1 defaultValue:[TLTwincode NOT_DEFINED]];
        _inviterTwincodeId = [TLDescriptor extractUUIDWithArgs:args position:2 defaultValue:[TLTwincode NOT_DEFINED]];
        _name = [TLDescriptor extractStringWithArgs:args position:3 defaultValue:@""];
        _status = [TLInvitationDescriptor toInvitationStatus:(int)status];
        _publicKey = [TLDescriptor extractStringWithArgs:args position:4 defaultValue:nil];
    }
    return self;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];
    [result appendString:[self.groupTwincodeId UUIDString]];
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    if (!self.memberTwincodeId || [[TLTwincode NOT_DEFINED] isEqual:self.memberTwincodeId]) {
        [result appendString:@"?"];
    } else {
        [result appendString:[self.memberTwincodeId UUIDString]];
    }
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    if ([[TLTwincode NOT_DEFINED] isEqual:self.inviterTwincodeId]) {
        [result appendString:@"?"];
    } else {
        [result appendString:[self.inviterTwincodeId UUIDString]];
    }
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    [result appendString:self.name];
    if (self.publicKey) {
        [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
        [result appendString:self.publicKey];
    }
    return result;
}

- (int64_t)value {

    return [TLInvitationDescriptor fromInvitationStatus:self.status];
}

@end

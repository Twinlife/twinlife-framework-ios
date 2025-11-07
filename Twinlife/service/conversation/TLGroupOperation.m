/*
 *  Copyright (c) 2018-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLGroupOperation.h"

#import "TLBinaryDecoder.h"
#import "TLBinaryEncoder.h"
#import "TLConversationService.h"

#define SERIALIZER_BUFFER_DEFAULT_SIZE 128

/*
 * <pre>
 * Schema version 2
 *  Date: 2024/09/09
 * {
 *  "schemaId":"493e6d32-a023-455a-9952-c76162c319c9",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"GroupOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "fields":
 *  [
 *   {"name":"groupTwincodeId", "type":"UUID"}
 *   {"name":"memberTwincodeId", "type":"UUID"}
 *   {"name":"permissions", "type":"long"}
 *   {"name":"publicKey", "type":"String"}
 *   {"name":"signedOffTwincodeId", "type":[null, "UUID"]}
 *   {"name":"signature", "type":"String"}
 *  ]
 * }
 * </pre>
 *
 * Schema version 1
 *
 * {
 *  "schemaId":"493e6d32-a023-455a-9952-c76162c319c9",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"GroupOperation",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "fields":
 *  [
 *   {"name":"groupTwincodeId", "type":"UUID"}
 *   {"name":"memberTwincodeId", "type":"UUID"}
 *   {"name":"permissions", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLGroupOperationSerializer
//

static NSUUID *GROUP_OPERATION_SCHEMA_ID = nil;

//
// Implementation: TLGroupOperation
//

@implementation TLGroupOperation

+ (void)initialize {
    
    GROUP_OPERATION_SCHEMA_ID = [[NSUUID alloc] initWithUUIDString:@"493e6d32-a023-455a-9952-c76162c319c9"];
}

+ (NSUUID *)SCHEMA_ID {
    
    return GROUP_OPERATION_SCHEMA_ID;
}

+ (int)SCHEMA_VERSION {
    
    return GROUP_OPERATION_SCHEMA_VERSION_1;
}

+ (nullable NSData *)serializeOperation:(nullable NSUUID *)groupTwincodeId memberTwincodeId:(nullable NSUUID *)memberTwincodeId permissions:(int64_t)permissions publicKey:(nullable NSString *)publicKey signedOffTwincodeId:(nullable NSUUID *)signedOffTwincodeId signature:(nullable NSString *)signature {
    
    if (!groupTwincodeId || !memberTwincodeId) {
        return nil;
    }

    NSMutableData *content = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    TLBinaryEncoder *encoder = [[TLBinaryEncoder alloc] initWithData:content];

    [encoder writeInt:publicKey ? GROUP_OPERATION_SCHEMA_VERSION_2 : GROUP_OPERATION_SCHEMA_VERSION_1];
    [encoder writeUUID:groupTwincodeId];
    [encoder writeUUID:memberTwincodeId];
    [encoder writeLong:permissions];
    if (publicKey) {
        [encoder writeString:publicKey];
        [encoder writeOptionalUUID:signedOffTwincodeId];
        [encoder writeOptionalString:signature];
    }
    return content;
}

- (instancetype)initWithConversation:(TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor {
    
    self = [super initWithConversation:conversation type:type descriptor:invitationDescriptor];
    
    if (self) {
        _groupTwincodeId = invitationDescriptor.groupTwincodeId;
        _memberTwincodeId = invitationDescriptor.memberTwincodeId;
    }
    return self;
}

- (instancetype)initWithConversation:(TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type invitationDescriptor:(TLInvitationDescriptor *)invitationDescriptor groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId {
    
    self = [super initWithConversation:conversation type:type descriptor:invitationDescriptor];
    
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
    }
    return self;
}

- (instancetype)initWithConversation:(TLConversationImpl *)conversation type:(TLConversationServiceOperationType)type groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId {
    
    self = [super initWithConversation:conversation type:type descriptor:nil];
    
    if(self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
    }
    return self;
}

- (nonnull instancetype)initWithId:(int64_t)id type:(TLConversationServiceOperationType)type conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId groupTwincodeId:(NSUUID *)groupTwincodeId memberTwincodeId:(NSUUID *)memberTwincodeId {
    
    self = [super initWithId:id type:type conversationId:conversationId creationDate:creationDate descriptorId:descriptorId];
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
    }
    return self;
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLGroupOperation\n"];
    [self appendTo:string];
    return string;
}

@end

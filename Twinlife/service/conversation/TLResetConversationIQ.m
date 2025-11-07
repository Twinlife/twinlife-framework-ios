/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLResetConversationIQ.h"
#import "TLClearDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * ResetConversation IQ.
 * <p>
 * Schema version 4
 *  Date: 2022/02/09
 *  Clear, reset conversation and inform the user
 *
 * <pre>
 * {
 *  "schemaId":"412f43fa-bee9-4268-ac6f-98e99e457d03",
 *  "schemaVersion":"4",
 *
 *  "type":"record",
 *  "name":"ResetConversationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields":
 *  [
 *   {"name":"clearDescriptor", "type":["null", {
 *     {"name":"twincodeOutboundId", "type":"uuid"},
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"createdTimestamp", "type":"long"},
 *     {"name":"sentTimestamp", "type":"long"},
 *   }},
 *   {"name":"clearTimestamp", "type":"long"},
 *   {"name":"clearMode", "type":"enum"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLResetConversationIQSerializer
//

@implementation TLResetConversationIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLResetConversationIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLResetConversationIQ *resetConversationIQ = (TLResetConversationIQ *)object;
    TLClearDescriptor *clearDescriptor = resetConversationIQ.clearDescriptor;

    if (!clearDescriptor) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:1];
        TLDescriptorId *descriptorId = clearDescriptor.descriptorId;
        [encoder writeUUID:descriptorId.twincodeOutboundId];
        [encoder writeLong:descriptorId.sequenceId];
        [encoder writeLong:clearDescriptor.createdTimestamp];
        [encoder writeLong:clearDescriptor.sentTimestamp];
    }
    
    [encoder writeLong:resetConversationIQ.clearTimestamp];
    switch (resetConversationIQ.clearMode) {
        case TLConversationServiceClearLocal:
            [encoder writeEnum:0];
            break;
            
        case TLConversationServiceClearBoth:
            [encoder writeEnum:1];
            break;

            // 2023-02-21: added this new clear mode but supported only starting with ConversationService 2.15.
        case TLConversationServiceClearMedia:
            [encoder writeEnum:2];
            break;
        
        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    int64_t requestId = [decoder readLong];

    TLClearDescriptor *clearDescriptor;
    int64_t clearTimestamp;

    if ([decoder readEnum] != 0) {
        NSUUID *twincodeOutboundId = [decoder readUUID];
        int64_t sequenceId = [decoder readLong];
        int64_t createdTimestamp = [decoder readLong];
        int64_t sentTimestamp = [decoder readLong];
        clearTimestamp = [decoder readLong];

        TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithId:0 twincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
        clearDescriptor = [[TLClearDescriptor alloc] initWithDescriptorId:descriptorId conversationId:0 createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp clearTimestamp:clearTimestamp];
    } else {
        clearDescriptor = nil;
        clearTimestamp = [decoder readLong];
    }
    
    TLConversationServiceClearMode clearMode;
    switch ([decoder readEnum]) {
        case 0:
            clearMode = TLConversationServiceClearLocal;
            break;

        case 1:
            clearMode = TLConversationServiceClearBoth;
            break;

            // 2023-02-21: added this new clear mode but supported only starting with ConversationService 2.15.
        case 2:
            clearMode = TLConversationServiceClearMedia;
            break;

        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }

    return [[TLResetConversationIQ alloc] initWithSerializer:self requestId:requestId clearDescriptor:clearDescriptor clearTimestamp:clearTimestamp clearMode:clearMode];
}

@end

//
// Implementation: TLResetConversationIQ
//

@implementation TLResetConversationIQ

static TLResetConversationIQSerializer *IQ_RESET_CONVERSATION_SERIALIZER_4;
static const int IQ_RESET_CONVERSATION_SCHEMA_VERSION_4 = 4;

+ (void)initialize {
    
    IQ_RESET_CONVERSATION_SERIALIZER_4 = [[TLResetConversationIQSerializer alloc] initWithSchema:@"412f43fa-bee9-4268-ac6f-98e99e457d03" schemaVersion:IQ_RESET_CONVERSATION_SCHEMA_VERSION_4];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_RESET_CONVERSATION_SERIALIZER_4.schemaId;
}

+ (int)SCHEMA_VERSION_4 {

    return IQ_RESET_CONVERSATION_SERIALIZER_4.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_4 {
    
    return IQ_RESET_CONVERSATION_SERIALIZER_4;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId clearDescriptor:(nullable TLClearDescriptor *)clearDescriptor clearTimestamp:(int64_t)clearTimestamp clearMode:(TLConversationServiceClearMode)clearMode {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _clearDescriptor = clearDescriptor;
        _clearTimestamp = clearTimestamp;
        _clearMode = clearMode;
    }
    return self;
}

@end

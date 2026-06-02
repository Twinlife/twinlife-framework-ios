/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPushPollIQ.h"
#import "TLPollDescriptorImpl.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * PushPoll IQ.
 * <p>
 * Schema version 1
 *  Date: 2026/03/17
 *
 * {
 *  "schemaId":"963e3df1-dad7-43c1-8135-f858b94d69ab",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"PollDescriptor",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.conversation.Descriptor.3"
 *  "fields":
 *  [
 *   {"name":"multipleChoicesAllowed", "type":"boolean"}
 *   {"name":"copyAllowed", "type":"boolean"}
 *   {"name":"question", "type":"string"}
 *   [
 *      {"name":"position", "type":"int"},
 *      {"name":"label", "type":"String"}
 *   ]
 *  ]
 * }
 */

//
// Implementation: TLPushPollIQSerializer
//

@implementation TLPushPollIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLPushPollIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLPushPollIQ *pushPollIQ = (TLPushPollIQ *)object;
    
    TLPollDescriptor *pollDescriptor = pushPollIQ.pollDescriptor;
    
    [encoder writeUUID:pollDescriptor.descriptorId.twincodeOutboundId];
    [encoder writeLong:pollDescriptor.descriptorId.sequenceId];
    [encoder writeOptionalUUID:pollDescriptor.sendTo];
    
    [encoder writeLong:pollDescriptor.createdTimestamp];
    [encoder writeLong:pollDescriptor.sentTimestamp];
    [encoder writeLong:pollDescriptor.expireTimeout];
    
    [encoder writeBoolean:pollDescriptor.multipleChoicesAllowed];
    [encoder writeBoolean:pollDescriptor.copyAllowed];
    [encoder writeString:pollDescriptor.question];
    
    [encoder writeInt:(int)pollDescriptor.choices.count];
    for (TLChoice *choice in pollDescriptor.choices) {
        [encoder writeInt:choice.position];
        [encoder writeString:choice.label];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    NSUUID *sendTo = [decoder readOptionalUUID];
    
    int64_t createdTimestamp = [decoder readLong];
    int64_t sentTimestamp = [decoder readLong];
    int64_t expireTimeout = [decoder readLong];

    BOOL multipleChoicesAllowed = [decoder readBoolean];
    BOOL copyAllowed = [decoder readBoolean];
    NSString *question = [decoder readString];
    
    int nbChoices = [decoder readInt];
    NSMutableArray<TLChoice *> *choices = [NSMutableArray arrayWithCapacity:nbChoices];
    for (int i = 0; i < nbChoices; i++) {
        int position = [decoder readInt];
        NSString *label = [decoder readString];
        [choices addObject:[[TLChoice alloc] initWithPosition:position label:label]];
    }
    TLPollDescriptor *pollDescriptor = [[TLPollDescriptor alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId expireTimeout:expireTimeout sendTo:sendTo createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp multipleChoicesAllowed:multipleChoicesAllowed question:question choices:choices copyAllowed:copyAllowed];
    
    return [[TLPushPollIQ alloc] initWithSerializer:self requestId:requestId pollDescriptor:pollDescriptor];
}

@end

//
// Implementation: TLPushPollIQ
//

@implementation TLPushPollIQ

static TLPushPollIQSerializer *IQ_PUSH_POLL_SERIALIZER_1;
static const int IQ_PUSH_POLL_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_PUSH_POLL_SERIALIZER_1 = [[TLPushPollIQSerializer alloc] initWithSchema:@"963e3df1-dad7-43c1-8135-f858b94d69ab" schemaVersion:IQ_PUSH_POLL_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_POLL_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_PUSH_POLL_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_PUSH_POLL_SERIALIZER_1;
}


- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId pollDescriptor:(nonnull TLPollDescriptor *)pollDescriptor {
    
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _pollDescriptor = pollDescriptor;
    }
    
    return self;
}

@end

/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnAnswerContactShareIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnPushPoll IQ.
 *
 * Schema version 1
 *  Date: 2026/03/23
 *
 * <pre>
 * {
 *  "schemaId":"48245700-ddf2-49b5-991f-300ee7df96a1",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnPushPollIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnAnswerContactShareIQ
//

@implementation TLOnAnswerContactShareIQ

static TLOnPushIQSerializer *IQ_ON_ANSWER_CONTACT_SHARE_SERIALIZER_1;
static const int IQ_ON_ANSWER_CONTACT_SHARE_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_ANSWER_CONTACT_SHARE_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"48245700-ddf2-49b5-991f-300ee7df96a1" schemaVersion:IQ_ON_ANSWER_CONTACT_SHARE_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_ANSWER_CONTACT_SHARE_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ON_ANSWER_CONTACT_SHARE_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ON_ANSWER_CONTACT_SHARE_SERIALIZER_1;
}

@end

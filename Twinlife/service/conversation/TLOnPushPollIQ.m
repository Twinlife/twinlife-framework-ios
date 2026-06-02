/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnPushPollIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnPushPoll IQ.
 *
 * Schema version 1
 *  Date: 2026/03/23
 *
 * <pre>
 * {
 *  "schemaId":"62d16671-6fc5-4b7d-9a35-c36e38b6275c",
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
// Implementation: TLOnPushPollIQ
//

@implementation TLOnPushPollIQ

static TLOnPushIQSerializer *IQ_ON_PUSH_POLL_SERIALIZER_1;
static const int IQ_ON_PUSH_POLL_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_PUSH_POLL_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"62d16671-6fc5-4b7d-9a35-c36e38b6275c" schemaVersion:IQ_ON_PUSH_POLL_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_POLL_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ON_PUSH_POLL_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ON_PUSH_POLL_SERIALIZER_1;
}

@end

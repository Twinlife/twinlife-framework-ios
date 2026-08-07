/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLOnPushContactShareIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnPushPoll IQ.
 *
 * Schema version 1
 *  Date: 2026/03/23
 *
 * <pre>
 * {
 *  "schemaId":"fbb7a421-eef7-456f-b957-9aefce367726",
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
// Implementation: TLOnPushContactShareIQ
//

@implementation TLOnPushContactShareIQ

static TLOnPushIQSerializer *IQ_ON_PUSH_CONTACT_SHARE_SERIALIZER_1;
static const int IQ_ON_PUSH_CONTACT_SHARE_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_PUSH_CONTACT_SHARE_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"fbb7a421-eef7-456f-b957-9aefce367726" schemaVersion:IQ_ON_PUSH_CONTACT_SHARE_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_CONTACT_SHARE_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ON_PUSH_CONTACT_SHARE_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ON_PUSH_CONTACT_SHARE_SERIALIZER_1;
}

@end

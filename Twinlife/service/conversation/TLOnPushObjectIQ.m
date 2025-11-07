/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushObjectIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnPushObject IQ.
 *
 * Schema version 3
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"f95ac4b5-d20f-4e1f-8204-6d146dd5291e",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"OnPushObjectIQ",
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
// Implementation: TLOnPushObjectIQ
//

@implementation TLOnPushObjectIQ

static TLOnPushIQSerializer *IQ_ON_PUSH_OBJECT_SERIALIZER_3;
static const int IQ_ON_PUSH_OBJECT_SCHEMA_VERSION_3 = 3;

+ (void)initialize {
    
    IQ_ON_PUSH_OBJECT_SERIALIZER_3 = [[TLOnPushIQSerializer alloc] initWithSchema:@"f95ac4b5-d20f-4e1f-8204-6d146dd5291e" schemaVersion:IQ_ON_PUSH_OBJECT_SCHEMA_VERSION_3];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_OBJECT_SERIALIZER_3.schemaId;
}

+ (int)SCHEMA_VERSION_3 {

    return IQ_ON_PUSH_OBJECT_SERIALIZER_3.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_3 {
    
    return IQ_ON_PUSH_OBJECT_SERIALIZER_3;
}

@end

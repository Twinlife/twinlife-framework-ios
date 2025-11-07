/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnInviteGroupIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnInviteGroup IQ.
 *
 * Schema version 2
 *  Date: 2024/08/28
 *
 * <pre>
 * {
 *  "schemaId":"afa81c21-beb5-4829-a5d0-8816afda602f",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnInviteGroupIQ",
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
// Implementation: TLOnInviteGroupIQ
//

@implementation TLOnInviteGroupIQ

static TLOnPushIQSerializer *IQ_ON_INVITE_GROUP_SERIALIZER_2;
static const int IQ_ON_INVITE_GROUP_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_INVITE_GROUP_SERIALIZER_2 = [[TLOnPushIQSerializer alloc] initWithSchema:@"afa81c21-beb5-4829-a5d0-8816afda602f" schemaVersion:IQ_ON_INVITE_GROUP_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_INVITE_GROUP_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_INVITE_GROUP_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_ON_INVITE_GROUP_SERIALIZER_2;
}

@end

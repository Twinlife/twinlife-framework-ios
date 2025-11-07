/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushTwincodeIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnPushTwincode IQ.
 *
 * Schema version 2
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"e6726692-8fe6-4d29-ae64-ba321d44a247",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnPushTwincodeIQ",
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
// Implementation: TLOnPushTwincodeIQ
//

@implementation TLOnPushTwincodeIQ

static TLOnPushIQSerializer *IQ_ON_PUSH_TWINCODE_SERIALIZER_2;
static const int IQ_ON_PUSH_TWINCODE_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_PUSH_TWINCODE_SERIALIZER_2 = [[TLOnPushIQSerializer alloc] initWithSchema:@"e6726692-8fe6-4d29-ae64-ba321d44a247" schemaVersion:IQ_ON_PUSH_TWINCODE_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_TWINCODE_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_PUSH_TWINCODE_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_ON_PUSH_TWINCODE_SERIALIZER_2;
}

@end

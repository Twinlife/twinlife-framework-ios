/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushGeolocationIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnPushGeolocation IQ.
 *
 * Schema version 2
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"5fd82b6b-5b7f-42c1-976e-f3addf8c5e16",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnPushGeolocationIQ",
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
// Implementation: TLOnPushGeolocationIQ
//

@implementation TLOnPushGeolocationIQ

static TLOnPushIQSerializer *IQ_ON_PUSH_GEOLOCATION_SERIALIZER_2;
static const int IQ_ON_PUSH_GEOLOCATION_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_PUSH_GEOLOCATION_SERIALIZER_2 = [[TLOnPushIQSerializer alloc] initWithSchema:@"5fd82b6b-5b7f-42c1-976e-f3addf8c5e16" schemaVersion:IQ_ON_PUSH_GEOLOCATION_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_GEOLOCATION_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_PUSH_GEOLOCATION_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_ON_PUSH_GEOLOCATION_SERIALIZER_2;
}

@end

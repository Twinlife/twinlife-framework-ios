/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnUpdateDescriptorIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnUpdateDescriptor IQ.
 *
 * Schema version 1
 *  Date: 2025/05/21
 *
 * <pre>
 * {
 *  "schemaId":"2afd6f3b-1e96-40cd-836e-7644540246b9",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnUpdateDescriptorIQ",
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
// Implementation: TLOnUpdateDescriptorIQ
//

@implementation TLOnUpdateDescriptorIQ

static TLOnPushIQSerializer *IQ_ON_UPDATE_DESCRIPTOR_SERIALIZER_1;
static const int IQ_ON_UPDATE_DESCRIPTOR_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_UPDATE_DESCRIPTOR_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"2afd6f3b-1e96-40cd-836e-7644540246b9" schemaVersion:IQ_ON_UPDATE_DESCRIPTOR_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_UPDATE_DESCRIPTOR_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ON_UPDATE_DESCRIPTOR_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ON_UPDATE_DESCRIPTOR_SERIALIZER_1;
}

@end

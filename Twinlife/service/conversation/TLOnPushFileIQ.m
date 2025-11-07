/*
 *  Copyright (c) 2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnPushFileIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnPushFile IQ.
 * <p>
 * Schema version 2
 *  Date: 2021/04/07
 *
 * <pre>
 * {
 *  "schemaId":"3d4e8b77-bca3-477d-a949-5ec4f36e01a3",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"OnPushFileIQ",
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
// Implementation: TLOnPushFileIQ
//

@implementation TLOnPushFileIQ

static TLOnPushIQSerializer *IQ_ON_PUSH_FILE_SERIALIZER_2;
static const int IQ_ON_PUSH_FILE_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_PUSH_FILE_SERIALIZER_2 = [[TLOnPushIQSerializer alloc] initWithSchema:@"3d4e8b77-bca3-477d-a949-5ec4f36e01a3" schemaVersion:IQ_ON_PUSH_FILE_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_PUSH_FILE_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_PUSH_FILE_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_2 {
    
    return IQ_ON_PUSH_FILE_SERIALIZER_2;
}

@end

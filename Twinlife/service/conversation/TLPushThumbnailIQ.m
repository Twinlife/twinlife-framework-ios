/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLPushThumbnailIQ.h"
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
// Implementation: TLPushThumbnailIQ
//

@implementation TLPushThumbnailIQ

static TLPushFileChunkIQSerializer *IQ_PUSH_THUMBNAIL_SERIALIZER_1;
static const int IQ_PUSH_THUMBNAIL_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_PUSH_THUMBNAIL_SERIALIZER_1 = [[TLPushFileChunkIQSerializer alloc] initWithSchema:@"b4ca7a06-f512-403a-b31f-58e19bf777a0" schemaVersion:IQ_PUSH_THUMBNAIL_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_PUSH_THUMBNAIL_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_PUSH_THUMBNAIL_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_PUSH_THUMBNAIL_SERIALIZER_1;
}

@end

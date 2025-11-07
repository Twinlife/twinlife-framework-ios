/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnUpdateAnnotationsIQ.h"
#import "TLSerializerFactory.h"

/**
 * OnUpdateAnnotation IQ.
 * <p>
 * Schema version 1
 *  Date: 2023/01/10
 *
 * <pre>
 * {
 *  "schemaId":"1db860bd-f84c-48c0-b2dd-17fea1e683bd",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnUpdateAnnotationIQ",
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
// Implementation: TLOnUpdateAnnotationsIQ
//

@implementation TLOnUpdateAnnotationsIQ

static TLOnPushIQSerializer *IQ_ON_UPDATE_ANNOTATIONS_SERIALIZER_1;
static const int IQ_ON_UPDATE_ANNOTATIONS_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_UPDATE_ANNOTATIONS_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"1db860bd-f84c-48c0-b2dd-17fea1e683bd" schemaVersion:IQ_ON_UPDATE_ANNOTATIONS_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_UPDATE_ANNOTATIONS_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ON_UPDATE_ANNOTATIONS_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_ON_UPDATE_ANNOTATIONS_SERIALIZER_1;
}

@end

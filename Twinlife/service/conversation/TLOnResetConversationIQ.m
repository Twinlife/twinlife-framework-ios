/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnResetConversationIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * OnResetConversationIQ IQ.
 *
 * Schema version 3
 *  Date: 2022/02/09
 *
 * <pre>
 * {
 *  "schemaId":"09e855f4-61d9-4acf-92ce-8f93c6951fb0",
 *  "schemaVersion":"3",
 *
 *  "type":"record",
 *  "name":"OnResetConversationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnResetConversationIQ
//

@implementation TLOnResetConversationIQ

static TLOnPushIQSerializer *IQ_ON_RESET_CONVERSATION_SERIALIZER_3;
static const int IQ_ON_RESET_CONVERSATION_SCHEMA_VERSION_3 = 3;

+ (void)initialize {
    
    IQ_ON_RESET_CONVERSATION_SERIALIZER_3 = [[TLOnPushIQSerializer alloc] initWithSchema:@"09e855f4-61d9-4acf-92ce-8f93c6951fb0" schemaVersion:IQ_ON_RESET_CONVERSATION_SCHEMA_VERSION_3];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_RESET_CONVERSATION_SERIALIZER_3.schemaId;
}

+ (int)SCHEMA_VERSION_3 {

    return IQ_ON_RESET_CONVERSATION_SERIALIZER_3.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_3 {
    
    return IQ_ON_RESET_CONVERSATION_SERIALIZER_3;
}

@end

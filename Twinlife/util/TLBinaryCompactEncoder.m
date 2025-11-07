/*
 *  Copyright (c) 2022-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLBinaryCompactEncoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define SERIALIZER_BUFFER_DEFAULT_SIZE 1024

//
// Implementation: TLBinaryCompactEncoder
//

#undef LOG_TAG
#define LOG_TAG @"TLBinaryCompactEncoder"

@implementation TLBinaryCompactEncoder

- (nonnull instancetype)initWithData:(nonnull NSMutableData *)data {

    self = [super initWithData:data];
    
    return self;
}

- (void)writeUUID:(nonnull NSUUID *)value {
    DDLogVerbose(@"%@ writeUUID: %@", LOG_TAG, value);

    uuid_t bytes;
    [value getUUIDBytes:bytes];

    uuid_t swap;
    for (int i = 0; i < 16; i++) {
        swap[i] = bytes[15 - i];
    }

    [self.data appendBytes:swap length:16];
}

+ (nullable NSData *)serializeWithAttributes:(nullable NSArray<TLAttributeNameValue *> *)attributes {
    
    if (!attributes || attributes.count == 0) {
        return nil;
    }

    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:SERIALIZER_BUFFER_DEFAULT_SIZE];
    
    TLBinaryEncoder *binaryEncoder = [[TLBinaryCompactEncoder alloc] initWithData:data];

    [binaryEncoder writeAttributes:attributes];
    return data;
}

@end

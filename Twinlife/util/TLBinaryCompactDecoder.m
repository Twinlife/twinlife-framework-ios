/*
 *  Copyright (c) 2022-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLBinaryCompactDecoder.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLBinaryCompactDecoder
//

#undef LOG_TAG
#define LOG_TAG @"TLBinaryCompactDecoder"

@implementation TLBinaryCompactDecoder

- (nonnull instancetype)initWithData:(nonnull NSMutableData *)data {

    self = [super initWithData:data];
    
    return self;
}

- (nonnull NSUUID *)readUUID {
    DDLogVerbose(@"%@ readUUID", LOG_TAG);

    uuid_t bytes;
    NSUInteger read = self.read + 16;
    if (read > self.length) {
        @throw [NSException exceptionWithName:@"TLDecoderCompactException" reason:nil userInfo:nil];
    }
    [self.data getBytes:bytes range:NSMakeRange(self.read, 16)];
    self.read = read;

    uuid_t swap;
    for (int i = 0; i < 16; i++) {
        swap[i] = bytes[15 - i];
    }

    return [[NSUUID alloc] initWithUUIDBytes:swap];
}

+ (nullable NSMutableArray<TLAttributeNameValue *> *)deserializeWithData:(nullable NSData *)data {
    
    if (!data) {
        return nil;
    }

    TLBinaryCompactDecoder *decoder = [[TLBinaryCompactDecoder alloc] initWithData:data];
    return [decoder readAttributes];
}

@end

/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "NSUUID+Extensions.h"

//
// Implementation: NSUUID (Extensions)
//

@implementation NSUUID (Extensions)

- (int64_t)getLeastSignificantBits {
    
    int64_t leastSignificantBits = 0L;
    uuid_t bytes;
    [self getUUIDBytes:bytes];
    int shift = 56;
    for (int i = 8; i < 16; i++) {
        int64_t lValue = bytes[i];
        leastSignificantBits |= (lValue & 0xFF) << shift;
        shift -= 8;
    }
    return leastSignificantBits;
}

- (int64_t)getMostSignificantBits {
    
    int64_t mostSignificantBits = 0L;
    uuid_t bytes;
    [self getUUIDBytes:bytes];
    int shift = 56;
    for (int i = 0; i < 8; i++) {
        int64_t lValue = bytes[i];
        mostSignificantBits |= (lValue & 0xFF) << shift;
        shift -= 8;
    }
    return mostSignificantBits;
}

- (int)compareTo:(NSUUID *)uuid {
    
    int64_t leastSignificantBits1 = [self getLeastSignificantBits];
    int64_t mostSignificantBits1 = [self getMostSignificantBits];
    int64_t leastSignificantBits2 = [uuid getLeastSignificantBits];
    int64_t mostSignificantBits2 = [uuid getMostSignificantBits];
    return (mostSignificantBits1 < mostSignificantBits2 ? -1 : (mostSignificantBits1 > mostSignificantBits2 ? 1 : (leastSignificantBits1 < leastSignificantBits2 ? -1 : (leastSignificantBits1 > leastSignificantBits2 ? 1 : 0))));
}

- (nonnull NSString*)toString {

    return [[self UUIDString] lowercaseString];
}

+ (nullable NSUUID *)toUUID:(nonnull NSString *)string {
    
    if (string.length == 36) {
        return [[NSUUID alloc] initWithUUIDString:string];
    }

    // iOS does not have a Base64 URL decoding, change - into + and _ into / if they are used.
    if ([string containsString:@"-"]) {
        string = [string stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    }
    if ([string containsString:@"_"]) {
        string = [string stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    }

    // The 16-bytes encoded values are such that we expect two '=' at the end.
    string = [[NSString alloc] initWithFormat:@"%@==", string];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:string options:0];
    if (data.length != 16) {
        return nil;
    }

    uuid_t bytes;
    [data getBytes:bytes range:NSMakeRange(0, 16)];
    return [[NSUUID alloc] initWithUUIDBytes:bytes];
}

+ (nonnull NSString *)fromUUID:(nonnull NSUUID *)value {

    uuid_t bytes;
    [value getUUIDBytes:bytes];
    NSData* data = [[NSData alloc] initWithBytes:bytes length:16];

    NSString *result = [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];

    // Due to the 16-bytes encoded value, we get two '=' at the end and we want to remove them.
    result = [result substringToIndex:result.length - 2];

    // iOS does not have a Base64 URL encoding, change + into - and / into _ if they are used.
    if ([result containsString:@"+"]) {
        result = [result stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    }
    if ([result containsString:@"/"]) {
        result = [result stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    }
    return result;
}

@end

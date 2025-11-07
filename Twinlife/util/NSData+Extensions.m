/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "NSData+Extensions.h"

//
// Implementation: NSData (Extensions)
//

@implementation NSData (Extensions)

+ (nullable NSData *)secureRandomWithLength:(int)length {

    void *secretData = malloc(length);
    if (!secretData) {
        return nil;
    }

    int result = SecRandomCopyBytes(kSecRandomDefault, length, secretData);
    if (result != errSecSuccess) {
        free(secretData);
        return nil;
    }

    return [[NSData alloc] initWithBytesNoCopy:secretData length:length];
}

@end

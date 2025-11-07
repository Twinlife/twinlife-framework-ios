/*
 *  Copyright (c) 2017, 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "NSURL+Extensions.h"

//
// Implementation: NSUUID (Extensions)
//

@implementation NSURL (Extensions)


- (nullable NSString *)queryParamWithName:(nonnull NSString *)name {
    NSArray *queryItems = [[[NSURLComponents alloc] initWithURL:self resolvingAgainstBaseURL:NO] queryItems];
    for (NSURLQueryItem *queryItem in queryItems) {
        if ([name isEqualToString: queryItem.name]) {
            return queryItem.value;
        }
    }
    return nil;
}

@end

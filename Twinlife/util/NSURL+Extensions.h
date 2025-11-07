/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface: NSURL (Extensions)
//

@interface NSURL (Extensions)

- (nullable NSString *)queryParamWithName:(nonnull NSString *)name;

@end

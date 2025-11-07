/*
 *  Copyright (c) 2017 - 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

//
// Interface: NSUUID (Extensions)
//

@interface NSUUID (Extensions)

- (int64_t)getLeastSignificantBits;

- (int64_t)getMostSignificantBits;

- (int)compareTo:(nonnull NSUUID *)uuid;

/// Get a printable representation of the UUID compatible with Android to be used for the database (lower-case UUID).
- (nonnull NSString*)toString;

+ (nullable NSUUID *)toUUID:(nonnull NSString *)string;

+ (nonnull NSString *)fromUUID:(nonnull NSUUID *)value;

@end

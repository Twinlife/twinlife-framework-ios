/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLVersion
//

@interface TLVersion : NSObject

@property (readonly) int major;
@property (readonly) int minor;
@property (readonly) int patch;

- (nonnull instancetype)initWithMajor:(int)major minor:(int)minor patch:(int)patch;

/// Create a version object splitting the string into major, minor and patch components.
- (nonnull instancetype)initWithVersion:(nonnull NSString *)version;

/// Compare two versions.
- (NSComparisonResult)compareWithOperationQueue:(nonnull TLVersion *)version;

@end

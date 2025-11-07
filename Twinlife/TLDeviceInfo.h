/*
 *  Copyright (c) 2019-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// TLDeviceInfo
//

@interface TLDeviceInfo : NSObject

@property (readonly) int64_t foregroundTime;
@property (readonly) int64_t backgroundTime;
@property (readonly) long alarmCount;
@property (readonly) long networkLockCount;
@property (readonly) long pushCount;
@property (readonly) float batteryLevel;
@property (readonly) BOOL charging;
@property (readonly) BOOL allowNotifications;

- (BOOL)isLowPowerModeEnabled;

- (nonnull instancetype)initWithForegroundTime:(int64_t)foregroundTime backgroundTime:(int64_t)backgroundTime pushCount:(int)pushCount alarmCount:(int)alarmCount networkLockCount:(int)networkLockCount allowNotifications:(BOOL)allowNotifications;

@end


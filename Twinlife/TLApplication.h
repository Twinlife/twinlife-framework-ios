/*
 *  Copyright (c) 2020-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Protocol: TLApplication
//

@protocol TLApplication

- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithExpirationHandler:(nonnull void (^)(void))block;

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier;

- (NSTimeInterval)backgroundTimeRemaining;

- (BOOL)allowNotifications;

@end

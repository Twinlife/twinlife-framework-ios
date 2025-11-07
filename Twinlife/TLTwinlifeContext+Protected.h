/*
 *  Copyright (c) 2015-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLTwinlifeContext (Protected)
//

@interface TLTwinlifeContext (Protected)

- (void)onTwinlifeReady;

- (void)onTwinlifeOnline;

- (void)onTwinlifeOffline;

- (void)onNetworkConnect;

- (void)onNetworkDisconnect;

- (void)onConnect;

- (void)onDisconnect;

- (void)onSignIn;

- (void)onSignInErrorWithErrorCode:(TLBaseServiceErrorCode)errorCode;

- (void)onSignOut;

@end

/*
 *  Copyright (c) 2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

//
// Interface: TLGroupProtocol
//

@interface TLGroupProtocol : NSObject

+ (nonnull NSString *)invokeTwincodeActionGroupSubscribe;

+ (nonnull NSString *)invokeTwincodeActionGroupRegistered;

+ (nonnull NSString *)invokeTwincodeActionAdminPermissions;

+ (nonnull NSString *)invokeTwincodeActionMemberPermissions;

+ (nonnull NSString *)invokeTwincodeActionAdminTwincodeId;

+ (void) setInvokeTwincodeActionGroupSubscribeMemberTwincodeId:(nonnull NSMutableArray *)attributes memberTwincodeId:(nonnull NSUUID *)memberTwincodeId;

@end

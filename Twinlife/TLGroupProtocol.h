/*
 *  Copyright (c) 2019-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLRosterId;
@class TLTwincodeOutbound;
@class TLAttributeNameValue;

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

// The ROSTER_SCHEMA_ID is the new schema ID used for groups after 2026-04-16.  Every member
// in the secure roster must have a public key.
+ (nonnull NSUUID *)ROSTER_SCHEMA_ID;

// The LEGACY_SCHEMA_ID was used by groups that were created without a secure roster.  This group
// allows to have members in the secure roster that have an empty public key.
+ (nonnull NSUUID *)LEGACY_SCHEMA_ID;

+ (nonnull NSString *)ACTION_ROSTER_UPDATE;

+ (nonnull NSString *)ACTION_ROSTER_LEAVE;

/// Get the secure roster ID associated with the group. For a legacy group, there is no secure roster ID.
/// @return null or the secure roster ID.
+ (nullable TLRosterId *)getSecureRosterIdWithTwincode:(nullable TLTwincodeOutbound *)twincode;

+ (void)setSecureRosterId:(nonnull NSMutableArray<TLAttributeNameValue *> *)attributes rosterId:(nonnull TLRosterId *)rosterId;

@end

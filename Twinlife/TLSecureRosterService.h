/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

@class TLPublicKeyData;
@class TLTwincodeOutbound;
@protocol TLGroupConversation;

//
// Constants
//

FOUNDATION_EXPORT const int TLSecureRosterServiceAllowEmptyKey;

//
// Interface: TLRosterId
//

/**
 * A roster identifier with its ID and schema ID.
 */
@interface TLRosterId : NSObject

@property (readonly, nonnull) NSUUID *rosterId;
@property (readonly, nonnull) NSUUID *schemaId;

- (nonnull instancetype)initWithId:(nonnull NSUUID *)rosterId schemaId:(nonnull NSUUID *)schemaId;

- (nonnull instancetype)initWithValue:(nonnull NSString *)value;

@end

//
// Interface: TLMemberIdentity
//

/**
 * Member to add to a secure roster.
 */
@interface TLMemberIdentity : NSObject

@property (readonly, nonnull) NSUUID *memberTwincodeId;
@property (readonly) int64_t memberPermission;
@property (readonly, nonnull) NSData *memberPublicKey;

- (nonnull instancetype)initWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId
                                memberPermission:(int64_t)memberPermission
                               memberPublicKey:(nonnull NSData *)memberPublicKey;

@end

//
// Interface: TLRosterMember
//

/**
 * A roster member with its twincode, permission and public key.
 */
@interface TLRosterMember : NSObject

@property (readonly, nonnull) NSUUID *memberTwincodeId;
@property (readonly) int64_t permissions;
@property (readonly, nonnull) TLPublicKeyData *publicKey;
@property (readonly, nonnull) NSData *signature;
@property (readonly) int64_t creationDate;
@property (readonly) int64_t modificationDate;
@property (assign) BOOL verified;

- (nonnull instancetype)initWithMemberTwincodeId:(nonnull NSUUID *)memberTwincodeId
                              creationDate:(int64_t)creationDate
                         modificationDate:(int64_t)modificationDate
                               permissions:(int64_t)permissions
                                publicKey:(nonnull TLPublicKeyData *)publicKey
                                signature:(nonnull NSData *)signature;

/// Check if the member has the given permission.
/// @param permission the permission to check.
/// @return true if the member has the given permission.
- (BOOL)hasPermission:(int64_t)permission;

@end

//
// Interface: TLSignedRosterGroup
//

/**
 * Group of members signed by the same public key.
 */
@interface TLSignedRosterGroup : NSObject

@property (readonly, nonnull) NSUUID *keyId;
@property (readonly, nonnull) TLPublicKeyData *publicKey;
@property (readonly, nonnull) NSData *signature;
@property (readonly, nonnull) NSUUID *signingKeyId;
@property (readonly, nonnull) NSArray<TLRosterMember *> *members;
@property (assign) BOOL verified;

- (nonnull instancetype)initWithKeyId:(nonnull NSUUID *)keyId
                     signingKeyId:(nonnull NSUUID *)signingKeyId
                      publicKey:(nonnull TLPublicKeyData *)publicKey
                       signature:(nonnull NSData *)signature
                        members:(nonnull NSArray<TLRosterMember *> *)members;


@end

//
// Interface: TLSecureRoster
//

@interface TLSecureRoster : NSObject

@property (readonly, nonnull) TLRosterId *rosterId;
@property (readonly) int maxMemberCount;
@property (readonly, nonnull) NSArray<TLSignedRosterGroup *> *groups;

- (nonnull instancetype)initWithRosterId:(nonnull TLRosterId *)rosterId maxMemberCount:(int)maxMemberCount groups:(nonnull NSArray<TLSignedRosterGroup *> *)groups;

@end

//
// Interface: TLSecureRosterServiceConfiguration
//

/**
 * Secure Roster service configuration.
 */
@interface TLSecureRosterServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Interface: TLSecureRosterService
//

/**
 * Secure Roster service is used for groups and community spaces to represent members.
 *
 * - the secure roster is protected by a list of public keys which are used to sign other public keys or members,
 * - a secure roster key is protected by signing '{rosterId, keyId, publicKeyId}',
 * - the first secure roster key is signed by itself and the keyId is specified at the creation,
 * - each member are protected by signing '{rosterId, memberTwincodeId, memberPermission, publicKey}'
 * - a member is valid only when a valid secure roster key exists and verifies the member's signature.
 *   The device must enforce this rule (to make sure the server does not add spying members).
 *   The server also verifies this rule before insertion.
 */
@interface TLSecureRosterService : TLBaseService

+ (nonnull NSString *)VERSION;

/// Create a secure roster with the configuration options and the given roster schema id which
/// indicates the target purpose of the secure roster.
/// Note: the public key is saved but it is not validated, hence it cannot accept new members.
/// The public key must be updated by using setRosterPublicKey().
/// @param createOptions the secure roster create options.
/// @param rosterSchemaId the secure roster schema ID.
/// @param publicKeyId the root public key ID.
/// @param publicKey the root public key (Ed25519).
/// @param complete the completion handler executed when the operation completes.
- (void)createRosterWithCreateOptions:(int)createOptions
                        rosterSchemaId:(nonnull NSUUID *)rosterSchemaId
                           publicKeyId:(nonnull NSUUID *)publicKeyId
                           publicKey:(nonnull TLPublicKeyData *)publicKey
                             complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLRosterId * _Nullable rosterId))complete;

- (void)createRosterWithCreateOptions:(int)createOptions
                        rosterSchemaId:(nonnull NSUUID *)rosterSchemaId
                     signingTwincode:(nonnull TLTwincodeOutbound *)signingTwincode
                             complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLRosterId * _Nullable rosterId))complete;

/// List the secure roster members and public keys used to protect them.  Members are grouped
/// per signing public key to help in the verification.  Public keys are ordered so that its
/// signing key has always a lower index.  The first key is self signed.  It is assumed that
/// the caller trusts that first key (and it must therefore verify that it matches the trusted key).
/// This operation is accepted if:
/// - the device has created the secure roster,
/// - the device is member of the secure roster.
/// @param rosterId the secure roster ID and roster schema ID.
/// @param afterCreationTime list only secure roster members created after the given timestamp.
/// @param complete the completion handler executed when the operation completes.
- (void)listRosterWithRosterId:(nonnull TLRosterId *)rosterId
                     afterCreationTime:(int64_t)afterCreationTime
                             complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode, TLSecureRoster * _Nullable keys))complete;

/// Add or update a member in the secure roster.  The new member is signed by using the private
/// key associated with the twincode.  We assume that the caller trusts the new member's public
/// key.  This operation is accepted by the server if:
/// - the device has created the secure roster,
/// - the device is member of the secure roster AND the public key was registered,
/// - the device member has the Permission.ADD_MEMBER.
/// @param rosterId the secure roster ID and roster schema ID.
/// @param signingMember the twincode identifying the private key to sign the new member.
/// @param newMemberTwincodeId the new member twincode ID.
/// @param newMemberPermission the new member permission.
/// @param newMemberPublicKey the new member public key.
/// @param complete the completion handler executed when the operation completes.
- (void)addMemberWithRosterId:(nonnull TLRosterId *)rosterId
                    signingMember:(nonnull TLTwincodeOutbound *)signingMember
               newMemberTwincodeId:(nonnull NSUUID *)newMemberTwincodeId
              newMemberPermission:(int64_t)newMemberPermission
               newMemberPublicKey:(nonnull TLPublicKeyData *)newMemberPublicKey
                          complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

- (void)addMemberWithRosterId:(nonnull TLRosterId *)rosterId
                    signingMember:(nonnull TLTwincodeOutbound *)signingMember
               newMemberTwincode:(nonnull TLTwincodeOutbound *)newMemberTwincode
              newMemberPermission:(int64_t)newMemberPermission
                          complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

- (void)addMembersWithRosterId:(nonnull TLRosterId *)rosterId
                     signingMember:(nonnull TLTwincodeOutbound *)signingMember
             groupConversation:(nonnull id<TLGroupConversation>)groupConversation
                          complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

/// Update the member permissions in the secure roster.
- (void)updateMembersWithRosterId:(nonnull TLRosterId *)rosterId signingMember:(nonnull TLTwincodeOutbound *)signingMember members:(nonnull NSArray<TLMemberIdentity *> *)members complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

/// Remove a member from the secure roster. This operation is accepted by the server if:
/// - the device has created the secure roster,
/// - the device is member of the secure roster,
/// - the device member has the Permission.DELETE_MEMBER.
/// @param rosterId the secure roster ID.
/// @param memberId the member twincode ID to remove.
/// @param complete the completion handler executed when the operation completes.
- (void)deleteMemberWithRosterId:(nonnull NSUUID *)rosterId
                         memberId:(nonnull NSUUID *)memberId
                         complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

/// Set the secure roster public key signed by the given twincode private key.
/// This operation is accepted by the server if:
/// - the device has created the secure roster,
/// - the device is member of the secure roster,
/// - the device member has the Permission.ADD_PUBLIC_KEY,
/// - the provided signature to add the new public key is valid,
/// - the public key matches exactly what the server knows.
/// @param rosterId the secure roster ID and roster schema ID.
/// @param signingMember the twincode identifying the private key to sign the new public key.
/// @param newKeyId the key ID to sign.
/// @param newPublicKey the public key to sign.
/// @param complete the completion handler executed when the operation completes.
- (void)setRosterPublicKeyWithRosterId:(nonnull TLRosterId *)rosterId
                        signingMember:(nonnull TLTwincodeOutbound *)signingMember
                              newKeyId:(nonnull NSUUID *)newKeyId
                         newPublicKey:(nonnull TLPublicKeyData *)newPublicKey
                             complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

- (void)setRosterPublicKeyWithRosterId:(nonnull TLRosterId *)rosterId
                        signingMember:(nonnull TLTwincodeOutbound *)signingMember
                    newSigningTwincode:(nonnull TLTwincodeOutbound *)newSigningTwincode
                             complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

/// Delete the secure roster if the user is member and owner of the secure roster.
/// @param rosterId the secure roster ID.
/// @param complete the completion handler executed when the operation completes.
- (void)deleteRosterWithRosterId:(nonnull TLRosterId *)rosterId
                             complete:(nonnull void (^)(TLBaseServiceErrorCode errorCode))complete;

@end

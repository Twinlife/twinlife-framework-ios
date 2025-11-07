/*
 *  Copyright (c) 2015-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Shiyi Gu (Shiyi.Gu@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

typedef enum {
    NOT_USED,
    TWINCODE_FACTORY,
    TWINCODE_INBOUND,
    TWINCODE_OUTBOUND,
    TWINCODE_SWITCH
} TLTwincodeFacet;

#define TL_TWINCODE_NAME         @"name"
#define TL_TWINCODE_DESCRIPTION  @"description"
#define TL_TWINCODE_AVATAR_ID    @"avatarId"
#define TL_TWINCODE_CAPABILITIES @"capabilities"

typedef NS_ENUM(NSUInteger, TLTrustMethod) {
    TLTrustMethodNone,              // No public key or not trusted.
    TLTrustMethodOwner,             // We are owner of the public key.
    TLTrustMethodQrCode,            // Public key was received by scanning a QR-code
    TLTrustMethodLink,              // Public key was received from an external link and the application was launched to handle it.
    TLTrustMethodVideo,             // Public key was validated with the authenticate video protocol.
    TLTrustMethodAuto,              // Public key received through P2P data channel from the P2P exchange public key protocol.
    TLTrustMethodPeer,              // Public key was received through P2P data channel
    TLTrustMethodInvitationCode,    // Public key was received from the server while adding the contact using a temporary invitation code.
};

//
// TLTwincode
//

@class TLAttributeNameValue;

@interface TLTwincode : NSObject

@property (nonnull, readonly) NSUUID *uuid;

- (nullable id)getAttributeWithName:(nonnull NSString *)name;

- (BOOL)hasAttributeWithName:(nonnull NSString *)name;

- (TLTwincodeFacet)getFacet;

- (BOOL)isTwincodeFactory;

- (BOOL)isTwincodeInbound;

- (BOOL)isTwincodeOutbound;

- (BOOL)isTwincodeSwitch;

+ (nonnull NSUUID *)NOT_DEFINED;

@end

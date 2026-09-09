/*
 *  Copyright (c) 2015-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

typedef enum {
    TLPermissionTypeNone = -1,
    TLPermissionTypeInviteMember = 0,
    TLPermissionTypeUpdateMember = 1,
    TLPermissionTypeRemoveMember = 2,
    TLPermissionTypeSendMessage  = 3,
    TLPermissionTypeSendImage    = 4,
    TLPermissionTypeSendAudio    = 5,
    TLPermissionTypeSendVideo    = 6,
    TLPermissionTypeSendFile     = 7,
    TLPermissionTypeDeleteMessage= 8,
    TLPermissionTypeDeleteImage  = 9,
    TLPermissionTypeDeleteAudio  = 10,
    TLPermissionTypeDeleteVideo  = 11,
    TLPermissionTypeDeleteFile   = 12,
    TLPermissionTypeResetConversation= 13,
    TLPermissionTypeSendGeolocation= 14,
    TLPermissionTypeSendTwincode = 15,
    TLPermissionTypeReceiveMessage = 16,
    TLPermissionTypeSendCommand = 17,
    TLPermissionTypeAddPublicKey = 18
} TLPermissionType;

#define TL_PERMISSION_MASK(FROM,TO)                     ((1L << (TO + 1)) - 1L) & (-(1L << FROM))
#define TL_ALL_PERMISSIONS                              (TL_PERMISSION_MASK(0, 18))
#define TL_RESTRICT_PERMISSIONS(PERMISSIONS, RESTRICT)  ((PERMISSIONS) & (RESTRICT))
#define TL_MANAGE_MEMBER_PERMISSIONS                    (TL_PERMISSION_MASK(0, 2))
#define TL_ALLOW_POST_PERMISSIONS                       (TL_PERMISSION_MASK(3, 7) | (1L << TLPermissionTypeSendGeolocation))
#define TL_ALLOW_DELETE_PERMISSIONS                     (TL_PERMISSION_MASK(8, 12))
#define TL_ADMIN_PERMISSIONS                            (TL_MANAGE_MEMBER_PERMISSIONS | (1L << TLPermissionTypeAddPublicKey))

//
// Interface: TLPermissions
//
@interface TLPermissions : NSObject

+ (BOOL)hasPermission:(TLPermissionType)kind permissions:(int64_t)permissions;

+ (int64_t)removePermission:(TLPermissionType)kind permissions:(int64_t)permissions;

@end

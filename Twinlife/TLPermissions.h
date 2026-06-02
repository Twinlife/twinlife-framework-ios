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
    TLPermissionTypeSendMessage,
    TLPermissionTypeSendImage,
    TLPermissionTypeSendAudio,
    TLPermissionTypeSendVideo,
    TLPermissionTypeSendFile,
    TLPermissionTypeDeleteMessage,
    TLPermissionTypeDeleteImage,
    TLPermissionTypeDeleteAudio,
    TLPermissionTypeDeleteVideo,
    TLPermissionTypeDeleteFile,
    TLPermissionTypeResetConversation,
    TLPermissionTypeSendGeolocation,
    TLPermissionTypeSendTwincode,
    TLPermissionTypeReceiveMessage,
    TLPermissionTypeSendCommand
} TLPermissionType;

#define TL_PERMISSION_MASK(FROM,TO)                     ((1L << (TO + 1)) - 1L) & (-(1L << FROM))
#define TL_ALL_PERMISSIONS                              (TL_PERMISSION_MASK(0, 18))
#define TL_RESTRICT_PERMISSIONS(PERMISSIONS, RESTRICT)  ((PERMISSIONS) & (RESTRICT))

//
// Interface: TLPermissions
//
@interface TLPermissions : NSObject

+ (BOOL)hasPermission:(TLPermissionType)kind permissions:(int64_t)permissions;

+ (int64_t)removePermission:(TLPermissionType)kind permissions:(int64_t)permissions;

@end

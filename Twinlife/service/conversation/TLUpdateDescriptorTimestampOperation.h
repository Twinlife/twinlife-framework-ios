/*
 *  Copyright (c) 2017-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
*/

#import "TLConversationServiceOperation.h"

//
// Interface: TLUpdateDescriptorTimestampOperation
//

typedef enum {
    TLUpdateDescriptorTimestampTypeRead,
    TLUpdateDescriptorTimestampTypeDelete,
    TLUpdateDescriptorTimestampTypePeerDelete
} TLUpdateDescriptorTimestampType;

@class TLDescriptorId;

@interface TLUpdateDescriptorTimestampOperation : TLConversationServiceOperation

@property (readonly) TLUpdateDescriptorTimestampType timestampType;
@property (readonly, nonnull) TLDescriptorId *updateDescriptorId;
@property (readonly) int64_t descriptorTimestamp;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

/// Serialize the specific part of the operation (used for the V20 migration).
+ (nullable NSData *)serializeOperation:(TLUpdateDescriptorTimestampType)timestampType timestamp:(int64_t)timestamp descriptorId:(nonnull TLDescriptorId *)descriptorId;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation timestampType:(TLUpdateDescriptorTimestampType)timestampType descriptorId:(nonnull TLDescriptorId *)descriptorId timestamp:(int64_t)timestamp;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content;

@end

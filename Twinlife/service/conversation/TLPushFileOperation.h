/*
 *  Copyright (c) 2016-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"

static int PUSH_FILE_OPERATION_NOT_INITIALIZED = -1;

//
// Interface: TLPushFileOperation
//

@class TLFileDescriptor;
@class TLDescriptorId;
@class TLDatabaseIdentifier;

@interface TLPushFileOperation : TLConversationServiceOperation

@property (nonatomic, setter=setChunkStart:) int64_t chunkStart;
@property (nullable) TLFileDescriptor *fileDescriptor;
@property int64_t sentOffset;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (int)NOT_INITIALIZED;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation fileDescriptor:(nonnull TLFileDescriptor *)fileDescriptor;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId chunkStart:(int64_t)chunkStart;

/// Check if we can send more data chunk.
- (BOOL)isReadyToSend:(int64_t)length;

@end

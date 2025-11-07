/*
 *  Copyright (c) 2016-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLConversationServiceOperation.h"
#import "TLConversationService.h"

@class TLResetConversationOperation;
@class TLDatabaseIdentifier;

//
// Interface: TLResetConversationOperationSerializer_4
//

@interface TLResetConversationOperationSerializer_4 : NSObject

+ (nullable TLResetConversationOperation *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder conversationId:(nonnull TLDatabaseIdentifier *)conversationId;

@end

//
// Interface: TLResetConversationOperationSerializer_3
//

@interface TLResetConversationOperationSerializer_3 : NSObject

+ (nullable TLResetConversationOperation *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder conversationId:(nonnull TLDatabaseIdentifier *)conversationId;

@end

//
// Interface: TLResetConversationOperationSerializer_2
//

@interface TLResetConversationOperationSerializer_2 : NSObject

+ (nullable TLResetConversationOperation *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder conversationId:(nonnull TLDatabaseIdentifier *)conversationId;

@end

//
// Interface: TLResetConversationOperation
//

@interface TLResetConversationOperation : TLConversationServiceOperation

@property (readonly) int64_t minSequenceId;
@property (readonly) int64_t peerMinSequenceId;
@property (readonly) int64_t clearTimestamp;
@property (readonly) int64_t createdTimestamp;
@property (readonly) TLConversationServiceClearMode clearMode;
@property (readonly, nullable) NSArray<TLDescriptorId*> *resetMembers;
@property (nullable) TLClearDescriptor *clearDescriptor;
@property (nullable) TLDescriptorId *descriptorId;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_4;

+ (int)SCHEMA_VERSION_3;

+ (int)SCHEMA_VERSION_2;

- (nonnull instancetype)initWithConversation:(nonnull TLConversationImpl *)conversation clearDescriptor:(nullable TLClearDescriptor *)clearDescriptor minSequenceId:(int64_t)minSequenceId peerMinSequenceId:(int64_t)peerMinSequenceId resetMembers:(nullable NSMutableArray<TLDescriptorId*> *)resetMembers clearTimestamp:(int64_t)clearTimestamp clearMode:(TLConversationServiceClearMode)clearMode;

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate descriptorId:(int64_t)descriptorId content:(nullable NSData *)content;

- (int64_t)getCreatedTimestamp;


@end

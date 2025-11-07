/*
 *  Copyright (c) 2016-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSynchronizeConversationOperation.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

//
// Implementation: TLSynchronizeConversationOperation
//

@implementation TLSynchronizeConversationOperation

- (instancetype)initWithConversation:(TLConversationImpl *)conversation {
    
    return [super initWithConversation:conversation type:TLConversationServiceOperationTypeSynchronizeConversation descriptor:nil];
}

- (nonnull instancetype)initWithId:(int64_t)id conversationId:(nonnull TLDatabaseIdentifier *)conversationId creationDate:(int64_t)creationDate {
    
    return [super initWithId:id type:TLConversationServiceOperationTypeSynchronizeConversation conversationId:conversationId creationDate:creationDate descriptorId:0];
}

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLSynchronizeConversationOperation\n"];
    [self appendTo:string];
    return string;
}

@end

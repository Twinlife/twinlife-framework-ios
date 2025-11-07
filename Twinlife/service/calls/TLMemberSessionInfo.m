/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLMemberSessionInfo.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

//
// Implementation: TLMemberSessionInfo
//

@implementation TLMemberSessionInfo

- (nonnull instancetype)initWithMemberId:(nonnull NSString *)memberId sessionId:(nullable NSUUID *)sessionId {

    self = [super init];
    
    if (self) {
        _memberId = memberId;
        _sessionId = sessionId;
    }
    return self;
}

+ (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder members:(nullable NSArray<TLMemberSessionInfo *> *)members {
    
    if (!members) {
        [encoder writeInt:0];
    } else {
        [encoder writeInt:(int)members.count];
        for (TLMemberSessionInfo *member in members) {
            [encoder writeString:member.memberId];
            [encoder writeOptionalUUID:member.sessionId];
        }
    }
}

+ (nullable NSArray<TLMemberSessionInfo *> *)deserializeWithDecoder:(nonnull id<TLDecoder>)decoder {
    
    int count = [decoder readInt];
    if (count == 0) {
        return nil;
    }

    NSMutableArray<TLMemberSessionInfo*> *result = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSString *memberId = [decoder readString];
        NSUUID *sessionId = [decoder readOptionalUUID];
        
        [result addObject:[[TLMemberSessionInfo alloc] initWithMemberId:memberId sessionId:sessionId]];
    }
    
    return result;
}

@end

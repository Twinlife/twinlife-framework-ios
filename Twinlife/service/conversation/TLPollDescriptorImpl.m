/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLPollDescriptorImpl.h"
#import "TLConversationService.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLPollDescriptor
//
@interface TLPollDescriptor ()

+ (nonnull NSArray<TLChoice *> *)sortChoiceArray:(nonnull NSArray<TLChoice *> *)array;

@end


//
// Implementation: TLChoice
//
@implementation TLChoice

- (nonnull instancetype)initWithPosition:(int)position label:(nonnull NSString *)label {
    self = [super init];
    
    if (self) {
        _position = position;
        _label = label;
    }
    
    return self;
}

- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[TLChoice class]]) {
        return NO;
    }
    
    TLChoice *choice = (TLChoice *)object;
    return self.position == choice.position && [self.label isEqualToString:choice.label];
}

+ (nonnull NSArray<TLChoice *> *)fromAnnotationValueWithValue:(int64_t)value choices:(nonnull NSArray<TLChoice *> *)choices {
    NSMutableArray<TLChoice *> *result = [NSMutableArray array];
    
    for (TLChoice *choice in choices) {
        if ((value & (1L << choice.position)) != 0) {
            [result addObject:choice];
        }
    }
    
    return [TLPollDescriptor sortChoiceArray:result];
}

+ (int64_t)toAnnotationValueWithChoices:(nonnull NSArray<TLChoice *> *)choices {
    int64_t result = 0;
    
    for (TLChoice *choice in choices) {
        result |= 1L << choice.position;
    }
    
    return result;
}



@end

//
// Implementation: TLPollDescriptor
//

#undef LOG_TAG
#define LOG_TAG @"TLPollDescriptor"

@implementation TLPollDescriptor

- (TLDescriptorType)getType {
    
    return TLDescriptorTypePollDescriptor;
}

#pragma mark - NSObject

- (NSString *)description {
    
    NSMutableString* string = [NSMutableString stringWithCapacity:1024];
    [string appendString:@"TLPollDescriptor\n"];
    [self appendTo:string];
    return string;
}

#pragma mark - TLDescriptor ()

- (void)appendTo:(NSMutableString*)string {
    
    [super appendTo:string];
    
    [string appendFormat:@" multipleChoicesAllowed: %@ question: %@ choices:%@\n", self.multipleChoicesAllowed ? @"YES" : @"NO", self.question, self.choices];
}

#pragma mark - TLPollDescriptor ()


- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId expireTimeout:(int64_t)expireTimeout multipleChoicesAllowed:(BOOL)multipleChoicesAllowed question:(nonnull NSString *)question choices:(nonnull NSArray<TLChoice *> *)choices copyAllowed:(BOOL)copyAllowed {
    
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil expireTimeout:expireTimeout];
    
    if (self) {
        _multipleChoicesAllowed = multipleChoicesAllowed;
        _copyAllowed = copyAllowed;
        _question = question;
        _choices = [TLPollDescriptor sortChoiceArray:choices];
    }
    
    return self;
}

- (nonnull instancetype)initWithDescriptorId:(nonnull TLDescriptorId *)descriptorId conversationId:(int64_t)conversationId creationDate:(int64_t)creationDate sendDate:(int64_t)sendDate receiveDate:(int64_t)receiveDate readDate:(int64_t)readDate updateDate:(int64_t)updateDate peerDeleteDate:(int64_t)peerDeleteDate deleteDate:(int64_t)deleteDate expireTimeout:(int64_t)expireTimeout flags:(int)flags content:(nonnull NSString *)content {
    self = [super initWithDescriptorId:descriptorId conversationId:conversationId sendTo:nil replyTo:nil creationDate:creationDate sendDate:sendDate receiveDate:receiveDate readDate:readDate updateDate:updateDate peerDeleteDate:peerDeleteDate deleteDate:deleteDate expireTimeout:expireTimeout];
    
    if (self) {
        _multipleChoicesAllowed = (flags & DESCRIPTOR_FLAG_MULTIPLE_CHOICES) != 0;
        _copyAllowed = (flags & DESCRIPTOR_FLAG_COPY_ALLOWED) != 0;
        
        NSArray<NSString *> *args = [TLDescriptor extractWithContent:content];
        
        _question = [TLDescriptor extractStringWithArgs:args position:0 defaultValue:@""];
        
        int nbChoices = (int)[TLDescriptor extractLongWithArgs:args position:1 defaultValue:0];
        NSMutableArray<TLChoice *> *extractedChoices = [NSMutableArray arrayWithCapacity:nbChoices];
        
        int currentIndex = 2;
        
        for (int i = 0; i < nbChoices; i++) {
            if (currentIndex + 1 >= args.count) {
                DDLogError(@"%@ Truncated/malformed poll choices in content string: %@", LOG_TAG, content);
                break;
            }
            int position = (int)[TLDescriptor extractLongWithArgs:args position:currentIndex defaultValue:0];
            NSString *label = [TLDescriptor extractStringWithArgs:args position:currentIndex+1 defaultValue:@""];
            [extractedChoices addObject:[[TLChoice alloc] initWithPosition:position label:label]];
            currentIndex += 2;
        }
                
        _choices = [TLPollDescriptor sortChoiceArray:extractedChoices];
    }
    
    return self;
}

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId expireTimeout:(int64_t)expireTimeout sendTo:(nullable NSUUID *)sendTo createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp multipleChoicesAllowed:(BOOL)multipleChoicesAllowed question:(nonnull NSString *)question choices:(nonnull NSArray<TLChoice *> *)choices copyAllowed:(BOOL)copyAllowed{

    self = [super initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId sendTo:sendTo replyTo:nil expireTimeout:expireTimeout createdTimestamp:createdTimestamp sentTimestamp:sentTimestamp];
    
    if (self) {
        _multipleChoicesAllowed = multipleChoicesAllowed;
        _copyAllowed = copyAllowed;
        _question = question;
        _choices = [TLPollDescriptor sortChoiceArray:choices];
    }
    
    return self;
}

- (nonnull NSDictionary<NSUUID *, NSArray<TLChoice *> *> *)getVotes {
    NSMutableDictionary<NSUUID *, NSMutableArray<TLChoice *> *> *votes = [NSMutableDictionary dictionary];
    
    for (NSUUID *twincodeOutboundId in self.annotations) {
        for (TLDescriptorAnnotation *annotation in self.annotations[twincodeOutboundId]) {
            if (annotation.type == TLDescriptorAnnotationTypePoll) {
                votes[twincodeOutboundId] = [NSMutableArray arrayWithArray:[TLChoice fromAnnotationValueWithValue:annotation.value choices:self.choices]];
            }
        }
    }
    
    return votes;
}

- (nullable NSString *)serialize {
    DDLogVerbose(@"%@ serialize", LOG_TAG);

    NSMutableString *result = [NSMutableString string];
    [result appendString:self.question];
    [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
    [result appendString:[NSNumber numberWithLong:self.choices.count].stringValue];
    
    for (TLChoice *choice in self.choices) {
        [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
        [result appendString:[NSNumber numberWithInt:choice.position].stringValue];
        [result appendString:DESCRIPTOR_FIELD_SEPARATOR];
        [result appendString:choice.label];
    }
    
    return result;
}


- (int)flags {
    int flags = self.multipleChoicesAllowed ? DESCRIPTOR_FLAG_MULTIPLE_CHOICES : 0;
    flags |= self.copyAllowed ? DESCRIPTOR_FLAG_COPY_ALLOWED : 0;
    return flags;
}

- (void)markEdited {
    // NOOP
}

- (void)serializeWithEncoder:(nonnull id<TLEncoder>)encoder {
    // NOOP
}

- (BOOL)updateWithCopyAllowed:(nullable NSNumber *)copyAllowed {
    if (!copyAllowed || copyAllowed.boolValue == self.copyAllowed) {
        return NO;
    }
    
    self.copyAllowed = copyAllowed.boolValue;
    return YES;
}

- (BOOL)updateWithMessage:(nullable NSString *)message {
    return NO;
}

+ (nonnull NSArray<TLChoice *> *)sortChoiceArray:(nonnull NSArray<TLChoice *> *)array {
    return [array sortedArrayUsingComparator:^NSComparisonResult(TLChoice * _Nonnull c1, TLChoice *  _Nonnull c2) {
        if (c1.position > c2.position) {
            return NSOrderedDescending;
        }
        
        if (c1.position < c2.position) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
}

@end

/*
 *  Copyright (c) 2017-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLFeedbackIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Feedback IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"B3ED091A-4DB9-4C9B-9501-65F11811738B",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"FeedbackIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"email", "type":"String"},
 *     {"name":"subject", "type":"String"},
 *     {"name":"feedbackDescription", "type":"String"},
 *     {"name":"deviceDescription", "type":"String"},
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLFeedbackIQSerializer
//

@implementation TLFeedbackIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLFeedbackIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLFeedbackIQ *feedbackIQ = (TLFeedbackIQ *)object;
    [encoder writeString:feedbackIQ.email];
    [encoder writeString:feedbackIQ.subject];
    [encoder writeString:feedbackIQ.feedbackDescription];
    [encoder writeString:feedbackIQ.deviceDescription];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLFeedbackIQ
//

@implementation TLFeedbackIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId email:(nonnull NSString *)email subject:(nonnull NSString *)subject feedbackDescription:(nonnull NSString *)feedbackDescription deviceDescription:(nonnull NSString *)deviceDescription {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _email = email;
        _subject = subject;
        _feedbackDescription = feedbackDescription;
        _deviceDescription = deviceDescription;
    }
    return self;
}

@end

/*
 *  Copyright (c) 2017-2021 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"

//
// Interface: TLFeedbackIQSerializer
//

@interface TLFeedbackIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLFeedbackIQ
//

@interface TLFeedbackIQ : TLBinaryPacketIQ

@property (readonly, nonnull) NSString *email;
@property (readonly, nonnull) NSString *subject;
@property (readonly, nonnull) NSString *feedbackDescription;
@property (readonly, nonnull) NSString *deviceDescription;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId email:(nonnull NSString *)email subject:(nonnull NSString *)subject feedbackDescription:(nonnull NSString *)feedbackDescription deviceDescription:(nonnull NSString *)deviceDescription;

@end

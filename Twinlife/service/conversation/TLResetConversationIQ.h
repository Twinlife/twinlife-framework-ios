/*
 *  Copyright (c) 2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBinaryPacketIQ.h"
#import "TLConversationService.h"

@class TLClearDescriptor;

//
// Interface: TLResetConversationIQSerializer
//

@interface TLResetConversationIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLResetConversationIQ
//

@interface TLResetConversationIQ : TLBinaryPacketIQ

@property (readonly, nullable) TLClearDescriptor *clearDescriptor;
@property (readonly) int64_t clearTimestamp;
@property (readonly) TLConversationServiceClearMode clearMode;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION_4;

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_4;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId clearDescriptor:(nullable TLClearDescriptor *)clearDescriptor clearTimestamp:(int64_t)clearTimestamp clearMode:(TLConversationServiceClearMode)clearMode;

@end

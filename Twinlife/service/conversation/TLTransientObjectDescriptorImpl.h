/*
 *  Copyright (c) 2016-2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLDescriptorImpl.h"

@class TLEncoder;

//
// Interface: TLTransientObjectDescriptorSerializer
//

@interface TLTransientObjectDescriptorSerializer : TLDescriptorSerializer_3

@end

//
// Interface: TLTransientObjectDescriptor ()
//

@interface TLTransientObjectDescriptor ()

@property (readonly, nonnull) TLSerializer *serializer;

+ (nonnull NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (nonnull TLSerializer *)SERIALIZER;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId serializer:(nonnull TLSerializer *)serializer object:(nonnull NSObject *)object;

- (nonnull instancetype)initWithTwincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId sequenceId:(int64_t)sequenceId serializer:(nonnull TLSerializer *)serializer object:(nonnull NSObject *)object createdTimestamp:(int64_t)createdTimestamp sentTimestamp:(int64_t)sentTimestamp;

- (nonnull instancetype)initWithDescriptor:(nonnull TLDescriptor *)descriptor serializer:(nonnull TLSerializer *)serializer object:(nonnull NSObject *)object;

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(nonnull id<TLEncoder>)encoder;

@end

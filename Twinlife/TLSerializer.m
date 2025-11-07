/*
 *  Copyright (c) 2015-2019 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSerializer.h"

//
// Implementation: TLSerializer
//

@implementation TLSerializer

- (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId schemaVersion:(int)schemaVersion class:(nonnull Class) clazz {
    
    self = [super init];
    if (self) {
        _schemaId = schemaId;
        _schemaVersion = schemaVersion;
        _clazz = clazz;
    }
    return self;
}

- (void)serializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(nonnull NSObject *)object {
}

- (NSObject *)deserializeWithSerializerFactory:(nonnull TLSerializerFactory *)serializerFactory decoder:(nonnull id<TLDecoder>)decoder {
    
    return nil;
}

- (BOOL)isSupportedWithMajorVersion:(int)majorVersion minorVersion:(int)minorVersion {
    
    return YES;
}

@end

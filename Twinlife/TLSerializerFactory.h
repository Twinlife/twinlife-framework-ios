/*
 *  Copyright (c) 2015-2017 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

//
// Interface: TLSerializerFactory
//

@class TLSerializer;

@interface TLSerializerFactory : NSObject

- (TLSerializer *)getSerializerWithObject:(NSObject *)object;

- (TLSerializer *)getSerializerWithSchemaId:(NSUUID *)schemaId schemaVersion:(int)schemaVersion;

@end

/*
 *  Copyright (c) 2015-2017 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLSerializerFactory.h"

//
// Interface: TLSerializerFactory ()
//

@interface TLSerializerFactory ()

@property NSMutableDictionary *class2Serializers;
@property NSMutableDictionary *serializers;

- (void)addSerializer:(TLSerializer *)serializer;

- (void)addSerializers:(NSArray<TLSerializer *> *)serializers;

@end

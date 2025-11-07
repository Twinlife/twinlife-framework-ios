/*
 *  Copyright (c) 2014-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPeerConnectionService.h"
#import "TLTwinlifeImpl.h"
#import "TLSerializerFactory.h"

@interface TLAccountMigrationPeerConnectionServiceDelegate : NSObject <TLPeerConnectionServiceDelegate>

@property (readonly, nonnull) TLTwinlife *twinlife;
@property (readonly, nonnull) TLSerializerFactory *serializerFactory;

@end

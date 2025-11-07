/*
 *  Copyright (c) 2014-2022 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLPeerConnectionObserver.h"

@interface TLAccountMigrationPeerConnectionServiceDelegate ()
@property (readonly, nonnull) TLPeerConnectionService *peerConnectionService;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<TLSerializerKey *, TLBinaryPacketListener> *binaryPacketListeners;
@property (nonatomic, readonly, nonnull) NSMutableArray<NSNumber *> *pendingRequests;
@property (readonly, nonnull) dispatch_queue_t executorQueue;
@property (nonatomic, nullable) NSUUID* incomingPeerConnectionId;
@property (nonatomic, nullable) NSUUID* outgoingPeerConnectionId;
@property (nonatomic, nullable) NSUUID* peerConnectionId;
@property (nonatomic) BOOL isOnline;
//TODOM ScheduledFuture openTimeout reconnectTimeout
@end

@implementation TLAccountMigrationPeerConnectionServiceDelegate



@end

/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

//
// Interface: TLTwincodeInfo
//

@interface TLTwincodeInfo : NSObject

@property (readonly, nonnull) NSUUID *twincodeFactoryId;
@property (readonly, nonnull) NSUUID *twincodeOutboundId;
@property (readonly, nonnull) NSUUID *twincodeInboundId;

- (nonnull instancetype)initWithTwincodeFactoryId:(nonnull NSUUID *)twincodeFactoryId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId;
@end

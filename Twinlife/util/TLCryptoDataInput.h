/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

@class TLCryptoBox;

//
// Interface: TLCryptoDataInput
//

@interface TLCryptoDataInput : NSData

- (nonnull instancetype)initWithFileHandle:(nonnull NSFileHandle *)fileHandle cryptoBox:(nonnull TLCryptoBox *)cryptoBox;

- (void)close;

- (BOOL)fullyRead;

@end

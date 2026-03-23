/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

@class TLCryptoBox;

//
// Interface: TLCryptoDataOutput
//

@interface TLCryptoDataOutput : NSMutableData

- (nonnull instancetype)initWithFileHandle:(nonnull NSFileHandle *)fileHandle size:(int)size cryptoBox:(nonnull TLCryptoBox *)cryptoBox;

- (void) flushBuffer;
@end

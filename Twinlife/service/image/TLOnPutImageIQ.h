/*
 *  Copyright (c) 2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 */

#import "TLBinaryPacketIQ.h"
#import "TLImageService.h"

typedef enum {
    TLPutImageStatusTypeIncomplete,         // Image upload is still incomplete.
    TLPutImageStatusTypeComplete,           // Image upload is complete and valid.
    TLPutImageStatusTypeError               // Image upload failed.
} TLPutImageStatusType;

//
// Interface: TLOnPutImageIQSerializer
//

@interface TLOnPutImageIQSerializer : TLBinaryPacketIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion;

@end

//
// Interface: TLOnPutImageIQ
//

@interface TLOnPutImageIQ : TLBinaryPacketIQ

@property (readonly) TLPutImageStatusType status;
@property (readonly) int64_t offset;

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer iq:(nonnull TLBinaryPacketIQ *)iq status:(TLPutImageStatusType)status offset:(int64_t)offset;

@end

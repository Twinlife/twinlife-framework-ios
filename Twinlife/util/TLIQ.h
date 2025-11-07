/*
 *  Copyright (c) 2015-2016 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 */

#import "TLSerializer.h"

//
// Interface: TLIQSerializer
//

@interface TLIQSerializer : TLSerializer

+ (NSUUID *)SCHEMA_ID;

+ (int)SCHEMA_VERSION;

+ (TLSerializer *)SERIALIZER;

@end

//
// Interface: TLIQ
//

typedef enum {
    TLIQTypeSet,
    TLIQTypeGet,
    TLIQTypeResult,
    TLIQTypeError
} TLIQType;

@interface TLIQ : NSObject

@property (readonly) NSString *id;
@property (readonly) NSString *from;
@property (readonly) NSString *to;
@property (readonly) TLIQType type;

- (instancetype)initWithFrom:(NSString *)from to:(NSString *)to type:(TLIQType)type;

- (instancetype)initWithId:(NSString *)id from:(NSString *)from to:(NSString *)to type:(TLIQType)type;

- (instancetype)initWithIQ:(TLIQ *)iq;

- (void)appendTo:(NSMutableString*)string;

@end

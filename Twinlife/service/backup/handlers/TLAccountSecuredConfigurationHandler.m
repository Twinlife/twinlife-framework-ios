/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLAccountSecuredConfigurationHandler.h"
#import "TLTwinlifeSecuredConfiguration.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif


//
// Interface: TLAccountServiceSecuredConfigurationRestorerV1
//

@interface TLAccountServiceSecuredConfigurationRestorerV1 : TLRestorer<TLAccountServiceSecuredConfiguration *>

@property (nonnull, readonly) TLTwinlife *twinlife;

- (nonnull instancetype) initWithTwinlife:(nonnull TLTwinlife *)twinlife;

@end

//
// Implementation: TLAccountServiceSecuredConfigurationRestorerV1
//

#undef LOG_TAG
#define LOG_TAG @"TLAccountServiceSecuredConfigurationRestorerV1"

@implementation TLAccountServiceSecuredConfigurationRestorerV1

+ (nonnull NSNumber *) VERSION {
    return @1;
}

- (nonnull instancetype) initWithTwinlife:(nonnull TLTwinlife *)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife: %@", LOG_TAG, twinlife);
    
    self = [super init];
    
    if (self) {
        _twinlife = twinlife;
    }
    
    return self;
}

- (nullable TLAccountServiceSecuredConfiguration *) restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");
    
    NSData *data = [decoder readData];
    
    TLAccountServiceSecuredConfiguration *secureConfig = [TLAccountServiceSecuredConfiguration loadWithSerializerFactory:self.twinlife.serializerFactory content:data];
            
    return secureConfig;
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);

    NSData *data = [decoder readData];
    
    TLAccountServiceSecuredConfiguration *secureConfig = [TLAccountServiceSecuredConfiguration loadWithSerializerFactory:self.twinlife.serializerFactory content:data];

    BOOL isCurrentAccount = [self.twinlife.accountService isCurrentAccountWithAccountConfiguration:secureConfig];
    
    return [[TLBackupVerifyResultPresent alloc] initWithObject:secureConfig modified:!isCurrentAccount];
}

@end

@interface TLAccountSecuredConfigurationHandler ()

@property (nonnull, readonly) TLTwinlife *twinlife;

@end

//
// Implementation: TLAccountSecuredConfigurationHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLAccountSecuredConfigurationHandler"

@implementation TLAccountSecuredConfigurationHandler

- (nonnull instancetype)initWithTwinlife:(id)twinlife {
    DDLogVerbose(@"%@ initWithTwinlife", LOG_TAG);
    
    self  = [super initWithRestorers:@{
        TLAccountServiceSecuredConfigurationRestorerV1.VERSION : [[TLAccountServiceSecuredConfigurationRestorerV1 alloc] initWithTwinlife:twinlife]
    }];
    
    if (self) {
        _twinlife = twinlife;
    }
    
    return self;
}

- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogVerbose(@"%@ backupWithBinaryEncoder: %@", LOG_TAG, encoder);

    NSData *secureConfig = [TLAccountServiceSecuredConfiguration exportWithSerializerFactory:self.twinlife.serializerFactory];;
    
    if (!secureConfig) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    [encoder writeUUID:TL_ACCOUNT_CONFIGURATION_BACKUP_SCHEMA_ID];
    [encoder writeInt:TL_ACCOUNT_CONFIGURATION_BACKUP_SCHEMA_VERSION];
    [encoder writeData:secureConfig];
}

@end

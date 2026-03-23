/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLBackupHandler.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif


@implementation TLBackupVerifyResult

@end

@implementation TLBackupVerifyResultPresent

- (nonnull instancetype)initWithObject:(nonnull id)object modified:(BOOL)modified {
    self = [super init];
    
    if (self) {
        _object = object;
        _modified = modified;
    }
    
    return self;
}

@end

@implementation TLBackupVerifyResultAbsent

- (nonnull instancetype)initWithIdentifier:(nonnull NSUUID *)identifier schemaId:(nullable NSUUID *)schemaId type:(nonnull Class)type {
    self = [super init];
    
    if (self) {
        _identifier = identifier;
        _schemaId = schemaId;
        _type = type;
    }
    
    return self;
}

@end


//
// Implementation: TLRestorer
//

#undef LOG_TAG
#define LOG_TAG @"TLRestorer"


@implementation TLRestorer

- (nullable id)restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogError(@"%@ TLRestorer must be subclassed", LOG_TAG);
    return nil;
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogError(@"%@ TLRestorer must be subclassed", LOG_TAG);
    return nil;
}

- (nullable NSDictionary *)getStats {
    DDLogVerbose(@"%@ getStats (default)", LOG_TAG);
    
    return nil;
}

+ (nonnull NSNumber *)VERSION {
    return @-1;
}

@end


//
// Implementation: TLBackupHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLBackupHandler"

@implementation TLBackupHandler

- (nonnull instancetype)initWithRestorers:(nonnull NSDictionary<NSNumber *, TLRestorer<id> *> *)restorers {
    DDLogVerbose(@"%@ initWithRestorers: %@", LOG_TAG, restorers);

    self = [super init];
    
    if (self) {
        _restorers = restorers;
    }
    
    return self;
}

- (id)restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");
    
    NSNumber *version = [[NSNumber alloc] initWithInt:[decoder readInt]];
    
    TLRestorer *restorer = self.restorers[version];
    
    if (!restorer) {
        DDLogError(@"%@ no restorer found for version %d", LOG_TAG, version.intValue);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    return [restorer restoreWithBinaryDecoder:decoder inPlace:inPlace];
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);
    
    NSNumber *version = [[NSNumber alloc] initWithInt:[decoder readInt]];
    
    TLRestorer *restorer = self.restorers[version];
    
    if (!restorer) {
        DDLogError(@"%@ no restorer found for version %d", LOG_TAG, version.intValue);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    return [restorer verifyWithBinaryDecoder:decoder];
}


- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogError(@"%@ backupWithBinaryEncoder not implemented by class %@", LOG_TAG, NSStringFromClass([self class]));
}

- (nullable NSDictionary<NSUUID *,NSNumber *> *)getBackupStats {
    return nil;
}

- (nonnull NSDictionary<NSUUID *, NSNumber *> *)getRestoreStats {
    NSMutableDictionary<NSUUID *, NSNumber *> *stats = [NSMutableDictionary dictionary];
    
    for (TLRestorer *restorer in self.restorers.allValues) {
        NSDictionary<NSUUID *, NSNumber *> *restorerStats = restorer.getStats;
        
        if (restorerStats) {
            [stats addEntriesFromDictionary:restorerStats];
        }
    }
    
    return stats;
}

@end



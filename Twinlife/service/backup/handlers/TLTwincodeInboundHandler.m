/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLTwincodeInboundHandler.h"
#import "TLTwincodeInboundServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLCryptoServiceImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLTwincodeInboundRestorerV1
//

@interface TLTwincodeInboundRestorerV1 : TLRestorer<TLTwincodeInbound *>

@property (nonatomic, nonnull, readonly) TLTwincodeInboundService *twincodeInboundService;
@property (nonatomic, nonnull, readonly) TLTwincodeOutboundService *twincodeOutboundService;

@property (nonatomic, nullable) NSArray<TLTwincodeInbound *> *localTwincodes;

- (nonnull instancetype)initWithTwincodeInboundService:(nonnull TLTwincodeInboundService *)twincodeInboundService twincodeOutboundService:(nonnull TLTwincodeOutboundService *)twincodeOutboundService;

@end

//
// Implementation: TLTwincodeInboundRestorerV1
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeInboundRestorerV1"

@implementation TLTwincodeInboundRestorerV1

+ (nonnull NSNumber *) VERSION {
    return @1;
}

- (nonnull instancetype)initWithTwincodeInboundService:(nonnull TLTwincodeInboundService *)twincodeInboundService twincodeOutboundService:(nonnull TLTwincodeOutboundService *)twincodeOutboundService {
    self = [super init];
    
    if (self) {
        _twincodeInboundService = twincodeInboundService;
        _twincodeOutboundService = twincodeOutboundService;
    }
    
    return self;
}


- (nullable TLTwincodeInbound *) restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace? @"YES" : @"NO");
    
    int64_t dbId = [decoder readLong];
    NSUUID *twincodeId = [decoder readUUID];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    NSUUID *twincodeFactoryId = [decoder readOptionalUUID];
    int64_t modificationDate = [decoder readLong];
    
    if (inPlace) {
        return nil;
    }
    
    TLTwincodeOutbound *twincodeOutbound = [self.twincodeOutboundService getLocalTwincodeWithTwincodeId:twincodeOutboundId];
    
    if (!twincodeOutbound) {
        DDLogError(@"%@ No twincodeOutbound found for twincodeInbound: %@ (twincodeOutboundId: %@)", LOG_TAG, twincodeId.UUIDString, twincodeOutboundId.UUIDString);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
        
    TLTwincodeInbound *twincodeInbound = [self.twincodeInboundService restoreTwincodeWithDatabaseId:dbId twincodeId:twincodeId twincodeOutbound:twincodeOutbound twincodeFactoryId:twincodeFactoryId modificationDate:modificationDate];
    
    if (!twincodeInbound) {
        DDLogError(@"%@ Could not restore twincodeInbound: %@", LOG_TAG, twincodeId.UUIDString);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    } else {
        DDLogVerbose(@"%@ Restored twincodeInbound: %@", LOG_TAG, twincodeInbound);
    }
    
    return twincodeInbound;
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);
    
    [decoder readLong]; //dbId
    NSUUID *twincodeId = [decoder readUUID];
    [decoder readUUID]; //twincodeOutboundId
    [decoder readOptionalUUID]; //twincodeFactoryId
    [decoder readLong]; //modificationDate

    for (TLTwincodeInbound *twincodeInbound in [self getLocalTwincodes]) {
        if ([twincodeInbound.identifier isEqual:twincodeId]) {
            return [[TLBackupVerifyResultPresent alloc] initWithObject:twincodeInbound modified:NO];
        }
    }
    
    return [[TLBackupVerifyResultAbsent alloc] initWithIdentifier:twincodeId schemaId:nil type:TLTwincodeInbound.class];
}

- (NSArray<TLTwincodeInbound *> *)getLocalTwincodes {
    if (!self.localTwincodes) {
        self.localTwincodes = [self.twincodeInboundService getLocalTwincodes];
    }
    
    return self.localTwincodes;
}

@end

@interface TLTwincodeInboundHandler ()

@property (nonatomic, nonnull, readonly) TLTwincodeInboundService *twincodeInboundService;

@end

//
// Implementation: TLTwincodeInboundHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeInboundHandler"

@implementation TLTwincodeInboundHandler

- (nonnull instancetype)initWithTwincodeInboundService:(nonnull TLTwincodeInboundService *)twincodeInboundService twincodeOutboundService:(nonnull TLTwincodeOutboundService *)twincodeOutboundService {
    self = [super initWithRestorers:@{
        TLTwincodeInboundRestorerV1.VERSION : [[TLTwincodeInboundRestorerV1 alloc] initWithTwincodeInboundService:twincodeInboundService twincodeOutboundService:twincodeOutboundService]
    }];
    
    if (self) {
        _twincodeInboundService = twincodeInboundService;
    }
    
    return self;
}


- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogVerbose(@"%@ backupWithBinaryEncoder: %@", LOG_TAG, encoder);

    NSArray<TLTwincodeInbound *> *localTwincodes = [self.twincodeInboundService getLocalTwincodes];
    
    for (TLTwincodeInbound *twincodeInbound in localTwincodes) {
        [encoder writeUUID:TL_TWINCODE_INBOUND_BACKUP_SCHEMA_ID];
        [encoder writeInt:TL_TWINCODE_INBOUND_BACKUP_SCHEMA_VERSION];
        [encoder writeLong:twincodeInbound.identifier.identifier];
        [encoder writeUUID:twincodeInbound.uuid];
        [encoder writeUUID:twincodeInbound.twincodeOutbound.uuid];
        [encoder writeOptionalUUID:twincodeInbound.twincodeFactoryId];
        [encoder writeLong:twincodeInbound.modificationDate];
        
        DDLogVerbose(@"%@ Backed up twincodeInbound=%@", LOG_TAG, twincodeInbound);
    }
}
@end




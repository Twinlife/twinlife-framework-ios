/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLTwincodeOutboundHandler.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLCryptoServiceImpl.h"
#import "TLImageId.h"
#import "TLAttributeNameValue.h"
#import "TLImageServiceProvider.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLTwincodeOutboundRestorerV1
//

@interface TLTwincodeOutboundRestorerV1 : TLRestorer<TLTwincodeOutbound *>

@property (nonatomic, nonnull, readonly) TLTwincodeOutboundService *twincodeOutboundService;
@property (nonatomic, nonnull, readonly) TLCryptoService *cryptoService;

- (nonnull instancetype)initWithTwincodeOutboundService:(nonnull TLTwincodeOutboundService *)twincodeOutboundService cryptoService:(nonnull TLCryptoService *)cryptoService;

@end

//
// Implementation: TLTwincodeOutboundRestorerV1
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeOutboundRestorerV1"

@implementation TLTwincodeOutboundRestorerV1

+ (nonnull NSNumber *) VERSION {
    return @1;
}

- (nonnull instancetype)initWithTwincodeOutboundService:(nonnull TLTwincodeOutboundService *)twincodeOutboundService cryptoService:(nonnull TLCryptoService *)cryptoService {
    self = [super init];
    
    if (self) {
        _twincodeOutboundService = twincodeOutboundService;
        _cryptoService = cryptoService;
    }
    
    return self;
}


- (nullable TLTwincodeOutbound *)restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");
    
    if (inPlace) {
        return [self restoreInPlaceWithDecoder:decoder];
    } else {
        return [self fullRestoreWithDecoder:decoder];
    }
}

- (nullable TLTwincodeOutbound *)fullRestoreWithDecoder:(nonnull TLBinaryDecoder *)decoder {
    int64_t dbId = [decoder readLong];
    NSUUID *twincodeId = [decoder readUUID];
    int64_t creationDate = [decoder readLong];
    int64_t modificationDate = [decoder readLong];
    NSArray<TLAttributeNameValue *> *attributes = [decoder readAttributes];
    int flags = [decoder readInt];
    
    // Make sure the twincode will be refreshed from the server (see RestoreExecutor.syncTwincodes())
    flags |= FLAG_NEED_FETCH;
    
    TLTwincodeOutbound *twincodeOutbound = [self.twincodeOutboundService restoreTwincodeWithDatabaseId:dbId twincodeId:twincodeId creationDate:creationDate modificationDate:modificationDate attributes:attributes flags:flags];
    
    if (!twincodeOutbound) {
        DDLogError(@"%@ could not restore twincodeOutbound %@", LOG_TAG, twincodeId.UUIDString);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
        return nil;
    }
    
    DDLogVerbose(@"%@ Restored twincodeOutbound: %@", LOG_TAG, twincodeOutbound);
    
    BOOL hasKey = [decoder readBoolean];
    
    if (hasKey) {
        NSData *signingKey = [decoder readData];
        NSData *encryptionKey = [decoder readOptionalData];
        int64_t keyCreationDate = [decoder readLong];
        int64_t keyModificationDate = [decoder readLong];
        int flags = [decoder readInt];
        
        TLRawKeyInfo *rawKeyInfo = [[TLRawKeyInfo alloc] initWithCreationDate:keyCreationDate modificationDate:keyModificationDate signingKey:signingKey encryptionKey:encryptionKey flags:flags];
        
        TLBaseServiceErrorCode errorCode = [self.cryptoService restoreKeyInfoWithTwincodeOutbound:twincodeOutbound rawKeyInfo:rawKeyInfo];
        
        if (errorCode != TLBaseServiceErrorCodeSuccess) {
            DDLogError(@"%@ could not restore key for twincodeOutbound %@", LOG_TAG, twincodeId.UUIDString);
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
        } else {
            DDLogVerbose(@"%@ Restored key for twincodeOutbound %@", LOG_TAG, twincodeId.UUIDString);
        }
    }
    
    return twincodeOutbound;
}

- (nullable TLTwincodeOutbound *)restoreInPlaceWithDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ restoreInPlaceWithDecoder: %@", LOG_TAG, decoder);
    
    // We only want the twincodeId, the modification date and the attributes, but we still need to decode all data.
    [decoder readLong];
    NSUUID *twincodeId = [decoder readUUID];
    [decoder readLong];
    int64_t modificationDate = [decoder readLong];
    NSArray<TLAttributeNameValue *> *attributes = [decoder readAttributes];
    [decoder readInt];
    
    BOOL hasKey = [decoder readBoolean];
    
    if (hasKey) {
        [decoder readData];
        [decoder readOptionalData];
        [decoder readLong];
        [decoder readLong];
        [decoder readInt];
    }
    
    TLTwincodeOutbound *existingTwincode = [self.twincodeOutboundService getLocalTwincodeWithTwincodeId:twincodeId];
    
    if (!existingTwincode) {
        DDLogVerbose(@"%@ Twincode %@ doesn't exist anymore, ignoring", LOG_TAG, twincodeId.UUIDString);
        return nil;
    }
    
    if (!attributes) {
        DDLogError(@"%@ No attributes found for twincode %@", LOG_TAG, twincodeId.UUIDString);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    if (!existingTwincode.isOwner) {
        DDLogVerbose(@"%@ Twincode %@ is not ours, skipping update", LOG_TAG, twincodeId.UUIDString);
        return existingTwincode;
    }
    
    NSArray<NSString *> *deleteAttributeNames = [self getDeleteAttributeNamesWithTwincode:existingTwincode attributes:attributes];
    
    return [self.twincodeOutboundService restoreExistingTwincodeWithTwincodeOutbound:existingTwincode modificationDate:modificationDate attributes:attributes deleteAttributeNames:deleteAttributeNames];
}

-(nonnull NSArray<NSString *> *)getDeleteAttributeNamesWithTwincode:(nonnull TLTwincodeOutbound *)twincode attributes:(nonnull NSArray<TLAttributeNameValue *> *)attributes {
    NSMutableArray<NSString *> *deleteAttributeNames = [NSMutableArray array];
    
    for (TLAttributeNameValue *attr in twincode.attributes) {
        BOOL found = NO;
        
        for (TLAttributeNameValue *bkpAttr in attributes) {
            if ([attr.name isEqualToString:bkpAttr.name]) {
                found = YES;
                break;
            }
        }
        
        if (!found) {
            [deleteAttributeNames addObject:attr.name];
        }
    }
    
    return deleteAttributeNames;
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);
    
    [decoder readLong]; //dbId
    NSUUID *twincodeId = [decoder readUUID];
    [decoder readLong]; //creationDate
    [decoder readLong]; //modificationDate
    NSSet<TLAttributeNameValue *> *attributes = [NSSet setWithArray:[decoder readAttributes]];
    [decoder readInt]; //flags
    
    BOOL hasKey = [decoder readBoolean];
    if (hasKey) {
        [decoder readData];
        [decoder readOptionalData];
        [decoder readLong];
        [decoder readLong];
        [decoder readInt];
    }

    TLTwincodeOutbound *localTwincode = [self.twincodeOutboundService getLocalTwincodeWithTwincodeId:twincodeId];
    
    if (!localTwincode) {
        return [[TLBackupVerifyResultAbsent alloc] initWithIdentifier:twincodeId schemaId:nil type:TLTwincodeOutbound.class];
    }
    
    NSMutableArray<TLAttributeNameValue *> *avatarAttribute = [NSMutableArray arrayWithCapacity:1];
    
    if (localTwincode.avatarId) {
        if ([localTwincode.avatarId isKindOfClass:TLExportedImageId.class]) {
            [avatarAttribute addObject:[[TLAttributeNameImageIdValue alloc] initWithName:TL_TWINCODE_AVATAR_ID imageId:(TLExportedImageId *)localTwincode.avatarId]];
        } else {
            TLImageInfo *imageInfo = [self.twincodeOutboundService.twinlife.imageService getImageInfoWithImageId:localTwincode.avatarId];
            [avatarAttribute addObject:[[TLAttributeNameUUIDValue alloc] initWithName:TL_TWINCODE_AVATAR_ID uuidValue:imageInfo.publicId]];
        }
    }
    
    NSSet<TLAttributeNameValue *> *dbAttributes = [NSSet setWithArray:[localTwincode getAttributes:avatarAttribute deleteAttributeNames:nil]];
    
    BOOL modified = dbAttributes.count != attributes.count || ![dbAttributes isEqualToSet:attributes];
    
    return [[TLBackupVerifyResultPresent alloc] initWithObject:localTwincode modified:modified];
}

@end

@interface TLTwincodeOutboundHandler ()

@property (nonatomic, nonnull, readonly) TLTwincodeOutboundService *twincodeOutboundService;
@property (nonatomic, nonnull, readonly) TLCryptoService *cryptoService;

@end

//
// Implementation: TLTwincodeOutboundHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLTwincodeOutboundHandler"

@implementation TLTwincodeOutboundHandler

- (nonnull instancetype)initWithTwincodeOutboundService:(TLTwincodeOutboundService *)twincodeOutboundService cryptoService:(TLCryptoService *)cryptoService {
    self = [super initWithRestorers:@{
        TLTwincodeOutboundRestorerV1.VERSION : [[TLTwincodeOutboundRestorerV1 alloc] initWithTwincodeOutboundService:twincodeOutboundService cryptoService:cryptoService]
    }];
    
    if (self) {
        _twincodeOutboundService = twincodeOutboundService;
        _cryptoService = cryptoService;
    }
    
    return self;
}


- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogVerbose(@"%@ backupWithBinaryEncoder: %@", LOG_TAG, encoder);

    NSArray<TLTwincodeOutbound *> *localTwincodes = [self.twincodeOutboundService getLocalTwincodes];
    
    for (TLTwincodeOutbound *twincodeOutbound in localTwincodes) {
        [encoder writeUUID:TL_TWINCODE_OUTBOUND_BACKUP_SCHEMA_ID];
        [encoder writeInt:TL_TWINCODE_OUTBOUND_BACKUP_SCHEMA_VERSION];
        [encoder writeLong:twincodeOutbound.identifier.identifier];
        [encoder writeUUID:twincodeOutbound.uuid];
        [encoder writeLong:twincodeOutbound.creationDate];
        [encoder writeLong:twincodeOutbound.modificationDate];
        
        NSMutableArray<TLAttributeNameValue *> *avatarAttribute = [NSMutableArray arrayWithCapacity:1];
        
        if (twincodeOutbound.avatarId) {
            if ([twincodeOutbound.avatarId isKindOfClass:TLExportedImageId.class]) {
                [avatarAttribute addObject:[[TLAttributeNameImageIdValue alloc] initWithName:TL_TWINCODE_AVATAR_ID imageId:(TLExportedImageId *)twincodeOutbound.avatarId]];
            } else {
                TLImageInfo *imageInfo = [self.twincodeOutboundService.twinlife.imageService getImageInfoWithImageId:twincodeOutbound.avatarId];
                [avatarAttribute addObject:[[TLAttributeNameUUIDValue alloc] initWithName:TL_TWINCODE_AVATAR_ID uuidValue:imageInfo.publicId]];
            }
        }
        
        [encoder writeAttributes:[twincodeOutbound getAttributes:avatarAttribute deleteAttributeNames:nil]];
        
        [encoder writeInt:twincodeOutbound.flags];
        
        TLRawKeyInfo *rawKeyInfo = [self.cryptoService getRawTwincodeKeyWithTwincode:twincodeOutbound];
        
        if (!rawKeyInfo) {
            [encoder writeBoolean:NO];
        } else {
            [encoder writeBoolean:YES];
            [encoder writeData:rawKeyInfo.signingKey];
            [encoder writeOptionalData:rawKeyInfo.encryptionKey];
            [encoder writeLong:rawKeyInfo.creationDate];
            [encoder writeLong:rawKeyInfo.modificationDate];
            [encoder writeInt:rawKeyInfo.flags];
        }
        
        DDLogVerbose(@"%@ Backed up twincodeOutbound=%@", LOG_TAG, twincodeOutbound);
    }
}
@end



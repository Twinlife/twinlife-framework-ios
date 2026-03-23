/*
 *  Copyright (c) 2025-2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import <CocoaLumberjack.h>

#import "TLBackupHeaderHandler.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLBackupHeaderRestorerV1
//

@interface TLBackupHeaderRestorerV1 : TLRestorer<TLBackupHeaderInfo *>

@end

//
// Implementation: TLBackupHeaderRestorerV1
//

#undef LOG_TAG
#define LOG_TAG @"TLBackupHeaderRestorerV1"

@implementation TLBackupHeaderRestorerV1

+ (nonnull NSNumber *) VERSION {
    return @1;
}

- (nullable TLBackupHeaderInfo *) restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");

    int64_t date = [decoder readLong];
    NSUUID *backupId = [decoder readUUID];
    NSData *salt = [decoder readData];
    NSString *applicationName = [decoder readString];
    NSString *applicationVersion = [decoder readString];
    
    DDLogVerbose(@"%@ decoded, date=%lld backupId=%@ salt=%@ applicationName=%@ applicationVersion=%@", LOG_TAG, date, backupId.UUIDString, salt, applicationName, applicationVersion);
    
    return [[TLBackupHeaderInfo alloc] initWithDate:date backupId:backupId salt:salt applicationName:applicationName applicationVersion:applicationVersion];
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);

    return [[TLBackupVerifyResultPresent alloc] initWithObject:[self restoreWithBinaryDecoder:decoder inPlace:YES] modified:NO];
}


@end

@interface TLBackupHeaderHandler ()

@property (nonatomic, readonly) int64_t date;
@property (nonatomic, nullable, readonly) NSUUID *backupId;
@property (nonatomic, nullable, readonly) NSData *salt;
@property (nonatomic, nullable, readonly) NSString *applicationName;
@property (nonatomic, nullable, readonly) NSString *applicationVersion;
@property (nonatomic, nonnull, readonly) NSData *fileSignature;

@end

//
// Implementation: TLBackupHeaderHandler
//

#undef LOG_TAG
#define LOG_TAG @"TLBackupHeaderHandler"

@implementation TLBackupHeaderHandler

- (nonnull instancetype)initWithFileSignature:(nonnull NSData *)fileSignature {
    self = [super initWithRestorers:@{
        TLBackupHeaderRestorerV1.VERSION : [[TLBackupHeaderRestorerV1 alloc] init]
    }];
    
    if (self) {
        _date = -1;
        _backupId = nil;
        _salt = nil;
        _applicationName = nil;
        _applicationVersion = nil;
        _fileSignature = fileSignature;
    }
    
    return self;
}

- (nonnull instancetype)initWithBackupId:(nonnull NSUUID *)backupId date:(int64_t)date salt:(nonnull NSData *)salt applicationName:(nonnull NSString *)applicationName applicationVersion:(nonnull NSString *)applicationVersion fileSignature:(nonnull NSData *)fileSignature{
    self = [super initWithRestorers:@{
        TLBackupHeaderRestorerV1.VERSION : [[TLBackupHeaderRestorerV1 alloc] init]
    }];
    
    if (self) {
        _date = date;
        _backupId = backupId;
        _salt = salt;
        _applicationName = applicationName;
        _applicationVersion = applicationVersion;
        _fileSignature = fileSignature;
    }
    
    return self;
}

- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder {
    DDLogVerbose(@"%@ backupWithBinaryEncoder: %@", LOG_TAG, encoder);

    if (self.date == -1 || !self.backupId || !self.salt || !self.applicationName || !self.applicationVersion) {
        DDLogError(@"%@ date, ID, salt, application name and version must be initialized to perform backup", LOG_TAG);
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
    }
    
    [encoder writeData:self.fileSignature];
    [encoder writeInt:TL_BACKUP_HEADER_BACKUP_SCHEMA_VERSION];
    [encoder writeLong:self.date];
    [encoder writeUUID:self.backupId];
    [encoder writeData:self.salt];
    [encoder writeString:self.applicationName];
    [encoder writeString:self.applicationVersion];
}

- (id)restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace {
    DDLogVerbose(@"%@ restoreWithBinaryDecoder: %@ inPlace: %@", LOG_TAG, decoder, inPlace ? @"YES" : @"NO");
    
    if (![self checkSignatureWithBinaryDecoder:decoder]) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:@"Invalid file signature" userInfo:nil];
    }
    
    return [super restoreWithBinaryDecoder:decoder inPlace:inPlace];
}

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ verifyWithBinaryDecoder: %@", LOG_TAG, decoder);
    
    if (![self checkSignatureWithBinaryDecoder:decoder]) {
        @throw [NSException exceptionWithName:@"TLDecoderException" reason:@"Invalid file signature" userInfo:nil];
    }
    
    return [super verifyWithBinaryDecoder:decoder];
}

- (BOOL)checkSignatureWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder {
    DDLogVerbose(@"%@ checkSignatureWithBinaryDecoder: %@", LOG_TAG, decoder);
    
    NSData *signature = [decoder readData];
    
    return [signature isEqualToData:self.fileSignature];
}

@end


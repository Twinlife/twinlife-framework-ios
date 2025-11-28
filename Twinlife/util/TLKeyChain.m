/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

#import <CocoaLumberjack.h>

#import "TLAssertion.h"
#import "TLKeyChain.h"
#import "TLTwinlifeImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

// For twinme and twinme+, we must add a prefix to make sure we are doing the NSUserDefaults -> KeyChain
// migration (because it turns out some devices from developers and may be some beta testers could
// have a KeyChain entry but their content is not valid).
#ifdef SKRED
# define LEGACY_NO_KEYSTORE NO   // Keystore was used since the beginning
# define TO_KEYCHAIN_KEY(NAME)   (NAME)
#else
# define LEGACY_NO_KEYSTORE YES  // Keystore was not used and we must handle upgrade transparently
# if defined(MYTWINLIFE) || defined(MYTWINLIFE_PLUS)
#   define TO_KEYCHAIN_KEY(NAME)   [NSString stringWithFormat:@"ks-dev.%@", (NAME)]
# else
#   define TO_KEYCHAIN_KEY(NAME)   [NSString stringWithFormat:@"ks.%@", (NAME)]
# endif
#endif

static const char sUUID1[kCCKeySizeAES256] = {43, 252, 50, 60, 180, 24, 65, 123, 165, 209, 16, 255, 72, 168, 228, 15};
static const char sUUID2[kCCKeySizeAES256] = {203, 179, 22, 102, 61, 178, 72, 87, 174, 60, 248, 65, 59, 22, 107, 26};
static char sSecretKey[kCCKeySizeAES256] = {0};

#define TWINLIFE_ACCESSIBLE_AFTER_FIRST_UNLOCK_KEY @"TLTwinlifeAccessibleAfterFirstUnlock"

//
// Interface: TLKeyChain
//

@interface TLKeyChain ()

+ (BOOL)createTagChainWithTag:(nonnull NSString *)tag;

@end

//
// Implementation: TLKeyChain
//

#undef LOG_TAG
#define LOG_TAG @"TLKeyChain"

@implementation TLKeyChain

+ (void)initialize {
    DDLogVerbose(@"%@ initialize", LOG_TAG);
    
    for (int i = 0; i < kCCKeySizeAES256; i++) {
        sSecretKey[i] = (char)(sUUID1[i] ^ sUUID2[kCCKeySizeAES256 - 1 - i]);
    }
}

+ (void)waitUntilReady {
    DDLogVerbose(@"%@ waitUntilReady", LOG_TAG);
    
    NSMutableDictionary *queryAttributes = [[NSMutableDictionary alloc] init];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:TWINLIFE_ACCESSIBLE_AFTER_FIRST_UNLOCK_KEY forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    [queryAttributes setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [queryAttributes setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    CFTypeRef result = nil;
    OSStatus resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryAttributes, &result);
    NSTimeInterval timeInterval = 1;
    while (resultCode == errSecInteractionNotAllowed) {
        [NSThread sleepForTimeInterval:timeInterval];
        resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryAttributes, &result);
    }
}

+ (nullable NSString *)getContentWithTag:(nonnull NSString *)tag type:(TLKeyChainTagType)type {
    DDLogVerbose(@"%@ getContentWithTag: %@ type: %ld", LOG_TAG, tag, type);

    NSUserDefaults *userDefaults;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appDir;
    switch (type) {
        case TLKeyChainTagTypePrivate:
            userDefaults = [NSUserDefaults standardUserDefaults];
            appDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
            break;

        case TLKeyChainTagTypeApplication:
            userDefaults = [TLTwinlife getAppSharedUserDefaultsWithAlternateApplication:NO];
            appDir = [TLTwinlife getAppGroupURL:fileManager];
            break;

        case TLKeyChainTagTypeAlternate:
            userDefaults = [TLTwinlife getAppSharedUserDefaultsWithAlternateApplication:YES];
            appDir = [fileManager containerURLForSecurityApplicationGroupIdentifier:TWINME_APP_GROUP_NAME];
            break;
    }

    NSURL *url = [appDir URLByAppendingPathComponent:tag];
    NSString *tagPath = url.path;

    NSString *fileContent = nil;
    if ([fileManager fileExistsAtPath:tagPath]) {
        fileContent = [NSString stringWithContentsOfFile:tagPath encoding:NSUTF8StringEncoding error:nil];
    }
    
    NSString *content = [userDefaults stringForKey:tag];
    if (content && !fileContent) {
        // The file does not exist but we have the marker in the NSUserDefaults, save a copy in the file.
        NSError *error;
        [content writeToFile:tagPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        fileContent = content;
        if (error) {
            // If we fail to save the tag, this could result to wrong behavior later, report an assertion failure if we can.
            // We only send the error code.
            TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_ERROR], [TLAssertValue initWithNumber:(int)tag.length], [TLAssertValue initWithNumber:(int)type], [TLAssertValue initWithNSError:error], [TLAssertValue initWithLength:content.length], nil);
        }

    } else if (fileContent && !content) {
        // Send an assertion to detect the NSUserDefaults issues.
        TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint MISSING_TAG_NSDEFAULTS], [TLAssertValue initWithNumber:(int)tag.length], [TLAssertValue initWithNumber:(int)type], nil);

    } else if (fileContent && ![fileContent isEqualToString:content]) {
        // Send an assertion if we detect that the file content is not synchronized with the NSUserDefaults.
        TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint INVALID_TAG_NSDEFAULTS], [TLAssertValue initWithNumber:(int)tag.length], [TLAssertValue initWithNumber:(int)type], [TLAssertValue initWithLength:fileContent.length], [TLAssertValue initWithLength:content.length], nil);
    }

    // Always return the fileData (the NSUserDefaults being unreliable).
    return fileContent;
}

+ (void)saveContentWithTag:(nonnull NSString *)tag type:(TLKeyChainTagType)type content:(nonnull NSString *)content {
    DDLogVerbose(@"%@ saveContentWithTag: %@ isPrivate: %ld content: %@", LOG_TAG, tag, type, content);
    
    NSUserDefaults *userDefaults;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appDir;
    switch (type) {
        case TLKeyChainTagTypePrivate:
            userDefaults = [NSUserDefaults standardUserDefaults];
            appDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
            break;
            
        case TLKeyChainTagTypeApplication:
            userDefaults = [TLTwinlife getAppSharedUserDefaultsWithAlternateApplication:NO];
            appDir = [TLTwinlife getAppGroupURL:fileManager];
            break;
            
        case TLKeyChainTagTypeAlternate:
        default:
            TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint BAD_VALUE], [TLAssertValue initWithNumber:(int)tag.length], [TLAssertValue initWithNumber:(int)type], nil);
            return;
    }
    
    NSURL *url = [appDir URLByAppendingPathComponent:tag];
    
    NSError *error;
    [content writeToFile:url.path atomically:YES encoding:NSUTF8StringEncoding error:&error];
    [userDefaults setObject:content forKey:tag];
    if (error) {
        // If we fail to save the tag, this could result to wrong behavior later, report an assertion failure if we can.
        // We only send the error code.
        TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_ERROR], [TLAssertValue initWithNumber:(int)tag.length], [TLAssertValue initWithNumber:(int)type], [TLAssertValue initWithNSError:error], [TLAssertValue initWithLength:content.length], nil);
    }
}

+ (void)removeContentWithTag:(nonnull NSString *)tag type:(TLKeyChainTagType)type {
    DDLogVerbose(@"%@ removeContentWithTag: %@ type: %ld", LOG_TAG, tag, type);

    NSUserDefaults *userDefaults;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appDir;
    switch (type) {
        case TLKeyChainTagTypePrivate:
            userDefaults = [NSUserDefaults standardUserDefaults];
            appDir = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
            break;

        case TLKeyChainTagTypeApplication:
            userDefaults = [TLTwinlife getAppSharedUserDefaultsWithAlternateApplication:NO];
            appDir = [TLTwinlife getAppGroupURL:fileManager];
            break;
            
        case TLKeyChainTagTypeAlternate:
        default:
            TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint BAD_VALUE], [TLAssertValue initWithNumber:(int)tag.length], [TLAssertValue initWithNumber:(int)type], nil);
            return;
    }

    NSURL *url = [appDir URLByAppendingPathComponent:tag];

    if ([fileManager fileExistsAtPath:url.path]) {
        [fileManager removeItemAtPath:url.path error:nil];
    }
    [userDefaults removeObjectForKey:tag];
}

+ (nullable NSData *)getKeyChainDataWithKey:(nonnull NSString *)key tag:(nullable NSString *)tag alternateApplication:(BOOL)alternateApplication {
    DDLogVerbose(@"%@ getKeyChainDataWithKey: %@ tag: %@ alternateApplication: %d", LOG_TAG, key, tag, alternateApplication);
    
    NSMutableDictionary *queryAttributes = [[NSMutableDictionary alloc] init];
    CFTypeRef result = nil;
    OSStatus resultCode;
    NSString *keychainKey = TO_KEYCHAIN_KEY(key);
    NSString *keychainTag = TO_KEYCHAIN_KEY(tag);
    [queryAttributes removeAllObjects];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:keychainKey forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:alternateApplication ? TWINME_KEYCHAIN_SERVICE : KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    [queryAttributes setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [queryAttributes setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryAttributes, &result);
    NSData *data = nil;
    if (resultCode == errSecItemNotFound) {
        // For twinme and twinme+, look at the NSUserDefaults and deobfuscate with the default encryption key.
        // If we are the main application, store the decrypted content in the iOS KeyChain.  Unlike Android, we don't
        // need to change the key name to detect whether upgrade was necessary.  For now, we also keep the credentials
        // in the NSUserDefaults in case there are issues.
        if (LEGACY_NO_KEYSTORE) {
            NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaultsWithAlternateApplication:alternateApplication];
            data = [userDefaults dataForKey:key];
            if (data) {
                data = [TLKeyChain decryptWithData:data];
                if (data && !alternateApplication) {
                    [TLKeyChain createKeyChainWithKey:key tag:tag data:data];
                }
            }
        }

        // Nothing in the Keychain, this is a fresh installation.
        return data;
    }
    if (resultCode != errSecSuccess) {
        TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint KEY_CHAIN], [TLAssertValue initWithNumber:resultCode], nil);
        return nil;
    }
    data = (__bridge id)result;

    // Note: the `tag` is nil only when we store or retrieve a value from the AccountMigrationService.
    if (!tag) {
        return data;
    }

    // iOS 10.3 Beta 1 and Beta 2 are the only versions that remove the keychain when the application
    // is uninstalled.  Apple restored the old behavior after complains from other applications.
    // They recommend storing something in the userDefaults to help detecting this.
    // We use a tag to detect when the application is uninstalled and the keychain contains an
    // old database key and device account.
    //
    //                          key         tag       userDefaults    action
    // Installation          <missing>   <missing>    <missing>       create key, tag, userDefaults
    // Migration             <known>     <missing>    <missing>       create tag, userDefaults
    // Uninstall             <known>     <known>      <missing>       erase key, tag
    // Broken Restore        <known>     <known>      <old>           erase key, tag
    //                       <missing>   <missing>    <known>         create key, tag, userDefaults
    // Restart               <known>     <known>      <known>         no-op
    //
    // A 'broken restore' occurs if the user saves the keychain without password and restores it
    // on another device: the keychain is not restored.
    //
    [queryAttributes removeAllObjects];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:keychainTag forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:alternateApplication ? TWINME_KEYCHAIN_SERVICE : KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    [queryAttributes setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
    [queryAttributes setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    resultCode = SecItemCopyMatching((__bridge CFDictionaryRef)queryAttributes, &result);
    NSData *tagData = nil;
    if (resultCode == errSecSuccess) {
        tagData = (__bridge id)result;

        NSString *tagValue = [TLKeyChain getContentWithTag:tag type:(alternateApplication ? TLKeyChainTagTypeAlternate : TLKeyChainTagTypeApplication)];
        NSString *expectTagValue = [[NSString alloc] initWithData:tagData encoding:NSUTF8StringEncoding];
        if (!tagValue) {
            // There are some evidence that the iOS NSUserDefaults is not reliable and can be lost:
            // - https://discussions.apple.com/thread/256060025?sortBy=rank
            // - https://christianselig.com/2024/10/beware-userdefaults/
            // If our database exist, we know this is not a re-installation and we can almost return the data.
            // The assertion is here to notify us about this rare issue.
            BOOL hasDb = [TLTwinlife hasDatabase];
            if (hasDb) {
                TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint RECOVER_TAG_KEY_CHAIN], nil);
                if (!alternateApplication) {
                    [TLKeyChain createTagChainWithTag:tag];
                }
                return data;
            }

            if (!alternateApplication) {
                // Tag exists in the keychain but was removed from the file system: application was uninstalled.
                [TLKeyChain removeKeyChainWithKey:key tag:tag];
                DDLogError(@"%@ getKeyChainDataWithKey: %@ tag: %@ exists in keychain (%@) but was removed", LOG_TAG, key, tag, expectTagValue);
                TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint MISSING_TAG_KEY_CHAIN], nil);
            }
            return nil;
        }
        if (![tagValue isEqualToString:expectTagValue]) {
            if (!alternateApplication) {
                // Tag exists in the keychain but has a different value: broken restore.
                [TLKeyChain removeKeyChainWithKey:key tag:tag];
                DDLogError(@"%@ getKeyChainDataWithKey: %@ expectTag: %@", LOG_TAG, tagValue, expectTagValue);
                TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint INVALID_TAG_KEY_CHAIN], nil);
            }
            return nil;
        }
    } else if (!alternateApplication) {
        // Migration: create the tag in keychain and userDefaults.
        [TLKeyChain createTagChainWithTag:tag];
    }
    return data;
}

+ (BOOL)createTagChainWithTag:(nonnull NSString *)tag {
    DDLogVerbose(@"%@ createTagChainWithTag: %@", LOG_TAG, tag);

    // Make sure the tag is removed.
    [TLKeyChain removeKeyChainWithKey:tag];

    // Create the tag with a new UUID that we put in the keychain and user defaults.
    // Both values must match when they are retrieved.  This is not sensitive data.
    NSUUID* tagValue = [NSUUID UUID];
    NSMutableDictionary *queryAttributes = [[NSMutableDictionary alloc] init];
    [queryAttributes setObject:TO_KEYCHAIN_KEY(tag) forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:[tagValue.UUIDString dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id)kSecValueData];
    [queryAttributes setObject:KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    [queryAttributes setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
    OSStatus resultCode = SecItemAdd((__bridge CFDictionaryRef)queryAttributes, NULL);
    
    // Create the tag with a new UUID that we put in the keychain and user defaults.
    // Both values must match when they are retrieved.  This is not sensitive data.
    if (resultCode == errSecSuccess) {
        [TLKeyChain saveContentWithTag:tag type:TLKeyChainTagTypeApplication content:tagValue.UUIDString];
        return YES;
    }

    TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_KEY_CHAIN], [TLAssertValue initWithNumber:resultCode], nil);
    return NO;
}

+ (BOOL)createKeyChainWithKey:(nonnull NSString *)key tag:(nullable NSString*)tag data:(nonnull NSData *)data {
    DDLogVerbose(@"%@ createKeyChainWithKey: %@ tag: %@ data: %@", LOG_TAG, key, tag, data);

    NSMutableDictionary *queryAttributes = [[NSMutableDictionary alloc] init];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:TO_KEYCHAIN_KEY(key) forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    [queryAttributes setObject:data forKey:(__bridge id)kSecValueData];
    [queryAttributes setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
    OSStatus resultCode = SecItemAdd((__bridge CFDictionaryRef)queryAttributes, NULL);
        
    if (tag && resultCode == errSecSuccess) {
        [TLKeyChain createTagChainWithTag:tag];
    }
    
    if (resultCode == errSecSuccess) {
        return YES;
    }

    TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_KEY_CHAIN], [TLAssertValue initWithNumber:resultCode], nil);
    return NO;
}

+ (BOOL)updateKeyChainWithKey:(nonnull NSString *)key tag:(nullable NSString *)tag data:(nonnull NSData *)data alternateApplication:(BOOL)alternateApplication {
    DDLogVerbose(@"%@ updateKeyChainWithKey: %@ tag: %@ data: %@ alternateApplication: %d", LOG_TAG, key, tag, data, alternateApplication);
    
    NSMutableDictionary *queryAttributes = [[NSMutableDictionary alloc] init];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:TO_KEYCHAIN_KEY(key) forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:alternateApplication ? TWINME_KEYCHAIN_SERVICE : KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] init];
    [attributesToUpdate setObject:data forKey:(__bridge id)kSecValueData];
    OSStatus resultCode = SecItemUpdate((__bridge CFDictionaryRef)queryAttributes, (__bridge CFDictionaryRef)attributesToUpdate);
    if (resultCode == errSecSuccess) {
        return YES;
    }
    if (resultCode != errSecItemNotFound) {
        TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_KEY_CHAIN], [TLAssertValue initWithNumber:resultCode], nil);
        return NO;
    }

    // If the item was not found, try to insert it
    // (this provides the same behavior as the NSUserDefaults setObject method used below
    // when Keychain is not used).
    [queryAttributes setObject:data forKey:(__bridge id)kSecValueData];
    [queryAttributes setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock forKey:(__bridge id)kSecAttrAccessible];
    resultCode = SecItemAdd((__bridge CFDictionaryRef)queryAttributes, NULL);

    if (resultCode == errSecSuccess) {
        if (tag) {
            [TLKeyChain createTagChainWithTag:tag];
        }
        return YES;
    }

    TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_KEY_CHAIN], [TLAssertValue initWithNumber:resultCode], nil);
    return NO;
}

+ (BOOL)removeKeyChainWithKey:(nonnull NSString *)key {
    DDLogVerbose(@"%@ removeKeyChainWithKey: %@", LOG_TAG, key);
    
    NSMutableDictionary *queryAttributes = [[NSMutableDictionary alloc] init];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:TO_KEYCHAIN_KEY(key) forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    OSStatus resultCode = SecItemDelete((__bridge CFDictionaryRef)queryAttributes);

    // Use removeContentWithTag so that we remove in NSUserDefaults and on file system (necessary for the tag).
    [TLKeyChain removeContentWithTag:key type:TLKeyChainTagTypeApplication];
    [TLKeyChain removeContentWithTag:key type:TLKeyChainTagTypePrivate];
    if (resultCode == errSecSuccess || resultCode == errSecItemNotFound) {
        return YES;
    }
    TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_KEY_CHAIN], [TLAssertValue initWithNumber:resultCode], nil);
    return NO;
}

+ (BOOL)removeKeyChainWithKey:(nonnull NSString *)key tag:(nullable NSString *)tag {
    DDLogVerbose(@"%@ removeKeyChainWithKey: %@ tag: %@", LOG_TAG, key, tag);
    
    NSMutableDictionary *queryAttributes = [[NSMutableDictionary alloc] init];
    [queryAttributes setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [queryAttributes setObject:TO_KEYCHAIN_KEY(key) forKey:(__bridge id)kSecAttrAccount];
    [queryAttributes setObject:KEYCHAIN_SERVICE forKey:(__bridge id)kSecAttrService];
    OSStatus resultCode = SecItemDelete((__bridge CFDictionaryRef)queryAttributes);
    NSUserDefaults *oldUserDefaults = [NSUserDefaults standardUserDefaults];
    [oldUserDefaults removeObjectForKey:key];
    if (tag) {
        [queryAttributes setObject:TO_KEYCHAIN_KEY(tag) forKey:(__bridge id)kSecAttrAccount];
        SecItemDelete((__bridge CFDictionaryRef)queryAttributes);
        [TLKeyChain removeContentWithTag:tag type:TLKeyChainTagTypeApplication];
        [TLKeyChain removeContentWithTag:tag type:TLKeyChainTagTypePrivate];
    }
    
    NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
    [userDefaults removeObjectForKey:key];
    if (resultCode == errSecSuccess || resultCode == errSecItemNotFound) {
        return YES;
    }
    TL_ASSERTION([TLTwinlife sharedTwinlife], [TLTwinlifeAssertPoint STORE_KEY_CHAIN], [TLAssertValue initWithNumber:resultCode], nil);
    return NO;
}

+ (void)removeAllKeyChain {
    DDLogVerbose(@"%@ removeAllKeyChain", LOG_TAG);
    
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];

    NSUserDefaults *oldUserDefaults = [NSUserDefaults standardUserDefaults];
    [oldUserDefaults removePersistentDomainForName:appDomain];
    
    NSUserDefaults *userDefaults = [TLTwinlife getAppSharedUserDefaults];
    [userDefaults removePersistentDomainForName:appDomain];
    
}

//
// Private methods
//

+ (NSData *)encryptWithData:(NSData *)data {
    DDLogVerbose(@"%@ encryptWithData %@", LOG_TAG, data);
    
    if (!data) {
        return nil;
    }
    
    void *ivData = malloc(kCCBlockSizeAES128);
    if (!ivData) {
        return nil;
    }
    int result = SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, ivData);
    if (result != errSecSuccess) {
        free(ivData);
        return nil;
    }
    
    size_t dataOutAvailable = data.length + kCCBlockSizeAES128;
    void *dataOut = malloc(kCCBlockSizeAES128 + dataOutAvailable);
    memcpy(dataOut, ivData, kCCBlockSizeAES128);
    size_t dataOutMoved = 0;
    CCCryptorStatus cryptorStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, (void *)sSecretKey, kCCKeySizeAES256, ivData, data.bytes, data.length,
                                            (char *)dataOut + kCCBlockSizeAES128, dataOutAvailable, &dataOutMoved);
    free(ivData);
    if (cryptorStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:dataOut length:kCCBlockSizeAES128 + dataOutMoved];
    }
    return nil;
}

+ (NSData *)decryptWithData:(NSData *)data {
    DDLogVerbose(@"%@ decryptWithData %@", LOG_TAG, data);
    
    if (!data || data.length < kCCBlockSizeAES128) {
        return nil;
    }
    
    void *ivData = malloc(kCCBlockSizeAES128);
    if (!ivData) {
        return nil;
    }
    memcpy(ivData, data.bytes, kCCBlockSizeAES128);
    
    size_t dataInLength = data.length - kCCBlockSizeAES128;
    void *dataIn = (char *)data.bytes + kCCBlockSizeAES128;
    size_t dataOutAvailable = dataInLength + kCCBlockSizeAES128;
    void *dataOut = malloc(dataOutAvailable);
    size_t dataOutMoved = 0;
    CCCryptorStatus cryptorStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, (void *)sSecretKey, kCCKeySizeAES256, ivData, dataIn, dataInLength,
                                            dataOut, dataOutAvailable, &dataOutMoved);
    free(ivData);
    if (cryptorStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:dataOut length:dataOutMoved];
    }
    return nil;
}

@end

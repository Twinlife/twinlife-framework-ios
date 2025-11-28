/*
 *  Copyright (c) 2017-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

typedef NS_ENUM(NSUInteger, TLKeyChainTagType) {
    TLKeyChainTagTypePrivate,
    TLKeyChainTagTypeApplication,
    TLKeyChainTagTypeAlternate
};

//
// Interface: TLKeyChain
//

@interface TLKeyChain : NSObject

+ (void)waitUntilReady;

/// Get a data tag from the filesystem or from the NSUserDefaults.  The data tag value should not contain sensitive value
/// this is only intended to be used to detect re-installation of the application.  The iOS NSUserDefaults are not reliable to store
/// some content and we use both filesystem & NSUserDefaults for this detection.  In most cases, the tag content is either
/// fixed (@"1" for the @"installed" tag) or a random NSUUID.`
+ (nullable NSString *)getContentWithTag:(nonnull NSString *)tag type:(TLKeyChainTagType)type;

/// Save the unsecure data content in a tag file and NSUserDefaults tag property.
+ (void)saveContentWithTag:(nonnull NSString *)tag type:(TLKeyChainTagType)type content:(nonnull NSString *)content;

/// Remove the data tag marker on the filesystem but also from the NSUserDefaults.
+ (void)removeContentWithTag:(nonnull NSString *)tag type:(TLKeyChainTagType)type;

+ (nullable NSData *)getKeyChainDataWithKey:(nonnull NSString *)key tag:(nullable NSString *)tag alternateApplication:(BOOL)alternateApplication;

+ (BOOL)createKeyChainWithKey:(nonnull NSString *)key tag:(nullable NSString *)tag data:(nonnull NSData *)data;

+ (BOOL)updateKeyChainWithKey:(nonnull NSString *)key tag:(nullable NSString *)tag data:(nonnull NSData *)data alternateApplication:(BOOL)alternateApplication;

+ (BOOL)removeKeyChainWithKey:(nonnull NSString *)key;

+ (BOOL)removeKeyChainWithKey:(nonnull NSString *)key tag:(nullable NSString *)tag;

+ (void)removeAllKeyChain;

+ (nullable NSData *)decryptWithData:(nonnull NSData *)data;

@end

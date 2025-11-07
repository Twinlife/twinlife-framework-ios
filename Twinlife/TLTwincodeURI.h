/*
 *  Copyright (c) 2024-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTwinlife.h"

typedef NS_ENUM(NSUInteger, TLTwincodeURIKind) {
    TLTwincodeURIKindInvitation,
    TLTwincodeURIKindCall,
    TLTwincodeURIKindTransfer,
    TLTwincodeURIKindAccountMigration,
    TLTwincodeURIKindAuthenticate,
    TLTwincodeURIKindSpaceCard,
    TLTwincodeURIKindProxy
};


@interface TLTwincodeURI : NSObject

@property TLTwincodeURIKind kind;
@property (nonatomic, readonly, nullable) NSUUID *twincodeId;
@property (nonatomic, readonly, nullable) NSString *twincodeOptions;
@property (nonatomic, readonly, nullable) NSString *uri;
@property (nonatomic, readonly, nullable) NSString *label;
@property (nonatomic, readonly, nullable) NSString *publicKey;

+(nonnull NSString *) PARAM_ID;
+(nonnull NSString *) CALL_ACTION;
+(nonnull NSString *) TRANSFER_ACTION;
+(nonnull NSString *) INVITE_ACTION;
+(nonnull NSString *) ACCOUNT_MIGRATION_ACTION;
+(nonnull NSString *) AUTHENTICATE_ACTION;
+(nonnull NSString *) PROXY_ACTION;
+(nonnull NSString *) CALL_PATH;
+(nonnull NSString *) SPACE_PATH;

- (nonnull instancetype)initWithKind:(TLTwincodeURIKind)kind twincodeId:(nullable NSUUID *)twincodeId twincodeOptions:(nullable NSString *)twincodeOptions uri:(nonnull NSString *)uri label:(nonnull NSString *)label publicKey:(nullable NSString *)publicKey;

@end

/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLTwincodeURI.h"
@implementation TLTwincodeURI

+ (nonnull NSString *)PARAM_ID {
    return INVITATION_PARAM_ID;
}

+ (nonnull NSString *)CALL_ACTION {
    return [NSString stringWithFormat:@"call.%@", SERVER_NAME];
}

+ (nonnull NSString *)TRANSFER_ACTION {
    return [NSString stringWithFormat:@"transfer.%@", SERVER_NAME];
}

+ (nonnull NSString *)INVITE_ACTION {
    return [NSString stringWithFormat:@"invite.%@", SERVER_NAME];
}

+ (nonnull NSString *)ACCOUNT_MIGRATION_ACTION {
    return [NSString stringWithFormat:@"account.migration.%@", SERVER_NAME];
}

+ (nonnull NSString *)AUTHENTICATE_ACTION {
    return [NSString stringWithFormat:@"authenticate.%@", SERVER_NAME];
}

+ (nonnull NSString *)PROXY_ACTION {
    return [NSString stringWithFormat:@"proxy.%@", SERVER_NAME];
}

+ (nonnull NSString *)CALL_PATH {
    return @"/call/";
}

+ (nonnull NSString *)SPACE_PATH {
    return @"/space/";
}

- (nonnull instancetype)initWithKind:(TLTwincodeURIKind)kind twincodeId:(nullable NSUUID *)twincodeId twincodeOptions:(nullable NSString *)twincodeOptions uri:(nonnull NSString *)uri label:(nonnull NSString *)label publicKey:(nullable NSString *)publicKey {
    self = [[TLTwincodeURI alloc] init];
    
    if (self) {
        _kind = kind;
        _twincodeId = twincodeId;
        _twincodeOptions = twincodeOptions;
        _uri = uri;
        _label = label;
        _publicKey = publicKey;
    }
    
    return self;
}

@end

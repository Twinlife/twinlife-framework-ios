/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLAssertion.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Interface: TLAssertValue
//

@interface TLAssertValue ()

- (nonnull instancetype)initWithParameter:(TLAssertionParameter)parameter value:(nullable NSObject *)value;

@end

//
// Implementation: TLAssertPoint
//

#undef LOG_TAG
#define LOG_TAG @"TLAssertPoint"

@implementation TLAssertPoint

- (nonnull instancetype)initWithValue:(int)value {
    DDLogVerbose(@"%@ initWithValue: %d", LOG_TAG, value);

    self = [super init];
    if (self) {
        _value = value;
    }
    return self;
}

@end

//
// Implementation: TLAssertValue
//

#undef LOG_TAG
#define LOG_TAG @"TLAssertValue"

@implementation TLAssertValue

- (nonnull instancetype)initWithParameter:(TLAssertionParameter)parameter value:(nullable NSObject *)value {
    
    self = [super init];
    if (self) {
        _parameter = parameter;
        _object = value;
    }
    return self;
}

+ (nonnull instancetype)initWithLength:(NSUInteger)length {
    
    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterLength value:[NSNumber numberWithLong:length]];
}

+ (nonnull instancetype)initWithOperationId:(int)operationId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterOperationId value:[NSNumber numberWithLong:operationId]];
}

+ (nonnull instancetype)initWithLine:(int)line {
    
    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterSourceLine value:[NSNumber numberWithLong:line]];
}

+ (nonnull instancetype)initWithSubject:(nonnull id<TLRepositoryObject>)subject {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterSubject value:(NSObject *)subject];
}

+ (nonnull instancetype)initWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincode {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterTwincodeOutbound value:(NSObject *)twincode];
}

+ (nonnull instancetype)initWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterPeerConnectionId value:peerConnectionId];
}

+ (nonnull instancetype)initWithInvocationId:(nonnull NSUUID *)invocationId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterInvocationId value:invocationId];
}

+ (nonnull instancetype)initWithResourceId:(nonnull NSUUID *)resourceId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterResourceId value:resourceId];
}

+ (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterSchemaId value:schemaId];
}

+ (nonnull instancetype)initWithEnvironmentId:(nonnull NSUUID *)environmentId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterEnvironmentId value:environmentId];
}

+ (nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterTwincodeId value:twincodeId];
}

+ (nonnull instancetype)initWithSchemaVersion:(int)version {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterSchemaVersion value:[NSNumber numberWithInt:version]];
}

+ (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode {
    
    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterErrorCode value:[NSNumber numberWithInt:errorCode]];
}

+ (nonnull instancetype)initWithSdpEncryptionStatus:(int)sdpEncryptionStatus {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterSdpEncryptionStatus value:[NSNumber numberWithInt:sdpEncryptionStatus]];
}

+ (nonnull instancetype)initWithParameter:(TLAssertionParameter)parameter value:(nullable id)value {
    
    return [[TLAssertValue alloc] initWithParameter:parameter value:(NSObject *)value];
}

+ (nonnull instancetype)initWithNumber:(int)value {
    
    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterNumber value:[NSNumber numberWithInt:value]];
}

+ (nonnull instancetype)initWithServiceId:(TLBaseServiceId)serviceId {

    return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterServiceId value:[NSNumber numberWithInt:serviceId]];
}

+ (nonnull instancetype)initWithNSError:(NSError *)error {

    if (!error) {
        return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterNSError value:0];
    } else {
        return [[TLAssertValue alloc] initWithParameter:TLAssertionParameterNSError value:[NSNumber numberWithLong:error.code]];
    }
}

@end

@implementation TLTwinlifeAssertPoint

TL_CREATE_ASSERT_POINT(SERVICE, 1)

TL_CREATE_ASSERT_POINT(EXCEPTION, 2)

TL_CREATE_ASSERT_POINT(UNEXPECTED_EXCEPTION, 3)
TL_CREATE_ASSERT_POINT(INVALID_CLASS, 4)

TL_CREATE_ASSERT_POINT(DATABASE_ERROR, 5);
TL_CREATE_ASSERT_POINT(BAD_CONFIGURATION, 6);
TL_CREATE_ASSERT_POINT(KEY_CHAIN, 7);
TL_CREATE_ASSERT_POINT(STORE_KEY_CHAIN, 8);
TL_CREATE_ASSERT_POINT(RECOVER_TAG_KEY_CHAIN, 9);
TL_CREATE_ASSERT_POINT(INVALID_TAG_KEY_CHAIN, 10);
TL_CREATE_ASSERT_POINT(MISSING_TAG_KEY_CHAIN, 11);
TL_CREATE_ASSERT_POINT(MISSING_TAG_NSDEFAULTS, 12);
TL_CREATE_ASSERT_POINT(BAD_VALUE, 14);
TL_CREATE_ASSERT_POINT(INVALID_TAG_NSDEFAULTS, 15);
TL_CREATE_ASSERT_POINT(STORE_ERROR, 16);
TL_CREATE_ASSERT_POINT(CONVERSATION_OPERATION_ERROR, 17);

@end

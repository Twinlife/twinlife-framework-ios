/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

/// Implement an assertion point and assign it a value (unique).
/// This macro is used in the @implementation part of an assertion class:
/// <pre>
/// @implementation TLTwinlifeAssertPoint
///  TL_CREATE_ASSERT_POINT(SERVICE, 1)
/// @end
/// </pre>
#define TL_CREATE_ASSERT_POINT(NAME, VALUE)                 \
+(nonnull TLAssertPoint *)NAME {                            \
    return [[TLAssertPoint alloc] initWithValue:VALUE];     \
}

/// Check with twinlifeContext/twinmeContext handler (HANDLER) whether the two objects OBJ1, OBJ2 are equal.
/// Raise the assertion POINT if the two values are not equal, add them as assertion values with the PARAM.
/// Additional TLAssertValue objects can be passed to the macro which should be terminated by nil.
/// When using this macro, the source code line number is automatically passed.
/// Exemple:
///  TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound, self.peerTwincodeOutboundId,
///     [TLExecutorAssertPoint INVALID_TWINCODE], TLAssertionParameterFactoryId,
///     [TLAssertValue initWithNumber:3], [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);
#define TL_ASSERT_EQUAL(HANDLER, OBJ1, OBJ2, POINT, PARAM, ...) \
  do { \
     id __obj1 = (OBJ1); \
     id __obj2 = (OBJ2); \
     if (!(__obj1 == nil ? __obj2 == nil : [__obj1 isEqual:__obj2])) {   \
          [HANDLER assertionWithAssertPoint:POINT,                        \
              [TLAssertValue initWithLine:__LINE__],                      \
              [TLAssertValue initWithParameter:PARAM value:__obj1],       \
              [TLAssertValue initWithParameter:PARAM value:__obj2], __VA_ARGS__, nil]; \
     } \
  } while (0)

/// Check with twinlifeContext/twinmeContext handler (HANDLER) whether the object is not null.
/// Raise the assertion POINT if the value is null.  Additional TLAssertValue objects can be passed.
/// Exemple:
///   TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutboundId,
///     [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
#define TL_ASSERT_NOT_NULL(HANDLER, OBJ1, POINT, ...) \
  do { \
     id __obj1 = (OBJ1); \
     if (__obj1 == nil) {   \
          [HANDLER assertionWithAssertPoint:POINT,                        \
              [TLAssertValue initWithLine:__LINE__], __VA_ARGS__, nil];   \
     } \
  } while (0)

/// Check with twinlifeContext/twinmeContext handler (HANDLER) whether the object OBJ1 is of the expected class CLASS.
/// Raise the assertion INVALID_CLASS with the OBJ1 value with the PARAM type if this is not the case (or if OBJ1 is nil).
/// Additional TLAssertValue objects can be passed to the macro which should be terminated by nil.
/// When using this macro, the source code line number is automatically passed.
/// Exemple:
///  TL_ASSERT_EQUAL(self.twinmeContext, twincodeOutbound, self.peerTwincodeOutboundId,
///     [TLExecutorAssertPoint INVALID_TWINCODE], TLAssertionParameterFactoryId,
///     [TLAssertValue initWithNumber:3], [TLAssertValue initWithTwincodeOutbound:twincodeOutbound], nil);
#define TL_ASSERT_IS_A(HANDLER, OBJ1, CLASS, PARAM, ...) \
  do { \
     NSObject *__obj1 = (OBJ1); \
     if (__obj1 == nil || ![__obj1 isKindOfClass:[CLASS class]]) {   \
          [HANDLER assertionWithAssertPoint:[TLTwinlifeAssertPoint INVALID_CLASS],     \
              [TLAssertValue initWithLine:__LINE__],                      \
              [TLAssertValue initWithParameter:PARAM value:__obj1], __VA_ARGS__, nil]; \
     } \
  } while (0)

/// Check with twinlifeContext/twinmeContext handler (HANDLER) whether the condition is TRUE.
/// Raise the assertion POINT if the condition is FALSE.  Additional TLAssertValue objects can be passed.
/// Exemple:
///   TL_ASSERT_NOT_NULL(twinmeContext, _peerTwincodeOutboundId,
///     [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
#define TL_ASSERT_TRUE(HANDLER, CONDITION, POINT, ...) \
  do { \
     if (!(CONDITION)) {   \
          [HANDLER assertionWithAssertPoint:POINT,                        \
              [TLAssertValue initWithLine:__LINE__], __VA_ARGS__, nil];   \
     } \
  } while (0)

/// Raise the assertion POINT with the current line information and additional TLAssertValue objects.
/// Exemple:
///   TL_ASSERTION(twinmeContext,
///     [TLExecutorAssertPoint PARAMETER], [TLAssertValue initWithNumber:1], nil);
#define TL_ASSERTION(HANDLER, POINT, ...) \
  do { \
     [HANDLER assertionWithAssertPoint:POINT,                        \
          [TLAssertValue initWithLine:__LINE__], __VA_ARGS__, nil];   \
  } while (0)

@protocol TLRepositoryObject;
@class TLTwincodeOutbound;
@class TLTwincodeInbound;

/// Enum to identify a possible assertion parameter that is reported with a failed assertion point:
/// - a parameter can be one of the following types: UUID, Integer, TwincodeInbound, TwincodeOutbound, RepositoryObject, ErrorCode
/// - NSString must never be sent with an assertion failure because we cannot be sure they do not contain user data.
///   If we do this by mistake, a NULL value is sent to the server.
typedef NS_ENUM(NSUInteger, TLAssertionParameter) {
    // Strongly typed parameters
    TLAssertionParameterSubject,
    TLAssertionParameterTwincodeInbound,
    TLAssertionParameterTwincodeOutbound,
    
    // UUID parameters
    TLAssertionParameterPeerConnectionId,
    TLAssertionParameterInvocationId,
    TLAssertionParameterSchemaId,
    TLAssertionParameterResourceId,
    TLAssertionParameterTwincodeId,
    TLAssertionParameterEnvironmentId,
    TLAssertionParameterFactoryId,
    
    // Integer parameters
    TLAssertionParameterSourceLine,    // In Objective-C, we can send the source line where the assertion is raised.
    TLAssertionParameterSchemaVersion,
    TLAssertionParameterLength,
    TLAssertionParameterOperationId,
    TLAssertionParameterErrorCode,
    TLAssertionParameterSdpEncryptionStatus,
    TLAssertionParameterServiceId,
    TLAssertionParameterNumber,       // A general purpose number (semantics is specific to the assertion point where it is used)
    TLAssertionParameterNSError       // We only send the NSError code (never send the message which could contain user data).
};

/**
 * Assertion point declaration used to report technical issues in the application.
 * It is associated with a number returned by `value` and a list of restricted
 * and well controlled values can be reported together with the failure.  The list of
 * values is voluntarily restricted to:
 * - UUID, Integer, TwincodeInbound, TwincodeOutbound, RepositoryObject, ErrorCode
 * - specific parameters: peerConnectionId, invocationId, schemaId, twincodes,
 *   schema version, length, error code, operation ids
 * Strings must never be sent with an assertion failure because we cannot be sure
 * they do not contain user data.
 *
 * it is mandatory to use the macro TL_CREATE_ASSERT_POINT for the implementation
 * because the script twinme-analysis.py extracts assertion points by scanning the source files.
 */

//
// Interface: TLAssertPoint
//

@interface TLAssertPoint : NSObject

@property (readonly) int value;

- (nonnull instancetype)initWithValue:(int)value;

@end

//
// Interface: TLAssertValue
//

@interface TLAssertValue : NSObject

@property (readonly) TLAssertionParameter parameter;
@property (readonly, nullable) NSObject *object;

+ (nonnull instancetype)initWithSubject:(nonnull id<TLRepositoryObject>)subject;
+ (nonnull instancetype)initWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincode;
+ (nonnull instancetype)initWithPeerConnectionId:(nonnull NSUUID *)peerConnectionId;
+ (nonnull instancetype)initWithInvocationId:(nonnull NSUUID *)invocationId;
+ (nonnull instancetype)initWithResourceId:(nonnull NSUUID *)resourceId;
+ (nonnull instancetype)initWithSchemaId:(nonnull NSUUID *)schemaId;
+ (nonnull instancetype)initWithEnvironmentId:(nonnull NSUUID *)environmentId;
+ (nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId;
+ (nonnull instancetype)initWithSchemaVersion:(int)version;
+ (nonnull instancetype)initWithLength:(NSUInteger)length;
+ (nonnull instancetype)initWithOperationId:(int)operationId;
+ (nonnull instancetype)initWithErrorCode:(TLBaseServiceErrorCode)errorCode;
+ (nonnull instancetype)initWithSdpEncryptionStatus:(int)sdpEncryptionStatus;
+ (nonnull instancetype)initWithLine:(int)line;
+ (nonnull instancetype)initWithParameter:(TLAssertionParameter)parameter value:(nullable id)value;
+ (nonnull instancetype)initWithNumber:(int)value;
+ (nonnull instancetype)initWithServiceId:(TLBaseServiceId)serviceId;
+ (nonnull instancetype)initWithNSError:(NSError *)error;

@end

//
// Interface: TLTwinlifeAssertPoint
//

@interface TLTwinlifeAssertPoint : TLAssertPoint

+(nonnull TLAssertPoint *)SERVICE;
+(nonnull TLAssertPoint *)EXCEPTION;
+(nonnull TLAssertPoint *)UNEXPECTED_EXCEPTION;
+(nonnull TLAssertPoint *)INVALID_CLASS;
+(nonnull TLAssertPoint *)DATABASE_ERROR;
+(nonnull TLAssertPoint *)BAD_CONFIGURATION;
+(nonnull TLAssertPoint *)KEY_CHAIN;
+(nonnull TLAssertPoint *)STORE_KEY_CHAIN;
+(nonnull TLAssertPoint *)RECOVER_TAG_KEY_CHAIN;
+(nonnull TLAssertPoint *)INVALID_TAG_KEY_CHAIN;
+(nonnull TLAssertPoint *)MISSING_TAG_KEY_CHAIN;
+(nonnull TLAssertPoint *)MISSING_TAG_NSDEFAULTS;
+(nonnull TLAssertPoint *)INVALID_TAG_NSDEFAULTS;
+(nonnull TLAssertPoint *)BAD_VALUE;
+(nonnull TLAssertPoint *)STORE_ERROR;

@end

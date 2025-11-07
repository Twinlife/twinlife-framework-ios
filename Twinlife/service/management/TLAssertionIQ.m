/*
 *  Copyright (c) 2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLAssertionIQ.h"
#import "TLManagementServiceImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"
#import "TLVersion.h"
#import "TLAssertion.h"
#import "TLRepositoryService.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLTwincodeInboundServiceImpl.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

/**
 * Assertion event request IQ.
 * This IQ reports technical information when an assertion represented by an AssertPoint failed.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"debcf418-2d3d-4477-97e1-8f7b4507ce8a",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"AssertionIQ",
 *  "namespace":"org.twinlife.schemas.account",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"applicationId", "type":"uuid"},
 *     {"name":"applicationVersionMajor", "type":"int"},
 *     {"name":"applicationVersionMinor", "type":"int"},
 *     {"name":"applicationVersionPatch", "type":"int"},
 *     {"name":"assertion", "type":"int"},
 *     {"name":"timestamp", "type":"long"},
 *     {"name":"valueCount", "type":"int"},[
 *       {"name":"type", ["int", "long", "uuid", "class", ]}
 *       {"name":"value", "type": ["long", "uuid", "class"]}
 *     ]
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLAssertionIQSerializer
//

#undef LOG_TAG
#define LOG_TAG @"TLAssertionIQSerializer"

@implementation TLAssertionIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLAssertionIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];

    TLAssertionIQ *assertionIQ = (TLAssertionIQ *)object;
    [encoder writeUUID:assertionIQ.applicationId];
    [encoder writeInt:assertionIQ.applicationVersion.major];
    [encoder writeInt:assertionIQ.applicationVersion.minor];
    [encoder writeInt:assertionIQ.applicationVersion.patch];
    [encoder writeInt:assertionIQ.assertPoint.value];
    [encoder writeLong:assertionIQ.timestamp];
    if (!assertionIQ.values) {
        [encoder writeInt:0];
    } else {
        [encoder writeInt:(int)assertionIQ.values.count];
        for (TLAssertValue *value in assertionIQ.values) {
            int kind = 0;

            switch (value.parameter) {
                case TLAssertionParameterPeerConnectionId:
                    kind = (1 << 8);
                    break;
                case TLAssertionParameterInvocationId:
                    kind = (2 << 8);
                    break;
                case TLAssertionParameterSchemaId:
                    kind = (3 << 8);
                    break;
                case TLAssertionParameterResourceId:
                    kind = (4 << 8);
                    break;
                case TLAssertionParameterTwincodeId:
                    kind = (5 << 8);
                    break;
                case TLAssertionParameterSchemaVersion:
                    kind = (6 << 8);
                    break;
                case TLAssertionParameterLength:
                    kind = (7 << 8);
                    break;
                case TLAssertionParameterOperationId:
                    kind = (8 << 8);
                    break;
                case TLAssertionParameterErrorCode:
                    kind = (9 << 8);
                    break;
                case TLAssertionParameterSdpEncryptionStatus:
                    kind = (10 << 8);
                    break;
                case TLAssertionParameterSourceLine:
                    kind = (11 << 8);
                    break;
                case TLAssertionParameterEnvironmentId:
                    kind = (12 << 8);
                    break;
                case TLAssertionParameterFactoryId:
                    kind = (13 << 8);
                    break;
                case TLAssertionParameterNumber:
                    kind = (14 << 8);
                    break;
                case TLAssertionParameterServiceId:
                    kind = (15 << 8);
                    break;
                case TLAssertionParameterNSError:
                    kind = (16 << 8);
                    break;
                case TLAssertionParameterTwincodeInbound:
                case TLAssertionParameterTwincodeOutbound:
                case TLAssertionParameterSubject:
                    kind = 0;
                    break;
            }
            if ([value.object isKindOfClass:[NSNumber class]]) {
                if (value.parameter == TLAssertionParameterErrorCode) {
                    TLBaseServiceErrorCode errorCode = (TLBaseServiceErrorCode) ((NSNumber *)value.object).intValue;
                    [encoder writeInt:kind | 1];
                    [encoder writeInt:[TLBaseService fromErrorCode:errorCode]];
                    [encoder writeInt:(int) errorCode];

                } else {
                    [encoder writeInt:kind | 2];
                    [encoder writeLong:((NSNumber *)value.object).longLongValue];
                }
            } else if ([value.object isKindOfClass:[TLTwincodeOutbound class]]) {
                [encoder writeInt:kind | 5];
                [self encodeWithTwincodeOutbound:(TLTwincodeOutbound *)value.object encoder:encoder];
            } else if ([value.object isKindOfClass:[TLTwincodeInbound class]]) {
                [encoder writeInt:kind | 6];
                [self encodeWithTwincodeInbound:(TLTwincodeInbound *)value.object encoder:encoder];
            } else if ([value.object isKindOfClass:[NSUUID class]]) {
                [encoder writeInt:kind | 3];
                [encoder writeUUID:(NSUUID *)value.object];
            } else if ([value.object conformsToProtocol:@protocol(TLRepositoryObject)]) {
                [encoder writeInt:8];
                [self encodeWithSubject:(id<TLRepositoryObject>)value.object encoder:encoder];
            } else {
                // Don't send any other types
                [encoder writeInt:kind];
            }
        }
    }
    if (assertionIQ.exception == nil) {
        [encoder writeEnum:0];
    } else {
        [encoder writeEnum:2];
        [encoder writeString:assertionIQ.exception.name];
        [encoder writeInt:0];
        // Stacktrace is useless because we almost never succeed in analysing addresses.
    }
}

/// Send the twincode IN and associated OUT (allows to verify consistency between them).
- (void)encodeWithTwincodeInbound:(nullable TLTwincodeInbound *)twincodeInbound encoder:(nonnull id<TLEncoder>)encoder {
    
    if (!twincodeInbound) {
        [encoder writeZero];
    } else {
        [encoder writeInt:1];
        [encoder writeUUID:twincodeInbound.uuid];
        [encoder writeUUID:twincodeInbound.twincodeOutbound.uuid];
    }
}

/// Send the twincode OUT with flags (allows to verify flags consistency).
- (void)encodeWithTwincodeOutbound:(nullable TLTwincodeOutbound *)twincodeOutbound encoder:(nonnull id<TLEncoder>)encoder {
 
    if (!twincodeOutbound) {
        [encoder writeZero];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:twincodeOutbound.uuid];
        [encoder writeInt:twincodeOutbound.flags];
    }
}

/// Send the subject schema ID which tells what kind of object it is (Profil, Contact, Group, ...)
/// Send the IN, OUT and PEER OUT twincodes.
- (void)encodeWithSubject:(nullable id<TLRepositoryObject>)subject encoder:(nonnull id<TLEncoder>)encoder {
   
    if (!subject) {
        [encoder writeZero];
    } else {
        [encoder writeEnum:1];
        [encoder writeUUID:subject.identifier.schemaId];
        [self encodeWithTwincodeInbound:subject.twincodeInbound encoder:encoder];
        [self encodeWithTwincodeOutbound:subject.twincodeOutbound encoder:encoder];
        [self encodeWithTwincodeOutbound:subject.peerTwincodeOutbound encoder:encoder];
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];
}

@end

//
// Implementation: TLAssertionIQ
//

#undef LOG_TAG
#define LOG_TAG @"TLAssertionIQ"

@implementation TLAssertionIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId applicationId:(nonnull NSUUID *)applicationId applicationVersion:(nonnull TLVersion *)applicationVersion assertPoint:(nonnull TLAssertPoint *)assertPoint values:(nullable NSArray<TLAssertValue *> *)values exception:(nullable NSException *)exception timestamp:(int64_t)timestamp {
    DDLogVerbose(@"%@ initWithSerializer requestId: %lld assertPoint: %@ values: %@ exception: %@", LOG_TAG, requestId, assertPoint, values, exception);

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _applicationId = applicationId;
        _applicationVersion = applicationVersion;
        _assertPoint = assertPoint;
        _values = values;
        _exception = exception;
        _timestamp = timestamp;
    }
    return self;
}

@end

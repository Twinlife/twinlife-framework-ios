/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLSessionTerminateIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Session Terminate request IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"342d4d82-d91f-437b-bcf2-a2051bd94ac1",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SessionTerminateIQ",
 *  "namespace":"org.twinlife.schemas.calls",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"to", "type":"string"},
 *     {"name":"sessionId", "type":"uuid"},
 *     {"name":"reason", "type":"enum"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLSessionTerminateIQSerializer
//

@implementation TLSessionTerminateIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLSessionTerminateIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSessionTerminateIQ *sessionTerminateIQ = (TLSessionTerminateIQ *)object;
    [encoder writeString:sessionTerminateIQ.to];
    [encoder writeUUID:sessionTerminateIQ.sessionId];
    switch (sessionTerminateIQ.reason) {
        case TLPeerConnectionServiceTerminateReasonSuccess:
            [encoder writeEnum:0];
            break;

        case TLPeerConnectionServiceTerminateReasonBusy:
            [encoder writeEnum:1];
            break;

        case TLPeerConnectionServiceTerminateReasonCancel:
            [encoder writeEnum:2];
            break;

        case TLPeerConnectionServiceTerminateReasonConnectivityError:
            [encoder writeEnum:3];
            break;

        case TLPeerConnectionServiceTerminateReasonDecline:
            [encoder writeEnum:4];
            break;

        case TLPeerConnectionServiceTerminateReasonDisconnected:
            [encoder writeEnum:5];
            break;

        case TLPeerConnectionServiceTerminateReasonGeneralError:
            [encoder writeEnum:6];
            break;

        case TLPeerConnectionServiceTerminateReasonGone:
            [encoder writeEnum:7];
            break;

        case TLPeerConnectionServiceTerminateReasonNotAuthorized:
            [encoder writeEnum:8];
            break;

        case TLPeerConnectionServiceTerminateReasonRevoked:
            [encoder writeEnum:9];
            break;

        case TLPeerConnectionServiceTerminateReasonTimeout:
            [encoder writeEnum:10];
            break;
        case TLPeerConnectionServiceTerminateReasonTransferDone:
            [encoder writeEnum:12];
            break;
        case TLPeerConnectionServiceTerminateReasonSchedule:
            [encoder writeEnum:13];
            break;
        case TLPeerConnectionServiceTerminateReasonMerge:
            [encoder writeEnum:14];
            break;
        case TLPeerConnectionServiceTerminateReasonNoPrivateKey:
            [encoder writeEnum:15];
            break;
        case TLPeerConnectionServiceTerminateReasonNoSecretKey:
            [encoder writeEnum:16];
            break;
        case TLPeerConnectionServiceTerminateReasonDecryptError:
            [encoder writeEnum:17];
            break;
        case TLPeerConnectionServiceTerminateReasonEncryptError:
            [encoder writeEnum:18];
            break;
        case TLPeerConnectionServiceTerminateReasonNoPublicKey:
            [encoder writeEnum:19];
            break;
        case TLPeerConnectionServiceTerminateReasonNotEncrypted:
            [encoder writeEnum:20];
            break;
        case TLPeerConnectionServiceTerminateReasonUnknown:
        default:
            [encoder writeEnum:11];
            break;
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    NSString *to = [decoder readString];
    NSUUID *sessionId = [decoder readUUID];
    TLPeerConnectionServiceTerminateReason reason;

    switch ([decoder readEnum]) {
        case 0:
            reason = TLPeerConnectionServiceTerminateReasonSuccess;
            break;

        case 1:
            reason = TLPeerConnectionServiceTerminateReasonBusy;
            break;

        case 2:
            reason = TLPeerConnectionServiceTerminateReasonCancel;
            break;

        case 3:
            reason = TLPeerConnectionServiceTerminateReasonConnectivityError;
            break;

        case 4:
            reason = TLPeerConnectionServiceTerminateReasonDecline;
            break;

        case 5:
            reason = TLPeerConnectionServiceTerminateReasonDisconnected;
            break;

        case 6:
            reason = TLPeerConnectionServiceTerminateReasonGeneralError;
            break;

        case 7:
            reason = TLPeerConnectionServiceTerminateReasonGone;
            break;

        case 8:
            reason = TLPeerConnectionServiceTerminateReasonNotAuthorized;
            break;

        case 9:
            reason = TLPeerConnectionServiceTerminateReasonRevoked;
            break;

        case 10:
            reason = TLPeerConnectionServiceTerminateReasonTimeout;
            break;

        case 12:
            reason = TLPeerConnectionServiceTerminateReasonTransferDone;
            break;
        case 13:
            reason = TLPeerConnectionServiceTerminateReasonSchedule;
            break;
        case 14:
            reason = TLPeerConnectionServiceTerminateReasonMerge;
            break;
        case 15:
            reason = TLPeerConnectionServiceTerminateReasonNoPrivateKey;
            break;
        case 16:
            reason = TLPeerConnectionServiceTerminateReasonNoSecretKey;
            break;
        case 17:
            reason = TLPeerConnectionServiceTerminateReasonDecryptError;
            break;
        case 18:
            reason = TLPeerConnectionServiceTerminateReasonEncryptError;
            break;
        case 19:
            reason = TLPeerConnectionServiceTerminateReasonNoPublicKey;
            break;
        case 20:
            reason = TLPeerConnectionServiceTerminateReasonNotEncrypted;
            break;
        case 11:
        default:
            reason = TLPeerConnectionServiceTerminateReasonUnknown;
    }

    return [[TLSessionTerminateIQ alloc] initWithSerializer:self requestId:iq.requestId to:to sessionId:sessionId reason:reason];
}

@end

//
// Implementation: TLSessionTerminateIQ
//

@implementation TLSessionTerminateIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId to:(nonnull NSString *)to sessionId:(nonnull NSUUID *)sessionId reason:(TLPeerConnectionServiceTerminateReason)reason {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _to = to;
        _sessionId = sessionId;
        _reason = reason;
    }
    return self;
}

@end

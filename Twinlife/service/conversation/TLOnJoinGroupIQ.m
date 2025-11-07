/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLOnJoinGroupIQ.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * OnJoinGroupIQ IQ.
 * <p>
 * Schema version 2
 *  Date: 2024/08/28
 *
 * <pre>
 * {
 *  "schemaId":"3d175317-f1f7-4cd1-abd8-2f538b342e41",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"JoinGroupIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"status", "type":"int"}
 *     0 => {}
 *     1 => {{"name":"permissions", "type":"long"}
 *           {"name":"inviterMemberTwincodeOutboundId", "type":"uuid"},
 *           {"name":"inviterPermissions", "type":"long"},
 *           {"name":"inviterPublicKey", "type":[null, "String"]},
 *           {"name":"inviterSecret", "type":[null, "bytes"]}}
 *           {"name":"inviterSalt", "type":[null, "String"]},
 *           {"name":"inviterSignature", "type":[null, "String"]}}
 *           {"name":"count", "type":"int"},
 *            [{"name":"memberTwincodeId", "type":"uuid"},
 *             {"name":"permissions", "type":"long"},
 *             {"name":"publicKey", "type":[null, "String"}]}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLOnJoinGroupMemberInfo
//

@implementation TLOnJoinGroupMemberInfo

- (nonnull instancetype)initWithTwincodeId:(nonnull NSUUID *)twincodeId publicKey:(nullable NSString *)publicKey permissions:(int64_t)permissions {

    self = [super init];
    if (self) {
        _memberTwincodeId = twincodeId;
        _publicKey = publicKey;
        _permissions = permissions;
    }
    return self;
}

@end

//
// Implementation: TLOnJoinGroupIQSerializer
//

@implementation TLOnJoinGroupIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLOnJoinGroupIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLOnJoinGroupIQ *onJoinGroupIQ = (TLOnJoinGroupIQ *)object;

    [encoder writeInt:onJoinGroupIQ.deviceState];
    if (onJoinGroupIQ.inviterTwincodeId == nil) {
        // Invitation rejected and refused by the peer.
        [encoder writeEnum:0];
    } else {
        // User joined the group.
        [encoder writeEnum:1];
        [encoder writeLong:onJoinGroupIQ.permissions];
        [encoder writeUUID:onJoinGroupIQ.inviterTwincodeId];
        [encoder writeLong:onJoinGroupIQ.inviterPermissions];
        [encoder writeOptionalString:onJoinGroupIQ.publicKey];
        [encoder writeOptionalData:onJoinGroupIQ.secretKey];
        [encoder writeOptionalString:onJoinGroupIQ.inviterSalt];
        [encoder writeOptionalString:onJoinGroupIQ.inviterSignature];
        if (onJoinGroupIQ.members == nil) {
            [encoder writeInt:0];
        } else {
            [encoder writeInt:(int)onJoinGroupIQ.members.count];
            for (TLOnJoinGroupMemberInfo *memberInfo in onJoinGroupIQ.members) {
                [encoder writeUUID:memberInfo.memberTwincodeId];
                [encoder writeLong:memberInfo.permissions];
                [encoder writeOptionalString:memberInfo.publicKey];
            }
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    int deviceState = [decoder readInt];
    NSMutableArray<TLOnJoinGroupMemberInfo *> *members = nil;
    int64_t permissions = 0;
    int64_t inviterPermissions = 0;
    NSUUID *inviterTwincodeId = nil;
    NSString *publicKey = nil;
    NSData *secretKey = nil;
    NSString *inviterSalt = nil;
    NSString *inviterSignature = nil;
    if ([decoder readEnum] != 0) {
        permissions = [decoder readLong];
        inviterTwincodeId = [decoder readUUID];
        inviterPermissions = [decoder readLong];
        publicKey = [decoder readOptionalString];
        secretKey = [decoder readOptionalData];
        inviterSalt = [decoder readOptionalString];
        inviterSignature = [decoder readOptionalString];
        int count = [decoder readInt];
        if (count > 0) {
            members = [[NSMutableArray alloc] initWithCapacity:count];
            while (count > 0) {
                count--;
                NSUUID *memberTwincodeId = [decoder readUUID];
                long memberPermissions = [decoder readLong];
                NSString *publicKey = [decoder readOptionalString];

                [members addObject:[[TLOnJoinGroupMemberInfo alloc] initWithTwincodeId:memberTwincodeId publicKey:publicKey permissions:memberPermissions]];
            }
        }
    }

    return [[TLOnJoinGroupIQ alloc] initWithSerializer:self requestId:requestId deviceState:deviceState inviterTwincodeId:inviterTwincodeId inviterPermissions:inviterPermissions publicKey:publicKey secretKey:secretKey permissions:permissions inviterSalt:inviterSalt inviterSignature:inviterSignature members:members];
}

@end

//
// Implementation: TLOnJoinGroupIQ
//

@implementation TLOnJoinGroupIQ

static TLOnJoinGroupIQSerializer *IQ_ON_JOIN_GROUP_SERIALIZER_2;
static const int IQ_ON_JOIN_GROUP_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_ON_JOIN_GROUP_SERIALIZER_2 = [[TLOnJoinGroupIQSerializer alloc] initWithSchema:@"3d175317-f1f7-4cd1-abd8-2f538b342e41" schemaVersion:IQ_ON_JOIN_GROUP_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_JOIN_GROUP_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_ON_JOIN_GROUP_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_ON_JOIN_GROUP_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId deviceState:(int)deviceState inviterTwincodeId:(nullable NSUUID *)inviterTwincodeId inviterPermissions:(int64_t)inviterPermissions publicKey:(nullable NSString *)publicKey secretKey:(nullable NSData *)secretKey permissions:(int64_t)permissions inviterSalt:(nullable NSString *)inviterSalt inviterSignature:(nullable NSString *)inviterSignature members:(nullable NSMutableArray<TLOnJoinGroupMemberInfo *> *)members {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _deviceState = deviceState;
        _publicKey = publicKey;
        _secretKey = secretKey;
        _permissions = permissions;
        _inviterTwincodeId = inviterTwincodeId;
        _inviterPermissions = inviterPermissions;
        _inviterSalt = inviterSalt;
        _inviterSignature = inviterSignature;
        _members = members;
    }
    return self;
}

@end

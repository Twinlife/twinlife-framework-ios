/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdatePermissionsIQ.h"
#import "TLOnPushIQ.h"
#import "TLSerializerFactory.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * UpdatePermissions IQ.
 * <p>
 * Schema version 2
 *  Date: 2024/09/10
 *<pre>
 * {
 *  "schemaId":"3b5dc8a2-2679-43f2-badf-ec61c7eed9f0",
 *  "schemaVersion":"2",
 *
 *  "type":"record",
 *  "name":"UpdateGroupMemberIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields":[
 *   {"name":"group", "type":"uuid"}
 *   {"name":"member", "type":"uuid"}
 *   {"name":"permissions", "type":"long"}
 *  ]
 * }
 * </pre>
 */

//
// Implementation: TLUpdatePermissionsIQSerializer
//

@implementation TLUpdatePermissionsIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdatePermissionsIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdatePermissionsIQ *updatePermissionsIQ = (TLUpdatePermissionsIQ *)object;
    [encoder writeUUID:updatePermissionsIQ.groupTwincodeId];
    [encoder writeUUID:updatePermissionsIQ.memberTwincodeId];
    [encoder writeLong:updatePermissionsIQ.permissions];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {

    int64_t requestId = [decoder readLong];
    NSUUID *groupTwincodeId = [decoder readUUID];
    NSUUID *memberTwincodeId = [decoder readUUID];
    int64_t permissions = [decoder readLong];

    return [[TLUpdatePermissionsIQ alloc] initWithSerializer:self requestId:requestId groupTwincodeId:groupTwincodeId memberTwincodeId:memberTwincodeId permissions:permissions];
}

@end

//
// Implementation: TLUpdatePermissionsIQ
//

@implementation TLUpdatePermissionsIQ

static TLUpdatePermissionsIQSerializer *IQ_UPDATE_PERMISSIONS_SERIALIZER_2;
static const int IQ_UPDATE_PERMISSIONS_SCHEMA_VERSION_2 = 2;

+ (void)initialize {
    
    IQ_UPDATE_PERMISSIONS_SERIALIZER_2 = [[TLUpdatePermissionsIQSerializer alloc] initWithSchema:@"3b5dc8a2-2679-43f2-badf-ec61c7eed9f0" schemaVersion:IQ_UPDATE_PERMISSIONS_SCHEMA_VERSION_2];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_UPDATE_PERMISSIONS_SERIALIZER_2.schemaId;
}

+ (int)SCHEMA_VERSION_2 {

    return IQ_UPDATE_PERMISSIONS_SERIALIZER_2.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_2 {
    
    return IQ_UPDATE_PERMISSIONS_SERIALIZER_2;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId groupTwincodeId:(nonnull NSUUID *)groupTwincodeId memberTwincodeId:(nonnull NSUUID *)memberTwincodeId permissions:(int64_t)permissions {

    self = [super initWithSerializer:serializer requestId:requestId];
    if (self) {
        _groupTwincodeId = groupTwincodeId;
        _memberTwincodeId = memberTwincodeId;
        _permissions = permissions;
    }
    return self;
}

@end

/**
 * OnUpdatePermissionsIQ IQ.
 *
 * Schema version 1
 *  Date: 2024/06/07
 *
 * <pre>
 * {
 *  "schemaId":"f9a9c212-3364-491e-b559-34cf8b6c6a44",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"OnUpdatePermissionsIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"deviceState", "type":"byte"},
 *     {"name":"receivedTimestamp", "type":"long"}
 *  ]
 * }
 *
 * </pre>
 */

//
// Implementation: TLOnUpdatePermissionsIQ
//

@implementation TLOnUpdatePermissionsIQ

static TLOnPushIQSerializer *IQ_ON_UPDATE_PERMISSIONS_SERIALIZER_1;
static const int IQ_ON_UPDATE_PERMISSIONS_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_ON_UPDATE_PERMISSIONS_SERIALIZER_1 = [[TLOnPushIQSerializer alloc] initWithSchema:@"f9a9c212-3364-491e-b559-34cf8b6c6a44" schemaVersion:IQ_ON_UPDATE_PERMISSIONS_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_ON_UPDATE_PERMISSIONS_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_ON_UPDATE_PERMISSIONS_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *)SERIALIZER_1 {
    
    return IQ_ON_UPDATE_PERMISSIONS_SERIALIZER_1;
}

@end

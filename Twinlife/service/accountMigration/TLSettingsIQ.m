/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLSettingsIQ.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Settings IQ.
 *
 * Schema version 1
 * <pre>
 * {
 *  "schemaId":"09557d03-3af7-4151-aa60-c6a4b992e18b",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"SettingsIQ",
 *  "namespace":"org.twinlife.schemas.deviceMigration",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"hasPeerSettings", "type":"boolean"},
 *     {"name":"count", "type":"int"},
 *     [{"name":"settingId", "type":"uuid"},
 *      {"name":"value", "type":"string"}]
 *  ]
 * }
 *
 * </pre>
 */

#define MAX_SIZE_PER_SETTING 256

@implementation TLSettingsIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {
    
    return [super initWithSchema:schema schemaVersion:schemaVersion class:TLSettingsIQ.class];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLSettingsIQ *settingsIQ = (TLSettingsIQ *)object;
    
    [encoder writeBoolean:settingsIQ.hasPeerSettings];
    [encoder writeInt:(int)settingsIQ.settings.count];
    [settingsIQ.settings enumerateKeysAndObjectsUsingBlock:^(NSUUID * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [encoder writeUUID:key];
        [encoder writeString:obj];
    }];
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    
    TLBinaryPacketIQ *iq = (TLBinaryPacketIQ *)[super deserializeWithSerializerFactory:serializerFactory decoder:decoder];
    
    BOOL hasPeerSettings = [decoder readBoolean];
    
    NSMutableDictionary<NSUUID *, NSString *> *settings = [[NSMutableDictionary alloc] init];
    int count = [decoder readInt];
    while(count > 0){
        NSUUID *identifier = [decoder readUUID];
        NSString *value = [decoder readString];
        settings[identifier] = value;
        count--;
    }
    
    return [[TLSettingsIQ alloc] initWithSerializer:self requestId:iq.requestId hasPeerSettings:hasPeerSettings settings:settings];
}

@end

@implementation TLSettingsIQ

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId hasPeerSettings:(BOOL)hasPeerSettings settings:(nonnull NSDictionary<NSUUID *,NSString *> *)settings  {
    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _hasPeerSettings = hasPeerSettings;
        _settings = settings;
    }
    
    return self;
}


- (long)bufferSize {
    return super.bufferSize + self.settings.count * MAX_SIZE_PER_SETTING;
}

- (void)appendTo:(nonnull NSMutableString *)string {
    
    [super appendTo:string];
    [string appendFormat:@" hasPeerSettings: %d settings: %@", self.hasPeerSettings, self.settings];
}

- (nonnull NSString *)description {
    
    NSMutableString *description = [[NSMutableString alloc] initWithString:@"TLSettingsIQ "];
    [self appendTo:description];
    return description;
}

@end

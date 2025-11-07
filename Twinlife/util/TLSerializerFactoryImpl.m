/*
 *  Copyright (c) 2015-2020 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Christian Jacquemot (Christian.Jacquemot@twinlife-systems.com)
 *   Chedi Baccari (Chedi.Baccari@twinlife-systems.com)
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import "TLSerializerFactoryImpl.h"
#import "TLSerializer.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

//
// Implementation: TLSerializerKey
//

@implementation TLSerializerKey

- (instancetype)initWithSchemaId:(NSUUID *)schemaId schemaVersion:(long)schemaVersion {
    
    self = [super init];
    if (self) {
        _schemaId = schemaId;
        _schemaVersion = schemaVersion;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return true;
    }
    if (!object || ![object isKindOfClass:[TLSerializerKey class]]) {
        return false;
    }
    TLSerializerKey* serializerKey = (TLSerializerKey *) object;
    return [serializerKey.schemaId isEqual:self.schemaId] && serializerKey.schemaVersion == self.schemaVersion;
}

- (NSUInteger)hash {
    
    NSUInteger result = 17;
    result = 31 * result + self.schemaId.hash;
    result = 31 * result + self.schemaVersion;
    return result;
}

- (id)copyWithZone:(NSZone *)zone {
    
    return self;
}

@end

//
// Implementation: TLSerializerFactory
//

#undef LOG_TAG
#define LOG_TAG @"TLSerializerFactory"

@implementation TLSerializerFactory

- (instancetype)init {
    DDLogVerbose(@"%@ init", LOG_TAG);
    
    self = [super init];
    if (self) {
        _class2Serializers = [[NSMutableDictionary alloc] init];
        _serializers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - TLSerializerFactory

- (TLSerializer *)getSerializerWithObject:(NSObject *)object {
    DDLogVerbose(@"%@ getSerializerWithObject: %@", LOG_TAG, object);
    
    @synchronized(self) {
        return self.class2Serializers[NSStringFromClass([object class])];
    }
}

- (TLSerializer *)getSerializerWithSchemaId:(NSUUID *)schemaId schemaVersion:(int)schemaVersion {
    DDLogVerbose(@"%@ getSerializerWithSchemaId: %@ schemaVersion: %d", LOG_TAG, schemaId, schemaVersion);
    
    TLSerializerKey *serializerKey = [[TLSerializerKey alloc] initWithSchemaId:schemaId schemaVersion:schemaVersion];
    @synchronized(self) {
        return self.serializers[serializerKey];
    }
}

#pragma mark - TLSerializerFactory+Impl

- (void)addSerializer:(TLSerializer *)serializer {
    DDLogVerbose(@"%@ addSerializer: %@", LOG_TAG, serializer);
    
    @synchronized(self) {
        TLSerializerKey *serializerKey = [[TLSerializerKey alloc] initWithSchemaId:serializer.schemaId schemaVersion:serializer.schemaVersion];
        self.serializers[serializerKey] = serializer;
        self.class2Serializers[NSStringFromClass(serializer.clazz)] = serializer;
    }
}

- (void)addSerializers:(NSArray<TLSerializer *> *)serializers {
    DDLogVerbose(@"%@ addSerializers: %@", LOG_TAG, serializers);
    
    @synchronized(self) {
        for (TLSerializer *serializer in serializers) {
            TLSerializerKey *serializerKey = [[TLSerializerKey alloc] initWithSchemaId:serializer.schemaId schemaVersion:serializer.schemaVersion];
            self.serializers[serializerKey] = serializer;
            self.class2Serializers[NSStringFromClass(serializer.clazz)] = serializer;
        }
    }
}

@end

/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLUpdateAnnotationsIQ.h"
#import "TLSerializerFactory.h"
#import "TLConversationService.h"
#import "TLDescriptorImpl.h"

#import "TLDecoder.h"
#import "TLEncoder.h"

/**
 * Update annotation IQ.
 * <p>
 * Schema version 1
 *  Date: 2023/01/10
 *
 * <pre>
 * {
 *  "schemaId":"a4bb8ccd-0b4b-43be-80ca-4714bedc2f79",
 *  "schemaVersion":"1",
 *
 *  "type":"record",
 *  "name":"UpdateAnnotationIQ",
 *  "namespace":"org.twinlife.schemas.conversation",
 *  "super":"org.twinlife.schemas.BinaryPacketIQ"
 *  "fields": [
 *     {"name":"twincodeOutboundId", "type":"uuid"}
 *     {"name":"sequenceId", "type":"long"}
 *     {"name":"mode", "type":"int"},
 *     {"name":"peerAnnotationCount", "type":"int"},
 *     {"name":"peerAnnotations": [
 *       {"name":"twincodeOutboundId", "type":"uuid"}
 *       {"name":"annotationCount", "type":"int"},
 *       {"name":"annotations": [
 *         {"name":"annotationType", "type":"int"}
 *         {"name":"annotationValue", "type":"int"}
 *       ]}
 *     ]}
 * }
 *
 * </pre>
 */

//
// Implementation: TLUpdateAnnotationsIQSerializer
//

@implementation TLUpdateAnnotationsIQSerializer

- (nonnull instancetype)initWithSchema:(nonnull NSString *)schema schemaVersion:(int)schemaVersion {

    return [super initWithSchema:schema schemaVersion:schemaVersion class:[TLUpdateAnnotationsIQ class]];
}

- (void)serializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory encoder:(id<TLEncoder>)encoder object:(NSObject *)object {
    
    [super serializeWithSerializerFactory:serializerFactory encoder:encoder object:object];
    
    TLUpdateAnnotationsIQ *updateAnnotationsIQ = (TLUpdateAnnotationsIQ *)object;
    [encoder writeUUID:updateAnnotationsIQ.descriptorId.twincodeOutboundId];
    [encoder writeLong:updateAnnotationsIQ.descriptorId.sequenceId];
    switch (updateAnnotationsIQ.updateType) {
        case TLUpdateAnnotationsUpdateTypeSet:
            [encoder writeEnum:1];
            break;

        case TLUpdateAnnotationsUpdateTypeAdd:
            [encoder writeEnum:2];
            break;

        case TLUpdateAnnotationsUpdateTypeRemove:
            [encoder writeEnum:3];
            break;

        default:
            @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];

    }

    [encoder writeInt:(int)updateAnnotationsIQ.annotations.count];
    for (NSUUID *peerTwincodeId in updateAnnotationsIQ.annotations) {
        NSArray<TLDescriptorAnnotation *> *list = updateAnnotationsIQ.annotations[peerTwincodeId];
        
        [encoder writeUUID:peerTwincodeId];
        [encoder writeInt:(int)list.count];
        for (TLDescriptorAnnotation *annotation in list) {
            switch (annotation.type) {
                case TLDescriptorAnnotationTypeForward:
                    [encoder writeEnum:1];
                    break;

                case TLDescriptorAnnotationTypeForwarded:
                    [encoder writeEnum:2];
                    break;

                case TLDescriptorAnnotationTypeSave:
                    [encoder writeEnum:3];
                    break;

                case TLDescriptorAnnotationTypeLike:
                    [encoder writeEnum:4];
                    break;

                case TLDescriptorAnnotationTypePoll:
                    [encoder writeEnum:5];
                    break;

                default:
                    @throw [NSException exceptionWithName:@"TLEncoderException" reason:nil userInfo:nil];

            }
            [encoder writeInt:annotation.value];
        }
    }
}

- (NSObject *)deserializeWithSerializerFactory:(TLSerializerFactory *)serializerFactory decoder:(id<TLDecoder>)decoder {
    int64_t requestId = [decoder readLong];
    NSUUID *twincodeOutboundId = [decoder readUUID];
    int64_t sequenceId = [decoder readLong];
    TLDescriptorId *descriptorId = [[TLDescriptorId alloc] initWithTwincodeOutboundId:twincodeOutboundId sequenceId:sequenceId];
    TLUpdateAnnotationsUpdateType updateType;
    switch ([decoder readEnum]) {
        case 1:
            updateType = TLUpdateAnnotationsUpdateTypeSet;
            break;

        case 2:
            updateType = TLUpdateAnnotationsUpdateTypeAdd;
            break;

        case 3:
            updateType = TLUpdateAnnotationsUpdateTypeRemove;
            break;

        default:
            @throw [NSException exceptionWithName:@"TLDecoderException" reason:nil userInfo:nil];

    }
    int count = [decoder readInt];
    NSMutableDictionary<NSUUID *, NSMutableArray<TLDescriptorAnnotation *> *> *peerAnnotations = [[NSMutableDictionary alloc] initWithCapacity:count];
    while (count > 0) {
        count--;

        NSUUID *peerTwincodeId = [decoder readUUID];
        int annotationCount = [decoder readInt];
        NSMutableArray<TLDescriptorAnnotation *> *list = [[NSMutableArray alloc] initWithCapacity:annotationCount];
        [peerAnnotations setObject:list forKey:peerTwincodeId];
        while (annotationCount > 0) {
            annotationCount--;

            int kind = [decoder readEnum];
            int value = [decoder readInt];
            switch (kind) {
                case 1:
                    [list addObject:[[TLDescriptorAnnotation alloc] initWithType:TLDescriptorAnnotationTypeForward value:value count:0]];
                    break;

                case 2:
                    [list addObject:[[TLDescriptorAnnotation alloc] initWithType:TLDescriptorAnnotationTypeForwarded value:value count:0]];
                    break;

                case 3:
                    [list addObject:[[TLDescriptorAnnotation alloc] initWithType:TLDescriptorAnnotationTypeSave value:value count:0]];
                    break;

                case 4:
                    [list addObject:[[TLDescriptorAnnotation alloc] initWithType:TLDescriptorAnnotationTypeLike value:value count:0]];
                    break;

                case 5:
                    [list addObject:[[TLDescriptorAnnotation alloc] initWithType:TLDescriptorAnnotationTypePoll value:value count:0]];
                    break;

                default:
                    // Ignore this annotation
                    break;
            }
        }
    }

    return [[TLUpdateAnnotationsIQ alloc] initWithSerializer:self requestId:requestId descriptorId:descriptorId updateType:updateType annotations:peerAnnotations];
}

@end

//
// Implementation: TLUpdateAnnotationsIQ
//

@implementation TLUpdateAnnotationsIQ

static TLUpdateAnnotationsIQSerializer *IQ_UPDATE_ANNOTATIONS_SERIALIZER_1;
static const int IQ_UPDATE_ANNOTATIONS_SCHEMA_VERSION_1 = 1;

+ (void)initialize {
    
    IQ_UPDATE_ANNOTATIONS_SERIALIZER_1 = [[TLUpdateAnnotationsIQSerializer alloc] initWithSchema:@"a4bb8ccd-0b4b-43be-80ca-4714bedc2f79" schemaVersion:IQ_UPDATE_ANNOTATIONS_SCHEMA_VERSION_1];
}

+ (nonnull NSUUID *)SCHEMA_ID {
    
    return IQ_UPDATE_ANNOTATIONS_SERIALIZER_1.schemaId;
}

+ (int)SCHEMA_VERSION_1 {

    return IQ_UPDATE_ANNOTATIONS_SERIALIZER_1.schemaVersion;
}

+ (nonnull TLBinaryPacketIQSerializer *) SERIALIZER_1 {
    
    return IQ_UPDATE_ANNOTATIONS_SERIALIZER_1;
}

- (nonnull instancetype)initWithSerializer:(nonnull TLBinaryPacketIQSerializer *)serializer requestId:(int64_t)requestId descriptorId:(nonnull TLDescriptorId *)descriptorId updateType:(TLUpdateAnnotationsUpdateType)updateType annotations:(nonnull NSMutableDictionary<NSUUID *, NSMutableArray<TLDescriptorAnnotation *> *> *)annotations {

    self = [super initWithSerializer:serializer requestId:requestId];
    
    if (self) {
        _descriptorId = descriptorId;
        _updateType = updateType;
        _annotations = annotations;
    }
    return self;
}

@end

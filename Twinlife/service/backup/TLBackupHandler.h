/*
 *  Copyright (c) 2026 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Romain Kolb (romain.kolb@skyrock.com)
 */

#import "TLBinaryEncoder.h"
#import "TLBinaryDecoder.h"

@interface TLBackupVerifyResult : NSObject

@end

@interface TLBackupVerifyResultPresent<ObjectType> : TLBackupVerifyResult

@property (nonatomic, nonnull, readonly) ObjectType object;
@property (nonatomic, readonly) BOOL modified;

-(nonnull instancetype)initWithObject:(nonnull ObjectType)object modified:(BOOL)modified;

@end

@interface TLBackupVerifyResultAbsent : TLBackupVerifyResult

@property (nonatomic, nonnull, readonly) NSUUID *identifier;
@property (nonatomic, nullable, readonly) NSUUID *schemaId;
@property (nonatomic, nonnull, readonly) Class type;

-(nonnull instancetype)initWithIdentifier:(nonnull NSUUID *)identifier schemaId:(nullable NSUUID *)schemaId type:(nonnull Class)type;

@end

@interface TLRestorer<ObjectType> : NSObject

+ (nonnull NSNumber *) VERSION;

- (nullable ObjectType) restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace;

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder;

- (nullable NSDictionary *) getStats;

@end

@interface TLBackupHandler<ObjectType> : NSObject

@property (nonnull, readonly) NSDictionary<NSNumber *, TLRestorer<ObjectType> *> *restorers;

- (nonnull instancetype)initWithRestorers:(nonnull NSDictionary<NSNumber *, TLRestorer<ObjectType> *> *)restorers;

- (void)backupWithBinaryEncoder:(nonnull TLBinaryEncoder *)encoder;

- (nullable ObjectType)restoreWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder inPlace:(BOOL)inPlace;

- (nonnull TLBackupVerifyResult *)verifyWithBinaryDecoder:(nonnull TLBinaryDecoder *)decoder;


- (nullable NSDictionary<NSUUID *, NSNumber *> *)getBackupStats;

- (nonnull NSDictionary<NSUUID *, NSNumber *> *)getRestoreStats;

@end

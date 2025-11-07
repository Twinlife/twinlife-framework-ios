/*
 *  Copyright (c) 2023-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

// add toString to make sure we use a lowercase version compatible with Android.
#import "NSUUID+Extensions.h"

typedef enum {
    TLDatabaseTableTwincodeInbound,
    TLDatabaseTableTwincodeOutbound,
    TLDatabaseTableTwincodeKeys,
    TLDatabaseTableSecretKeys,
    TLDatabaseTableRepository,
    TLDatabaseTableConversation,
    TLDatabaseTableDescriptor,
    TLDatabaseTableAnnotation,
    TLDatabaseTableInvitation,
    TLDatabaseTableNotification,
    TLDatabaseTableImage,
    TLDatabaseTableOperation,
    TLDatabaseSequence,

    TLDatabaseTableLast
} TLDatabaseTable;

/**
 * Interface that describes where a database object is stored as well as its schema.
 */
@protocol TLDatabaseObjectIdentification

/// Give information about the database table that contains the object.
- (TLDatabaseTable)kind;

/// The schema ID identifies the object factory in the database.
- (nonnull NSUUID *)schemaId;

/// The schema version identifies a specific version of the object representation.
- (int)schemaVersion;

/// Indicates whether the object is local only or also stored on the server.
- (BOOL)isLocal;

@end

/**
 * A database identifier holds an internal ID and an identification of the object.
 * It can be used for a repository object, a twincode, a conversation, a descriptor,
 * a notification.
 */
@interface TLDatabaseIdentifier : NSObject <NSCopying>

@property (readonly) long identifier;
@property (readonly, nonnull) id<TLDatabaseObjectIdentification> factory;

- (nonnull instancetype)initWithIdentifier:(long)identifier factory:(nonnull id<TLDatabaseObjectIdentification>)factory;

- (nonnull NSNumber *)identifierNumber;

- (TLDatabaseTable)databaseTable;

/// The schema ID identifies the object factory in the database.
- (nonnull NSUUID *)schemaId;

/// The schema version identifies a specific version of the object representation.
- (int)schemaVersion;

/// Indicates whether the object is local only or also stored on the server.
- (BOOL)isLocal;

@end


@protocol TLDatabaseObject <NSObject>

/// Get the internal database identifier.  This is unique across all database objects.
- (nonnull TLDatabaseIdentifier *)identifier;

/// Get the id associated with the object.  This UUID is used to identify the object on the server.
- (nonnull NSUUID *)objectId;

@end

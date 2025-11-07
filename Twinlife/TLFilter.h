/*
 *  Copyright (c) 2023 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@protocol TLRepositoryObject;
@protocol TLDatabaseObject;
@class TLTwincodeOutbound;

typedef BOOL (^TLFilterAcceptor) (id<TLDatabaseObject> _Nonnull object);

/**
 * Basic filter definition for the RepositoryService, ConversationService and NotificationService.
 * The filter is used to build the SQL query to find the objects.  Then, for each object found
 * it calls `acceptWithObject()` to check if the object matches other more complex rules.
 *
 * - filter objects with a given owner (space),
 * - filter objects before a given date,
 * - filter objects matching a name (limited SQL LIKE),
 * - filter objects using a given twincode.
 */
@interface TLFilter : NSObject

@property (nullable) id<TLRepositoryObject> owner;
@property (nullable) NSString *name;
@property (nullable) TLTwincodeOutbound *twincodeOutbound;
@property int64_t before;
@property (nullable) TLFilterAcceptor acceptWithObject;

@end

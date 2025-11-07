/*
 *  Copyright (c) 2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>

#import <FMDatabaseAdditions.h>
#import <FMDatabaseQueue.h>

#import <WebRTC/TLCryptoBox.h>
#import "NSData+Extensions.h"
#import "TLCryptoServiceProvider.h"
#import "TLCryptoServiceImpl.h"
#import "TLTwincodeOutboundServiceImpl.h"
#import "TLSessionSecretKeyPair.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
#if defined(DEBUG) && DEBUG == 1
static const int ddLogLevel = DDLogLevelInfo;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif
#endif

#define LOG_TAG @"TLCryptoServiceProvider"

#define SCHEMA_ID @"33c38ac6-e89d-4639-b116-90fc47a5f9f4"

/**
 * twincodeKeys table:
 * id INTEGER: local database identifier (primary key)  == twincode outbound id
 * creationDate INTEGER: key creation date
 * modificationDate INTEGER: key modification date
 * flags INTEGER NOT NULL: various control flags
 * nonceSequence INTEGER: sequence number
 * signingKey BLOB: private or public key for signing
 * encryptionKey BLOB: private or public key for encryption
 */
#define TWINCODE_KEYS_CREATE_TABLE \
        @"CREATE TABLE IF NOT EXISTS twincodeKeys (id INTEGER PRIMARY KEY," \
            " creationDate INTEGER NOT NULL, modificationDate INTEGER NOT NULL," \
            " flags INTEGER NOT NULL, nonceSequence INTEGER NOT NULL DEFAULT 0," \
            " signingKey BLOB, encryptionKey BLOB" \
            ")"

/**
 * secretKeys table:
 * id INTEGER NOT NULL: local twincode identifier (primary key)
 * peerTwincodeId INTEGER: peer twincode identifier (primary key)
 * creationDate INTEGER: secret creation date
 * modificationDate INTEGER: secret modification date
 * secretUpdateDate INTEGER: last update date of secret1 or secret2
 * flags INTEGER NOT NULL: various control flags
 * nonceSequence INTEGER NOT NULL: sequence number
 * secret1 BLOB: secret 1
 * secret2 BLOB: secret 2
 *
 * Note:
 *  - we have only one secret for a peer twincode.
 *    a secretKeys for a peerTwincode will have peerTwincodeId == NULL
 *  - we have only one secret for a 1-1 contact.
 *  - we have one secret for each member of a group we are talking to
 *    the 'id' is our identity and the 'peerTwincodeId' is the peer twincode.
 */
#define SECRET_KEYS_CREATE_TABLE \
        @"CREATE TABLE IF NOT EXISTS secretKeys (id INTEGER NOT NULL," \
         " peerTwincodeId INTEGER," \
         " creationDate INTEGER NOT NULL, modificationDate INTEGER NOT NULL," \
         " secretUpdateDate INTEGER NOT NULL," \
         " flags INTEGER NOT NULL DEFAULT 0," \
         " nonceSequence INTEGER NOT NULL DEFAULT 0," \
         " secret1 BLOB, secret2 BLOB," \
         " PRIMARY KEY(id, peerTwincodeId)" \
         ")"

//
// Implementation: TLCryptoServiceProvider
//

@implementation TLCryptoServiceProvider

- (nonnull instancetype)initWithService:(nonnull TLCryptoService *)service database:(nonnull TLDatabaseService *)database {
    DDLogVerbose(@"%@ initWithService: %@ database: %@", LOG_TAG, service, database);

    self = [super initWithService:service database:database sqlCreate:TWINCODE_KEYS_CREATE_TABLE table:TLDatabaseTableTwincodeKeys];
    return self;
}

- (void)onCreateWithTransaction:(nonnull TLTransaction *)transaction {
    DDLogVerbose(@"%@ onCreateWithTransaction: %@", LOG_TAG, transaction);

    [super onCreateWithTransaction:transaction];
    [transaction createSchemaWithSQL:SECRET_KEYS_CREATE_TABLE];
}

- (void)onUpgradeWithTransaction:(nonnull TLTransaction *)transaction oldVersion:(int)oldVersion newVersion:(int)newVersion {
    DDLogVerbose(@"%@ onUpgradeWithTransaction: %@ oldVersion: %d newVersion: %d", LOG_TAG, transaction, oldVersion, newVersion);

    /*
     * <pre>
     * Database Version 23
     *  Date: 2024/09/27
     *   New database model with twincodeKeys and secretKeys table
     * </pre>
     */
    [self onCreateWithTransaction:transaction];
}

#if 0

// Uncomment the #if 0 to erase the secret keys and twincode keys as if we are using
// and old version of twinme.  This allows to test the upgrade from 26.0 to 27.0 for
// the secret key generation.
- (void)onOpen {
    DDLogVerbose(@"%@ onOpen", LOG_TAG);

    [self inTransaction:^(TLTransaction *transaction) {
        [transaction executeUpdate:@"UPDATE twincodeOutbound SET flags = 0 WHERE flags > 1"];
        [transaction executeUpdate:@"DELETE FROM secretKeys"];
        [transaction executeUpdate:@"DELETE FROM twincodeKeys"];
        [transaction commit];
    }];
}
#endif

#pragma mark - TLDatabaseObjectFactory

- (BOOL)isLocal {
    
    return NO;
}

- (nonnull NSUUID *)schemaId {

    return [[NSUUID alloc] initWithUUIDString:SCHEMA_ID];
}

- (int)schemaVersion {

    return 0;
}

#pragma mark - TLCryptoServiceProvider

- (nullable TLTwincodeInbound *)loadTwincodeWithTwincodeId:(nonnull NSUUID *)twincodeInboundId {
    DDLogVerbose(@"%@ loadTwincodeWithTwincodeInboundId: %@", LOG_TAG, twincodeInboundId);
    
    return [self.database loadTwincodeInboundWithTwincodeId:twincodeInboundId];
}

- (nullable TLKeyInfo *)loadPeerEncryptionKeyWithTwincodeId:(nonnull NSUUID *)twincodeId {
    DDLogVerbose(@"%@ loadPeerEncryptionKeyWithTwincodeId: %@", LOG_TAG, twincodeId);

    __block TLKeyInfo *info = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }

        FMResultSet *resultSet = [database executeQuery:@"SELECT k.flags, k.modificationDate, k.signingKey,"
                                  " k.encryptionKey,"
                                  " twout.id, twout.twincodeId, twout.modificationDate, twout.name,"
                                  " twout.avatarId, twout.description, twout.capabilities, twout.attributes, twout.flags"
                                  " FROM twincodeOutbound AS twout"
                                  " INNER JOIN twincodeKeys AS k ON k.id=twout.id"
                                  " WHERE twout.twincodeId=?", [TLDatabaseService toObjectWithUUID:twincodeId]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if (![resultSet next]) {
            return;
        }

        int flags = [resultSet intForColumnIndex:0];
        int64_t modificationDate = [resultSet longLongIntForColumnIndex:1];
        NSData *signingKey = [resultSet dataForColumnIndex:2];
        NSData *encryptionKey = [resultSet dataForColumnIndex:3];
        TLTwincodeOutbound *twincodeOutbound = [self.database loadTwincodeOutboundWithResultSet:resultSet offset:4];
        info = [[TLKeyInfo alloc] initWithTwincode:twincodeOutbound modificationDate:modificationDate flags:flags signingKey:signingKey encryptionKey:encryptionKey nonceSequence:0 keyIndex:0 secret:nil];
    }];

    return info;
}

- (nullable TLKeyInfo *)loadKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincode {
    DDLogVerbose(@"%@ loadKeyWithTwincode: %@", LOG_TAG, twincode);

    NSNumber *keyId = [twincode.identifier identifierNumber];
    __block TLKeyInfo *info = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }

        FMResultSet *resultSet = [database executeQuery:@"SELECT k.flags, k.modificationDate, k.signingKey,"
                                      " k.encryptionKey, k.nonceSequence"
                                      " FROM twincodeKeys AS k WHERE k.id=?", keyId];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if (![resultSet next]) {
            return;
        }

        int flags = [resultSet intForColumnIndex:0];
        int64_t modificationDate = [resultSet longLongIntForColumnIndex:1];
        NSData *signingKey = [resultSet dataForColumnIndex:2];
        NSData *encryptionKey = [resultSet dataForColumnIndex:3];
        int64_t nonceSequence = [resultSet longLongIntForColumnIndex:4];
        info = [[TLKeyInfo alloc] initWithTwincode:twincode modificationDate:modificationDate flags:flags signingKey:signingKey encryptionKey:encryptionKey nonceSequence:nonceSequence keyIndex:0 secret:nil];
    }];

    return info;
}

- (nullable TLKeyInfo *)loadKeySecretsWithTwincode:(nonnull TLTwincodeOutbound *)twincode peerTwincode:(nonnull TLTwincodeOutbound *)peerTwincode useSequenceCount:(long)useSequenceCount options:(int)options {
    DDLogVerbose(@"%@ loadKeySecretsWithTwincode: %@ peerTwincode: %@ useSequenceCount: %ld options: %d", LOG_TAG, twincode, peerTwincode, useSequenceCount, options);

    NSData *secret = ((options & (TLCryptoServiceProviderCreateSecret | TLCryptoServiceProviderCreateNextSecret | TLCryptoServiceProviderCreateFirstSecret)) != 0) ? [NSData secureRandomWithLength:TL_KEY_LENGTH] : nil;

    while (true) {
        NSNumber *keyId = [twincode.identifier identifierNumber];
        NSNumber *peerId = [peerTwincode.identifier identifierNumber];
        __block TLKeyInfo *info = nil;
        __block BOOL createSecret = NO;
        __block NSNumber *secretId = nil;
        __block int secretFlags = 0;
        [self inDatabase:^(FMDatabase *database) {
            if (!database) {
                return;
            }

            FMResultSet *resultSet = [database executeQuery:@"SELECT k.flags, k.modificationDate, k.signingKey,"
                                      " k.encryptionKey, k.nonceSequence, s.id, s.flags, s.secret1, s.secret2"
                                      " FROM twincodeKeys AS k"
                                      " LEFT JOIN secretKeys AS s ON k.id=s.id AND s.peerTwincodeId=?"
                                      " WHERE k.id=?", peerId, keyId];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
                return;
            }
            if (![resultSet next]) {
                return;
            }

            int flags = [resultSet intForColumnIndex:0];
            int64_t modificationDate = [resultSet longLongIntForColumnIndex:1];
            NSData *signingKey = [resultSet dataForColumnIndex:2];
            NSData *encryptionKey = [resultSet dataForColumnIndex:3];
            int64_t nonceSequence = [resultSet longLongIntForColumnIndex:4];
            secretId = [resultSet columnIndexIsNull:5] ? nil : [NSNumber numberWithLong:[resultSet longForColumnIndex:5]];
            secretFlags = [resultSet columnIndexIsNull:6] ? 0 : [resultSet intForColumnIndex:6];
            NSData *secret1 = [resultSet dataForColumnIndex:7];
            NSData *secret2 = [resultSet dataForColumnIndex:8];

            // Create a new secret 1 or secret2 depending on current configuration.  This must be idempotent
            // so that if we want to send a new secret X to the peer, we can repeat the send operation but
            // we create the secret only once.  The new secret is marked with `NEW_SECRET1` or `NEW_SECRET2`
            // until the peer acknowledged its good reception.  At that time, we clear the flag and update
            // the `USE_SECRETx` to reflect the change (see `validateSecrets()`).
            NSData *useSecret = nil;
            int keyIndex = 0;
            if ((options & TLCryptoServiceProviderCreateFirstSecret) != 0) {
                // If secret1 was already created, use it.  If the USE_SECRET1 flag is set, we must not
                // override the secret with a new one but we must continue using it and sent it even if
                // the peer already has it.
                keyIndex = 1;
                if ((secretFlags & TLCryptoServiceNewSecret1) != 0 || (secretFlags & TLCryptoServiceUseSecret1) != 0) {
                    useSecret = secret1;
                } else {
                    secretFlags = TLCryptoServiceNewSecret1;
                    useSecret = secret;
                    createSecret = YES;
                }
            } else if ((secretFlags & TLCryptoServiceUseSecret1) != 0) {
                keyIndex = 1;
                useSecret = secret1;
                if ((options & (TLCryptoServiceProviderCreateSecret | TLCryptoServiceProviderCreateNextSecret)) != 0) {
                    keyIndex = 2;
                    // Prepare for the new secret 2 (don't change until we clear the NEW_SECRET2 flag).
                    if ((options & TLCryptoServiceProviderCreateNextSecret) != 0) {
                        if ((secretFlags & TLCryptoServiceNewSecret2) == 0) {
                            secretFlags |= TLCryptoServiceNewSecret2;
                            useSecret = secret;
                            createSecret = YES;
                        } else {
                            useSecret = secret2;
                        }
                    } else {
                        // Switch to use secret2 (without waiting for the peer to acknowledge).
                        secretFlags |= TLCryptoServiceUseSecret2;
                        secretFlags &= ~TLCryptoServiceUseSecret1;
                        useSecret = secret;
                        createSecret = YES;
                    }
                }
            } else if ((secretFlags & TLCryptoServiceUseSecret2) != 0) {
                keyIndex = 2;
                useSecret = secret2;
                if ((options & (TLCryptoServiceProviderCreateSecret | TLCryptoServiceProviderCreateNextSecret)) != 0) {
                    keyIndex = 1;
                    // Prepare for the new secret 1 (don't change until we clear the NEW_SECRET1 flag).
                    if ((options & TLCryptoServiceProviderCreateNextSecret) != 0) {
                        if ((secretFlags & TLCryptoServiceNewSecret1) == 0) {
                            secretFlags |= TLCryptoServiceNewSecret1;
                            useSecret = secret;
                            createSecret = YES;
                        } else {
                            useSecret = secret1;
                        }
                    } else {
                        // Switch to use secret1 (without waiting for the peer to acknowledge).
                        secretFlags |= TLCryptoServiceUseSecret1;
                        secretFlags &= ~TLCryptoServiceUseSecret2;
                        useSecret = secret;
                        createSecret = YES;
                    }
                }
            } else if ((options & TLCryptoServiceProviderCreateNextSecret) != 0) {
                secretFlags = TLCryptoServiceNewSecret1;
                useSecret = secret;
                createSecret = YES;
                keyIndex = 1;
            } else if ((options & TLCryptoServiceProviderCreateSecret) != 0) {
                secretFlags = TLCryptoServiceUseSecret1;
                useSecret = secret;
                createSecret = YES;
                keyIndex = 1;
            } else if ((options & TLCryptoServiceProviderCreateFirstSecret) != 0) {
                // If secret1 was already created, use it.
                if ((secretFlags & TLCryptoServiceNewSecret1) != 0) {
                    useSecret = secret1;
                    keyIndex = 1;
                } else {
                    secretFlags = TLCryptoServiceNewSecret1;
                    useSecret = secret;
                    createSecret = YES;
                    keyIndex = 1;
                }
            } else {
                keyIndex = 0;
                useSecret = nil;
            }

            info = [[TLKeyInfo alloc] initWithTwincode:twincode modificationDate:modificationDate flags:flags signingKey:signingKey encryptionKey:encryptionKey nonceSequence:nonceSequence keyIndex:keyIndex secret:useSecret];
        }];
        if (!info || (useSequenceCount == 0 && !createSecret)) {
            return info;
        }

        __block BOOL success = NO;
        [self inTransaction:^(TLTransaction *transaction) {
            NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
            [transaction executeUpdate:@"UPDATE twincodeKeys SET nonceSequence=?, modificationDate=? WHERE id=? AND nonceSequence=?", [NSNumber numberWithLongLong:info.nonceSequence + useSequenceCount], now, keyId, [NSNumber numberWithLongLong:info.nonceSequence]];
            if (createSecret) {
                if (secretId == nil) {
                    [transaction executeUpdate:@"INSERT OR REPLACE INTO secretKeys (id, peerTwincodeId, creationDate, modificationDate, secretUpdateDate, flags, secret1) values(?, ?, ?, ?, ?, ?, ?)", keyId, peerId, now, now, now, [NSNumber numberWithInt:secretFlags], secret];
                } else {
                    // Update flags, secrets and modification date but not the secretUpdateDate:
                    // it will be updated by validateSecrets() when the peer acknowledges the update.
                    if (info.keyIndex == 1) {
                        [transaction executeUpdate:@"UPDATE secretKeys SET flags=?, secret1=? WHERE id=? AND peerTwincodeId=?", [NSNumber numberWithInt:secretFlags], info.secretKey, keyId, peerId];
                    } else {
                        [transaction executeUpdate:@"UPDATE secretKeys SET flags=?, secret2=? WHERE id=? AND peerTwincodeId=?", [NSNumber numberWithInt:secretFlags], info.secretKey, keyId, peerId];
                    }
                }

                // Now, make sure the twincode has FLAG_ENCRYPT set iff USE_SECRETx is set
                // (otherwise, it must be handled by validateSecrets().
                int twincodeFlags = twincode.flags;
                if ((twincodeFlags & FLAG_ENCRYPT) == 0 && ((secretFlags & (TLCryptoServiceUseSecret1 | TLCryptoServiceUseSecret2)) != 0)) {
                    twincodeFlags |= FLAG_ENCRYPT;
                    [transaction executeUpdate:@"UPDATE twincodeOutbound SET modificationDate=?, flags=? WHERE id=?", now, [NSNumber numberWithInt:twincodeFlags], keyId];
                    twincode.flags = twincodeFlags;
                    twincode.modificationDate = now.longLongValue;
                }

                DDLogInfo(@"%@ Created secret %d for twincode %@ twincode flags %x", LOG_TAG, info.keyIndex, twincode.uuid, twincodeFlags);
            }
            [transaction commit];
            success = YES;
        }];
        if (success) {
            return info;
        }
    }
}

- (nullable TLKeyPair *)loadKeyPairWithTwincode:(nonnull TLTwincodeOutbound *)twincode {
    DDLogVerbose(@"%@ loadKeyWithTwincode: %@", LOG_TAG, twincode);

    NSNumber *keyId = [twincode.identifier identifierNumber];
    __block TLKeyPair *info = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }
        
        FMResultSet *resultSet = [database executeQuery:@"SELECT privKey.flags, privKey.signingKey,"
                                  " pubKey.flags, pubKey.signingKey, twout.twincodeId, peerTwout.twincodeId, r.uuid"
                                  " FROM repository AS r"
                                  " INNER JOIN twincodeKeys AS privKey ON r.twincodeOutbound=privKey.id"
                                  " INNER JOIN twincodeKeys AS pubKey ON r.peerTwincodeOutbound=pubKey.id"
                                  " INNER JOIN twincodeOutbound AS twout ON r.twincodeOutbound=twout.id"
                                  " INNER JOIN twincodeOutbound AS peerTwout ON r.peerTwincodeOutbound=peerTwout.id"
                                  " WHERE r.twincodeOutbound=?", keyId];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if (![resultSet next]) {
            return;
        }
        
        int privFlags = [resultSet intForColumnIndex:0];
        NSData *privKey = [resultSet dataForColumnIndex:1];
        int peerPubFlags = [resultSet intForColumnIndex:2];
        NSData *peerPubKey = [resultSet dataForColumnIndex:3];
        NSUUID *twincodeId = [resultSet uuidForColumnIndex:4];
        NSUUID *peerTwincodeId = [resultSet uuidForColumnIndex:5];
        NSUUID *subjectId = [resultSet uuidForColumnIndex:6];
        if (privKey && peerPubKey && twincodeId && peerTwincodeId && subjectId) {
            info = [[TLKeyPair alloc] initWithFlags:privFlags privKey:privKey peerFlags:peerPubFlags peerPubKey:peerPubKey twincodeId:twincodeId peerTwincodeId:peerTwincodeId subjectId:subjectId];
        }
    }];
    return info;
}

- (nullable TLKeyPair *)loadKeyPairWithKey:(nonnull NSData *)key {
    DDLogVerbose(@"%@ loadKeyPairWithKey: %@", LOG_TAG, key);

    __block TLKeyPair *info = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }
        
        FMResultSet *resultSet = [database executeQuery:@"SELECT privKey.flags, privKey.signingKey,"
                                  " pubKey.flags, pubKey.signingKey, twout.twincodeId, peerTwout.twincodeId, r.uuid"
                                  " FROM repository AS r"
                                  " INNER JOIN twincodeKeys AS privKey ON r.twincodeOutbound=privKey.id"
                                  " INNER JOIN twincodeKeys AS pubKey ON r.peerTwincodeOutbound=pubKey.id"
                                  " INNER JOIN twincodeOutbound AS twout ON r.twincodeOutbound=twout.id"
                                  " INNER JOIN twincodeOutbound AS peerTwout ON r.peerTwincodeOutbound=peerTwout.id"];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        while ([resultSet next]) {
            int privFlags = [resultSet intForColumnIndex:0];
            NSData *privKey = [resultSet dataForColumnIndex:1];
            int peerPubFlags = [resultSet intForColumnIndex:2];
            NSData *peerPubKey = [resultSet dataForColumnIndex:3];
            NSUUID *twincodeId = [resultSet uuidForColumnIndex:4];
            NSUUID *peerTwincodeId = [resultSet uuidForColumnIndex:5];
            NSUUID *subjectId = [resultSet uuidForColumnIndex:6];
            if (privKey && peerPubKey && twincodeId && peerTwincodeId && subjectId) {
                TLKeyPair *checkKey = [[TLKeyPair alloc] initWithFlags:privFlags privKey:privKey peerFlags:peerPubFlags peerPubKey:peerPubKey twincodeId:twincodeId peerTwincodeId:peerTwincodeId subjectId:subjectId];
                
                if ([key isEqualToData:peerPubKey] || [key isEqualToData:[checkKey.privateKey publicKey:NO]]) {
                    info = checkKey;
                    return;
                }
            }
        }
    }];
    return info;
}

- (TLBaseServiceErrorCode)prepareWithSessionId:(nonnull NSUUID *)sessionId twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nullable TLTwincodeOutbound *)peerTwincodeOutbound keyPair:(id<TLSessionKeyPair> _Nullable *_Nullable)keyPair strict:(BOOL)strict {
    DDLogVerbose(@"%@ prepareWithSessionId: %@ twincodeOutbound: %@ peerTwincodeOutbound: %@ strict: %d", LOG_TAG, sessionId, twincodeOutbound, peerTwincodeOutbound, strict);

    while (true) {
        NSNumber *keyId = [twincodeOutbound.identifier identifierNumber];
        *keyPair = nil;
        __block id<TLSessionKeyPair> sessionKey = nil;
        [self inDatabase:^(FMDatabase *database) {
            if (!database) {
                return;
            }

            if (peerTwincodeOutbound) {
                NSNumber *peerId = [peerTwincodeOutbound.identifier identifierNumber];

                // Note: there is only one row to get the peer secret BUT we could have several
                // rows for our own twincode: for a 1-1 relation, there will be only one but for a 1-N group
                // there will be one dedicated secret for each member: our secret is shared with only one group member.
                FMResultSet *resultSet = [database executeQuery:@"SELECT s.flags, s.secretUpdateDate,"
                                          " s.nonceSequence, s.secret1, s.secret2,"
                                          " peer.secret1, peer.secret2"
                                          " FROM secretKeys AS s, secretKeys AS peer"
                                          " WHERE s.id=? AND peer.id=? AND s.peerTwincodeId=peer.id", keyId, peerId];
                if (!resultSet) {
                    [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
                    return;
                }
                if (![resultSet next]) {
                    return;
                }
                
                int flags = [resultSet intForColumnIndex:0];
                int64_t secretUpdateDate = [resultSet longLongIntForColumnIndex:1];
                int64_t nonceSequence = [resultSet longLongIntForColumnIndex:2];
                NSData *secret1 = [resultSet dataForColumnIndex:3];
                NSData *secret2 = [resultSet dataForColumnIndex:4];
                NSData *peerSecret1 = [resultSet dataForColumnIndex:5];
                NSData *peerSecret2 = [resultSet dataForColumnIndex:6];
                int keyIndex;
                NSData *secret;
                
                // Get the secret that we are sure the peer has.
                if ((flags & TLCryptoServiceUseSecret1) != 0) {
                    secret = secret1;
                    keyIndex = 1;
                } else if ((flags & TLCryptoServiceUseSecret2) != 0) {
                    secret = secret2;
                    keyIndex = 2;
                } else if (flags != 0 && strict) {
                    // The peer does not know our secret and we are in strict mode (P2P-OUT).
                    return;
                } else {
                    secret = secret1;
                    keyIndex = 1;
                }

                sessionKey = [[TLSessionSecretKeyPair alloc] initWithSessionId:sessionId twincodeOutbound:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound privKeyFlags:flags secretUpdateDate:secretUpdateDate nonceSequence:nonceSequence keyIndex:keyIndex secret:secret peerSecret1:peerSecret1 peerSecret2:peerSecret2];
            } else {
                
            }
        }];
        if (!sessionKey) {
            return TLBaseServiceErrorCodeNoPrivateKey;
        }

        __block BOOL success = NO;
        [self inTransaction:^(TLTransaction *transaction) {
            NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
            int64_t nonceSequence = sessionKey.nonceSequence;
            if (peerTwincodeOutbound) {
                NSNumber *peerId = [peerTwincodeOutbound.identifier identifierNumber];

                [transaction executeUpdate:@"UPDATE secretKeys SET nonceSequence=?, modificationDate=? WHERE id=? AND peerTwincodeId=? AND nonceSequence=?", [NSNumber numberWithLongLong:nonceSequence + sessionKey.sequenceCount], now, keyId, peerId, [NSNumber numberWithLongLong:nonceSequence]];
            } else {
                [transaction executeUpdate:@"UPDATE twincodeKeys SET nonceSequence=?, modificationDate=? WHERE id=? AND nonceSequence=?", [NSNumber numberWithLongLong:nonceSequence + sessionKey.sequenceCount], now, keyId, [NSNumber numberWithLongLong:nonceSequence]];
            }
            [transaction commit];
            success = YES;
        }];
        if (success) {
            *keyPair = sessionKey;
            return TLBaseServiceErrorCodeSuccess;
        }
    }
}

- (TLBaseServiceErrorCode)refreshWithSessionKeyPair:(nonnull TLSessionSecretKeyPair *)sessionKeyPair {
    DDLogVerbose(@"%@ refreshWithSessionKeyPair: %@", LOG_TAG, sessionKeyPair);

    NSNumber *keyId = [sessionKeyPair.twincodeOutbound.identifier identifierNumber];
    NSNumber *peerId = [sessionKeyPair.peerTwincodeOutbound.identifier identifierNumber];
    __block TLBaseServiceErrorCode errorCode = TLBaseServiceErrorCodeDatabaseError;
    for (int retry = 1; retry < 5; retry++) {
        [self inTransaction:^(TLTransaction *transaction) {
            if (!transaction) {
                return;
            }

            // Only get the nonce sequence associated with the twincode pair.
            FMResultSet *resultSet = [transaction executeQuery:@"SELECT "
                                          " s.nonceSequence"
                                          " FROM secretKeys AS s"
                                          " WHERE s.id=? AND s.peerTwincodeId=?", keyId, peerId];
            if (!resultSet) {
                [self.service onDatabaseErrorWithError:[transaction lastError] line:__LINE__];
                return;
            }
            if (![resultSet next]) {
                return;
            }
                
            int64_t nonceSequence = [resultSet longLongIntForColumnIndex:0];
            NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];

            [sessionKeyPair refreshWithNonceSequence:nonceSequence];

            errorCode = TLBaseServiceErrorCodeExpired;
            [transaction executeUpdate:@"UPDATE secretKeys SET nonceSequence=?, modificationDate=? WHERE id=? AND peerTwincodeId=? AND nonceSequence=?", [NSNumber numberWithLongLong:nonceSequence + sessionKeyPair.sequenceCount], now, keyId, peerId, [NSNumber numberWithLongLong:nonceSequence]];
            [transaction commit];
            errorCode = TLBaseServiceErrorCodeSuccess;
        }];
        if (errorCode != TLBaseServiceErrorCodeExpired) {
            break;
        }
    }
    return errorCode;
}

- (nullable TLImageInfo *)loadImageInfoWithId:(int64_t)identifier {
    DDLogVerbose(@"%@ loadImageInfoWithId: %lld", LOG_TAG, identifier);

    __block TLImageInfo *result = nil;
    [self inDatabase:^(FMDatabase *database) {
        if (!database) {
            return;
        }

        FMResultSet *resultSet = [database executeQuery:@"SELECT img.uuid, img.imageSHAs"
                                  " FROM image AS img WHERE img.id=?", [NSNumber numberWithLongLong:identifier]];
        if (!resultSet) {
            [self.service onDatabaseErrorWithError:[database lastError] line:__LINE__];
            return;
        }
        if (![resultSet next]) {
            return;
        }

        NSUUID *imageId = [resultSet uuidForColumnIndex:0];
        NSData *imageSha = [resultSet dataForColumnIndex:1];
        result = [[TLImageInfo alloc] initWithData:imageSha publicId:imageId status:TLImageStatusTypeOwner copiedImageId:nil];
    }];
    return result;
}

- (void)saveSecretKeyWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound keyIndex:(int)keyIndex secretKey:(nonnull NSData *)secretKey {
    DDLogVerbose(@"%@ saveSecretKeyWithTwincode: %@ peerTwincodeOutbound: %@ keyIndex: %d secretKey: %@", LOG_TAG, twincodeOutbound, peerTwincodeOutbound, keyIndex, secretKey);
    
    [self inTransaction:^(TLTransaction *transaction) {
        NSNumber *peerId = [peerTwincodeOutbound.identifier identifierNumber];
        NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];

        [transaction saveSecretKeyWithKeyId:peerId keyIndex:keyIndex secretKey:secretKey now:now];

        // Check if the FLAG_ENCRYPT flags is set on the peer twincode:
        // - we must have the { <twincode>, <peer-twincode> } key association,
        // - we must know the peer secret { <peer-twincode>, null } association (this is now true).
        if (![peerTwincodeOutbound isEncrypted]) {
            [transaction updateTwincodeEncryptFlagsWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound now:now];
        }

        [transaction commit];

        DDLogInfo(@"%@ Stored peer secret %d for twincode %@ twincode flags %x", LOG_TAG, keyIndex, peerTwincodeOutbound.uuid, peerTwincodeOutbound.flags);
    }];
}

- (void)validateSecretWithTwincode:(nonnull TLTwincodeOutbound *)twincodeOutbound peerTwincodeOutbound:(nonnull TLTwincodeOutbound *)peerTwincodeOutbound {
    DDLogVerbose(@"%@ validateSecretWithTwincode: %@ peerTwincodeOutbound: %@", LOG_TAG, twincodeOutbound, peerTwincodeOutbound);
    
    [self inTransaction:^(TLTransaction *transaction) {

        NSNumber *keyId = [twincodeOutbound.identifier identifierNumber];
        NSNumber *peerId = [peerTwincodeOutbound.identifier identifierNumber];

        long secretFlags = [transaction longForQuery:@"SELECT flags FROM secretKeys WHERE id=? AND peerTwincodeId=?", keyId, peerId];
        if (secretFlags == 0) {
            return;
        }

        NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
        if ((secretFlags & TLCryptoServiceNewSecret1) != 0) {
            secretFlags = TLCryptoServiceUseSecret1;
        } else if ((secretFlags & TLCryptoServiceNewSecret2) != 0) {
            secretFlags = TLCryptoServiceUseSecret2;
        }
        [transaction executeUpdate:@"UPDATE secretKeys SET secretUpdateDate=?, flags=? WHERE id=? AND peerTwincodeId=?", now, [NSNumber numberWithLong:secretFlags], keyId, peerId];

        // Now, make sure our twincode has FLAG_ENCRYPT set.
        [transaction updateTwincodeEncryptFlagsWithTwincode:twincodeOutbound peerTwincodeOutbound:peerTwincodeOutbound now:now];
        [transaction commit];

        DDLogInfo(@"%@ Validated sent secret flags %lx for twincode %@ twincode flags %x with peer %@", LOG_TAG, secretFlags, twincodeOutbound.uuid, twincodeOutbound.flags, peerTwincodeOutbound.uuid);
    }];
}

- (TLBaseServiceErrorCode)insertKeyWithTransaction:(nonnull TLTransaction *)transaction twincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound flags:(int)flags {
    DDLogVerbose(@"%@ insertKeyWithTransaction: %@ flags: %d", LOG_TAG, twincodeOutbound, flags);
    
    TLCryptoKey *signCrypto = [TLCryptoKey createWithKind:[TLKeyInfo toCryptoKindWithFlags:flags encrypt:NO]];
    TLCryptoKey *encryptCrypto = [TLCryptoKey createWithKind:[TLKeyInfo toCryptoKindWithFlags:flags encrypt:YES]];
    NSData *signingKey = [signCrypto privateKey:NO];
    NSData *encryptionKey = [encryptCrypto privateKey:NO];
    if (!signingKey || !encryptionKey) {
        return TLBaseServiceErrorCodeLibraryError;
    }

    NSNumber *now = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
    [transaction executeUpdate:@"INSERT OR IGNORE INTO twincodeKeys (id, creationDate, modificationDate, flags, signingKey, encryptionKey, nonceSequence) VALUES(?, ?, ?, ?, ?, ?, 0)", [twincodeOutbound.identifier identifierNumber], now, now, [NSNumber numberWithInt:(flags & TL_KEY_TYPE_MASK) | TL_KEY_PRIVATE_FLAG], signingKey, [TLDatabaseService toObjectWithData:encryptionKey]];
    return TLBaseServiceErrorCodeSuccess;
}

- (TLBaseServiceErrorCode)insertKeyWithTwincodeOutbound:(nonnull TLTwincodeOutbound *)twincodeOutbound flags:(int)flags {
    DDLogVerbose(@"%@ insertKeyWithTransaction: %@ flags: %d", LOG_TAG, twincodeOutbound, flags);

    __block TLBaseServiceErrorCode result = TLBaseServiceErrorCodeDatabaseError;
    [self inTransaction:^(TLTransaction *transaction) {
        
        result = [self insertKeyWithTransaction:transaction twincodeOutbound:twincodeOutbound flags:flags];
        if (result == TLBaseServiceErrorCodeSuccess) {
            [transaction commit];
        }
    }];
    return result;
}

@end

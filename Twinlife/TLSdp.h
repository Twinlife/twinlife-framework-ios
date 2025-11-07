/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

@class TLSdp;

//
// Interface: TLTransportCandidate
//

@interface TLTransportCandidate : NSObject

@property (readonly) int ident;
@property (readonly, nonnull) NSString *label;
@property (readonly, nonnull) NSString *sdp;
@property (readonly) BOOL removed;
@property int64_t requestId;

- (nonnull instancetype)initWithId:(int)ident label:(nonnull NSString*)label sdp:(nonnull NSString *)sdp removed:(BOOL)removed;

@end

//
// Interface: TLTransportCandidateList
//

@interface TLTransportCandidateList : NSObject

- (nonnull instancetype)init;

/// Check if we have some transport candidate to send.
- (BOOL)isFlushed;

/// Indicates that a new transport candidate is available.
- (void)addCandidateWithId:(int)ident label:(nonnull NSString *)label sdp:(nonnull NSString *)sdp;

/// Indicates that a transport candidate is no longer available.
- (void)removeCandidateWithId:(int)ident label:(nonnull NSString *)label sdp:(nonnull NSString *)sdp;

/// Clear the list of candidates.
- (void)clear;

/// Build the transport info SDP for a new request to send all the transport candidates not yet sent.
- (nonnull TLSdp *)buildSdpWithRequestId:(int64_t)requestId;

/// Remove all transport candidate associated with the give request id.
- (void)removeWithRequestId:(int64_t)requestId;

/// Cancel the request and prepare to send again all transport candidate with the given request id.
- (void)cancelWithRequestId:(int64_t)requestId;

- (int)pendingCount;

@end

//
// Interface: TLSdp
//

@interface TLSdp : NSObject

/// Get the SDP raw data as transmitted on the wire.
@property (readonly, nonnull) NSData *data;

/// Filter the SDP to only keep codecs in the `CODECS` list.
+ (nonnull NSString *)filterCodecsWithSDP:(nonnull NSString *)sdp;

/// Create the SDP content from the binary content as received on the wire from the peer.
- (nonnull instancetype)initWithData:(nonnull NSData *)data compressed:(BOOL)compressed keyIndex:(int)keyIndex;

/// Create the SDP with the given content and compress it if necessary.
- (nonnull instancetype)initWithSdp:(nonnull NSString *)sdp;

/// Returns true if the SDP is compressed.
- (BOOL)isCompressed;

/// Returns true if the SDP is encrypted.
- (BOOL)isEncrypted;

/// Get the key index used for encryption.
- (int)getKeyIndex;

/// Get the SDP in de-compressed and clear form text.
- (nullable NSString *)sdp;

/// Get the transport candidates defined in the sdp.
- (nullable NSArray<TLTransportCandidate *> *)candidates;

@end

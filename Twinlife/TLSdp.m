/*
 *  Copyright (c) 2022-2024 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import <CocoaLumberjack.h>
#import <zlib.h>

#import "TLSdp.h"

#if 0
static const int ddLogLevel = DDLogLevelVerbose;
#else
static const int ddLogLevel = DDLogLevelWarning;
#endif

#define COMPRESS_LIMIT 256

/// The SDP candidate is composed of pre-defined strings. The `dictionary` describes a set of pre-defined strings
/// that occur in most SDP candidate and that we can replace quickly and easily by a single special character.
/// The Objective-C implementation uses C pointer because SDP candidate analysis and expansion is 2 times faster
/// compared to a similar implementation with NSString.  The encoding/decoding as well as the compression/decompression
/// must be fast because the user could have fast Wi-Fi or 4G networks and we don't want to impact on them.
/// The benefit in compacting/compressing comes when the SDP is big and the network is slow (we must consider our
/// network but also the peer's network that we don't know).
#define DICTIONARY_SIZE 16

static const char* dictionary[DICTIONARY_SIZE] = {
        "candidate:", // 1
        " udp ",      // 2
        " tcptype",   // 14
        " relay",     // 4
        " typ",       // 5
        " host",      // 6
        " srflx",     // 7
        " relay",     // 8
        " raddr",     // 10
        " ufrag",     // 11
        " rport",     // 12
        " tcp ",      // 3
        " passive",   // 15
        " network-cost", // 16
        " network-id", // 17
        " generation"  // 18
};

static const char dictionaryMap[] = {
        (char) 1, (char) 2, (char) 14,
        (char) 4, (char) 5, (char) 6,
        (char) 7, (char) 8, (char) 10,
        (char) 11, (char) 12, (char) 3,
        (char) 15, (char) 16, (char) 17,
        (char) 18
};

#define MAX_DICTIONARY_SIZE 19

static const int mapToDictionary[MAX_DICTIONARY_SIZE] = {
        -1,
        0,
        1,
        11,
        3,
        4,
        5,
        6,
        7,
        -1,
        8,
        9,
        10,
        11,
        2,
        12,
        13,
        14,
        15
};

static NSArray<NSString *> *CODECS;

//
// Interface: TLTransportCandidateList
//

@interface TLTransportCandidateList ()

@property (readonly, nonnull) NSMutableArray<TLTransportCandidate *> *candidates;

+ (int)findDictionaryWithContent:(nonnull const char *)content;

/// Expand the received compact SDP string by using the pre-defined dictionary.
+ (nonnull NSString *)expand:(nonnull NSString *)sdp;

/// Build the transport info SDP for a new request to send all the transport candidates not yet sent.
- (nonnull NSString *)buildInternalSdpWithRequestId:(int64_t)requestId;

@end

//
// Interface: TLSdp
//

@interface TLSdp ()

@property BOOL compressed;
@property int keyIndex;

@end

//
// Implementation: TLTransportCandidate
//

#undef LOG_TAG
#define LOG_TAG @"TLTransportCandidate"

@implementation TLTransportCandidate

/// Create the SDP content from the binary content as received on the wire from the peer.
- (nonnull instancetype)initWithId:(int)ident label:(nonnull NSString*)label sdp:(nonnull NSString *)sdp removed:(BOOL)removed {
    DDLogVerbose(@"%@ initWithId: %d label: %@ sdp: %@ removed: %d", LOG_TAG, ident, label, sdp, removed);

    self = [super init];
    if (self) {
        _ident = ident;
        _label = label;
        _sdp = sdp;
        _removed = removed;
        _requestId = 0L;
    }
    return self;
}

@end

//
// Implementation: TLTransportCandidateList
//

#undef LOG_TAG
#define LOG_TAG @"TLTransportCandidateList"

@implementation TLTransportCandidateList

+ (int)findDictionaryWithContent:(nonnull const char *)content {
    
    // Start at the second dictionary entry because the first one does not start with a space.
    for (int i = 1; i < DICTIONARY_SIZE; i++) {
        const char* dict = dictionary[i];
        size_t len = strlen(dict);
        if (strncmp(content, dict, len) == 0) {
            return i;
        }
    }

    return -1;
}

+ (nonnull NSString *)expand:(nonnull NSString *)sdp {
    DDLogVerbose(@"%@ expand: %@", LOG_TAG, sdp);

    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256];
    NSUInteger len = [sdp length];

    for (int i = 0; i < len; i++) {
        char c = [sdp characterAtIndex:i];
        if (c >= MAX_DICTIONARY_SIZE) {
            [result appendFormat:@"%c", c];
        } else {
            int pos = mapToDictionary[(int) c];
            if (pos < 0) {
                [result appendFormat:@"%c", c];
            } else {
                const char *dict = dictionary[pos];
                size_t len = strlen(dict);
                [result appendString:[[NSString alloc] initWithBytesNoCopy:(void*)dict length:len encoding:NSUTF8StringEncoding freeWhenDone:NO]];
            }
        }
    }
    return result;
}

- (nonnull instancetype)init {
    
    self = [super init];
    if (self) {
        _candidates = [[NSMutableArray alloc] init];
    }
    return self;
}

/// Check if we have some transport candidate to send.
- (BOOL)isFlushed {
    
    @synchronized (self) {
        for (TLTransportCandidate *candidate in self.candidates) {
            if (candidate.requestId == 0) {
                return NO;
            }
        }
    }
    
    return YES;
}

- (int)pendingCount {
    
    int count = 0;
    @synchronized (self) {
        for (TLTransportCandidate *candidate in self.candidates) {
            if (candidate.requestId == 0) {
                count++;
            }
        }
    }
    
    return count;
}

/// Indicates that a new transport candidate is available.
- (void)addCandidateWithId:(int)ident label:(nonnull NSString *)label sdp:(nonnull NSString *)sdp {
    DDLogVerbose(@"%@ addCandidateWithId: %d label: %@ sdp: %@", LOG_TAG, ident, label, sdp);

    @synchronized (self) {
        [self.candidates addObject:[[TLTransportCandidate alloc] initWithId:ident label:label sdp:sdp removed:NO]];
    }
}


/// Indicates that a transport candidate is no longer available.
- (void)removeCandidateWithId:(int)ident label:(nonnull NSString *)label sdp:(nonnull NSString *)sdp {
    DDLogVerbose(@"%@ removeCandidateWithId: %d label: %@ sdp: %@", LOG_TAG, ident, label, sdp);

    @synchronized (self) {
        [self.candidates addObject:[[TLTransportCandidate alloc] initWithId:ident label:label sdp:sdp removed:YES]];
    }
}

/// Clear the list of candidates.
- (void)clear {
    DDLogVerbose(@"%@ clear", LOG_TAG);

    @synchronized (self) {
        [self.candidates removeAllObjects];
    }
}

- (nonnull NSString *)buildInternalSdpWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ buildInternalSdpWithRequestId: %lld", LOG_TAG, requestId);

    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:256 * (self.candidates.count + 1)];

    BOOL needSeparator = NO;
    for (TLTransportCandidate *candidate in self.candidates) {
        if (candidate.requestId == 0) {
            candidate.requestId = requestId;

            if (needSeparator) {
                [result appendString:@"\r"];
            }
            needSeparator = YES;
            [result appendFormat:@"%c%@%c%d%c", (candidate.removed ? '-' : '+'), candidate.label, '\t', candidate.ident, '\t'];
            
            NSString *sdp = candidate.sdp;

            // Work on the C pointer to speed up the candidate compaction (2 times faster than NSString).
            unsigned int len = (unsigned int)[sdp length];
            const char* p = [sdp UTF8String];

            int pos = 0;
            size_t dictLen = strlen(dictionary[0]);
            if (strncmp(p, dictionary[0], dictLen) == 0) {
                [result appendFormat:@"%c", dictionaryMap[0]];
                pos = (int) dictLen;
            }
            while (pos < len) {
                char c = p[pos];
                if (c != ' ') {
                    [result appendFormat:@"%c", c];
                    pos++;
                } else {
                    int dict = [TLTransportCandidateList findDictionaryWithContent:&p[pos]];
                    if (dict > 0) {
                        pos += strlen(dictionary[dict]);
                        [result appendFormat:@"%c", dictionaryMap[dict]];
                    } else {
                        [result appendFormat:@"%c", c];
                        pos++;
                    }
                }
            }
        }
    }
    return result;
}

/// Build the transport info SDP for a new request to send all the transport candidates not yet sent.
- (nonnull TLSdp *)buildSdpWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ buildSdpWithRequestId: %lld", LOG_TAG, requestId);

    NSString *sdp;
    @synchronized (self) {
        sdp = [self buildInternalSdpWithRequestId:requestId];
    }

    return [[TLSdp alloc] initWithSdp:sdp];
}

/// Remove all transport candidate associated with the give request id.
- (void)removeWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ removeWithRequestId: %lld", LOG_TAG, requestId);

    @synchronized (self) {
        int index = (int) self.candidates.count;
        while (index >= 1) {
            index--;
            
            TLTransportCandidate *candidate = self.candidates[index];
            if (candidate.requestId == requestId) {
                [self.candidates removeObjectAtIndex:index];
            }
        }
    }
}

/// Cancel the request and prepare to send again all transport candidate with the given request id.
- (void)cancelWithRequestId:(int64_t)requestId {
    DDLogVerbose(@"%@ cancelWithRequestId: %lld", LOG_TAG, requestId);

    @synchronized (self) {
        for (TLTransportCandidate *candidate in self.candidates) {
            if (candidate.requestId == requestId) {
                candidate.requestId = 0;
            }
        }
    }
}

@end

//
// Implementation: TLSdp
//

#undef LOG_TAG
#define LOG_TAG @"TLSdp"

@implementation TLSdp

+ (void)initialize {
 
    // List of Audio and Video codecs which are accepted ("rtx" is added because it is required).
    CODECS = @[@"opus", @"rtx", @"VP8", @"VP9", @"H264", @"AV1X"];
}

+ (nonnull NSString *)filterCodecsWithSDP:(nonnull NSString *)sdp {
    DDLogVerbose(@"%@ filterCodecsWithSDP: %@", LOG_TAG, sdp);
    
    NSMutableArray *lines = [[NSMutableArray alloc] init];
    [lines addObjectsFromArray:[sdp componentsSeparatedByString:@"\n"]];
    NSMutableSet *payloadTypes = [[NSMutableSet alloc] init];
    BOOL filtered = NO;

    // Example produced by Firefox:
    // a=rtpmap:109 opus/48000/2^M
    // a=rtpmap:9 G722/8000/1^M
    // a=rtpmap:0 PCMU/8000^M
    // a=rtpmap:8 PCMA/8000^M
    // a=rtpmap:101 telephone-event/8000/1^M
    // a=rtpmap:120 VP8/90000^M
    // a=rtpmap:124 rtx/90000^M
    // a=rtpmap:121 VP9/90000^M
    // a=rtpmap:125 rtx/90000^M
    // a=rtpmap:126 H264/90000^M
    // a=rtpmap:127 rtx/90000^M
    // a=rtpmap:97 H264/90000^M
    // a=rtpmap:98 rtx/90000^M
    // a=rtpmap:123 ulpfec/90000^M
    // a=rtpmap:122 red/90000^M
    // a=rtpmap:119 rtx/90000^M
    // => we must keep 97, 98, 109, 119, 120, 121, 124, 125, 126, 127
    // => we want to drop 0, 8, 9, 101, 119, 122, 123
    for (NSString *line in lines) {
        if ([line hasPrefix:@"a=rtpmap:"]) {
            bool found = NO;
            for (NSString *audioCodec in CODECS) {
                if ([line containsString:audioCodec]) {
                    NSString *payloadType = [line substringWithRange:NSMakeRange(@"a=rtpmap:".length, [line rangeOfString:@" "].location - @"a=rtpmap:".length)];
                    [payloadTypes addObject:payloadType];
                    found = YES;
                    break;
                }
            }
            if (!found) {
                filtered = YES;
            }
        }
    }
    
    if (!filtered || payloadTypes.count == 0) {
        return sdp;
    }

    // Example produced by Firefox:
    // a=fmtp:109 maxplaybackrate=48000;stereo=1;useinbandfec=1
    // a=fmtp:101 0-15
    // a=fmtp:126 profile-level-id=42e01f;level-asymmetry-allowed=1;packetization-mode=1
    // a=fmtp:97 profile-level-id=42e01f;level-asymmetry-allowed=1
    // a=fmtp:120 max-fs=12288;max-fr=60
    // a=fmtp:124 apt=120
    // a=fmtp:121 max-fs=12288;max-fr=60
    // a=fmtp:125 apt=121
    // a=fmtp:127 apt=126
    // a=fmtp:98 apt=97
    // a=fmtp:119 apt=122
    for (NSString *line in lines) {
        if ([line hasPrefix:@"a=fmtp:"]) {
            NSRange aptPos = [line rangeOfString:@"apt="];
            if (aptPos.length > 0) {
                NSString *payloadType = [line substringWithRange:NSMakeRange(@"a=fmtp:".length, [line rangeOfString:@" "].location - @"a=fmtp:".length)];
                NSString *assignedPayloadType = [line substringFromIndex:aptPos.location + @"apt=".length];
                char lastCharacter = [assignedPayloadType characterAtIndex:assignedPayloadType.length - 1];
                if (lastCharacter == '\r') {
                    assignedPayloadType = [assignedPayloadType substringToIndex:assignedPayloadType.length - 1];
                }
                if ([payloadTypes containsObject:assignedPayloadType]) {
                    [payloadTypes addObject:payloadType];
                } else {
                    // Example with 'a=fmtp:119 apt=122', 122 is not in the accepted list, we must remote 119.
                    [payloadTypes removeObject:payloadType];
                }
            }
        }
    }

    // Example from Firefox:
    // a=rtcp-fb:120 nack
    // a=rtcp-fb:120 nack pli
    // a=rtcp-fb:120 ccm fir
    // a=rtcp-fb:120 goog-remb
    // a=rtcp-fb:120 transport-cc
    // a=rtcp-fb:121 nack
    // a=rtcp-fb:121 nack pli
    // a=rtcp-fb:121 ccm fir
    // a=rtcp-fb:121 goog-remb
    // a=rtcp-fb:121 transport-cc
    // a=rtcp-fb:126 nack
    // a=rtcp-fb:126 nack pli
    // a=rtcp-fb:126 ccm fir
    // a=rtcp-fb:126 goog-remb
    // a=rtcp-fb:126 transport-cc
    // a=rtcp-fb:97 nack
    // a=rtcp-fb:97 nack pli
    // a=rtcp-fb:97 ccm fir
    // a=rtcp-fb:97 goog-remb
    // a=rtcp-fb:97 transport-cc
    // a=rtcp-fb:123 nack
    // a=rtcp-fb:123 nack pli
    // a=rtcp-fb:123 ccm fir
    // a=rtcp-fb:123 goog-remb
    // a=rtcp-fb:123 transport-cc
    // a=rtcp-fb:122 nack
    // a=rtcp-fb:122 nack pli
    // a=rtcp-fb:122 ccm fir
    // a=rtcp-fb:122 goog-remb
    // a=rtcp-fb:122 transport-cc
    // => we want to drop 122, 123 and keep others
    for (int i = 0; i < lines.count; i++) {
        NSString *line = lines[i];
        NSString *payloadType;
        if ([line hasPrefix:@"a=rtpmap:"]) {
            payloadType = [line substringWithRange:NSMakeRange(@"a=rtpmap:".length, [line rangeOfString:@" "].location - @"a=rtpmap:".length)];
        } else if ([line hasPrefix:@"a=rtcp-fb:"]) {
            payloadType = [line substringWithRange:NSMakeRange(@"a=rtcp-fb:".length, [line rangeOfString:@" "].location - @"a=rtcp-fb:".length)];
        } else if ([line hasPrefix:@"a=fmtp:"]) {
            payloadType = [line substringWithRange:NSMakeRange(@"a=fmtp:".length, [line rangeOfString:@" "].location - @"a=fmtp:".length)];
        } else {
            continue;
        }
        if (![payloadTypes containsObject:payloadType]) {
            lines[i] = @"";
        }
    }

    // Example from Firefox:
    // m=audio 9 UDP/TLS/RTP/SAVPF 109 9 0 8 101
    // m=video 0 UDP/TLS/RTP/SAVPF 120 124 121 125 126 127 97 98 123 122 119
    // => we want to drop 0, 8, 9, 101, 122, 123 without changing priority order and generate:
    // m=audio 9 UDP/TLS/RTP/SAVPF 109
    // m=video 0 UDP/TLS/RTP/SAVPF 120 124 121 125 126 127 97 98
    NSMutableString *sdpBuilder = [NSMutableString stringWithCapacity:4048];
    for (int i = 0; i < lines.count; i++) {
        NSString *line = lines[i];
        if (line.length == 0) {
            continue;
        }

        if ([line hasPrefix:@"m=audio "] || [line hasPrefix:@"m=video "]) {
            NSArray<NSString*> *elements = [line componentsSeparatedByString:@" "];
            NSMutableString *lineBuilder = [NSMutableString stringWithCapacity:1024];
            [lineBuilder appendString:elements[0]];
            [lineBuilder appendString:@" "];
            [lineBuilder appendString:elements[1]];
            [lineBuilder appendString:@" "];
            [lineBuilder appendString:elements[2]];
            for (int i = 3; i < elements.count; i++) {
                NSString *element = elements[i];
                char lastCharacter = 0;
                if (i == elements.count - 1) {
                    lastCharacter = [element characterAtIndex:element.length - 1];
                    if (lastCharacter == '\r') {
                        element = [element substringToIndex:element.length - 1];
                    }
                }
                if ([payloadTypes containsObject:element]) {
                    [lineBuilder appendString:@" "];
                    [lineBuilder appendString:element];
                }
                if (lastCharacter == '\r') {
                    [lineBuilder appendString:@"\r"];
                }
            }
            line = lineBuilder;
        }
        [sdpBuilder appendString:line];
        [sdpBuilder appendString:@"\n"];
    }
    return sdpBuilder;

}

/// Create the SDP content from the binary content as received on the wire from the peer.
- (nonnull instancetype)initWithData:(nonnull NSData *)data compressed:(BOOL)compressed keyIndex:(int)keyIndex {
    DDLogVerbose(@"%@ initWithData: %@ compressed: %d keyIndex: %d", LOG_TAG, data, compressed, keyIndex);

    self = [super init];
    if (self) {
        _data = data;
        _compressed = compressed;
        _keyIndex = keyIndex;
    }
    
    return self;
}

/// Create the SDP with the given content and compress it if necessary.
- (nonnull instancetype)initWithSdp:(nonnull NSString *)sdp {
    DDLogVerbose(@"%@ initWithSdp: %@", LOG_TAG, sdp);

    self = [super init];
    if (self) {
        NSData *data = [sdp dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)data.length;
        if (length < COMPRESS_LIMIT) {
            _data = data;
            _compressed = NO;
            _keyIndex = 0;
        } else {
            _keyIndex = 0;
            
            z_stream strm;

            strm.zalloc = Z_NULL;
            strm.zfree = Z_NULL;
            strm.opaque = Z_NULL;
            strm.total_out = 0;
            strm.next_in = (Bytef *)[data bytes];
            strm.avail_in = (unsigned int)length;

            // Don't spend time on compression we better have bigger compressed content
            // but faster compression because sending data can be fast enough on most networks.
            if (deflateInit(&strm, Z_BEST_SPEED) == Z_OK) {

                NSMutableData *compressed = [NSMutableData dataWithLength:length + 2];

                strm.next_out = [compressed mutableBytes] + strm.total_out;
                strm.avail_out = (unsigned int)(length - strm.total_out);

                deflate(&strm, Z_FINISH);

                deflateEnd(&strm);

                if (strm.avail_out > 0) {
                    [compressed setLength:strm.total_out + 2];

                    // Append the de-compressed size at the end so that we help the de-compression
                    // by telling it the size of buffer to allocate.
                    uint8_t value[2];
                    value[0] = (int) (length >> 8);
                    value[1] = (int) (length & 0x0FF);
                    [compressed replaceBytesInRange:NSMakeRange(strm.total_out, 2) withBytes:&value[0] length:2];
                    _data = [NSData dataWithData:compressed];
                    _compressed = YES;
                } else {
                    _data = data;
                    _compressed = NO;
                }
            } else {
                _data = data;
                _compressed = NO;
            }
        }
    }
    
    return self;
}

/// Returns true if the SDP is compressed.
- (BOOL)isCompressed {
    
    return self.compressed;
}

/// Returns true if the SDP is encrypted.
- (BOOL)isEncrypted {
    
    return self.keyIndex > 0;
}

/// Get the key index used for encryption.
- (int)getKeyIndex {
    
    return self.keyIndex;
}

/// Get the SDP in de-compressed and clear form text.
- (nullable NSString *)sdp {
    DDLogVerbose(@"%@ sdp", LOG_TAG);

    if (self.keyIndex > 0) {

        return nil;
    }

    if (self.compressed) {
        int length = (int) self.data.length;

        z_stream strm;
        strm.next_in = (Bytef *)[self.data bytes];
        strm.avail_in = (unsigned int)length - 2;
        strm.total_out = 0;
        strm.zalloc = Z_NULL;
        strm.zfree = Z_NULL;

        if (inflateInit(&strm) != Z_OK) {
            return nil;
        }

        // Get the size of final decompressed SDP by looking at two bytes at end of compressed buffer.
        int8_t b[2];
        [self.data getBytes:&b[0] range:NSMakeRange(length - 2, 2)];
        int len = (int) (b[1] & 0x0FF) + ((int) (b[0] & 0x0FF) << 8);

        NSMutableData *result = [NSMutableData dataWithLength:len];

        strm.next_out = [result mutableBytes] + strm.total_out;
        strm.avail_out = (unsigned int)(len - strm.total_out);

        // Inflate another chunk.
        int status = inflate (&strm, Z_SYNC_FLUSH);
        if (inflateEnd (&strm) != Z_OK || status != Z_STREAM_END) {
            return nil;
        }

        return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];

    } else {
        return [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
    }
}

/// Get the transport candidates defined in the sdp.
- (nullable NSArray<TLTransportCandidate *> *)candidates {
    DDLogVerbose(@"%@ candidates", LOG_TAG);

    NSString *sdp = [self sdp];
    if (!sdp) {
        
        return nil;
    }

    NSArray<NSString *> *lines = [sdp componentsSeparatedByString:@"\r"];
    NSMutableArray<TLTransportCandidate *> *result = [[NSMutableArray alloc] initWithCapacity:lines.count];
    for (int i = 0; i < lines.count; i++) {
        NSString *candidate = lines[i];
        int length = (int)[candidate length];
        BOOL removed = [candidate characterAtIndex:0] == '-';
        NSRange pos = [candidate rangeOfString:@"\t"];
        NSString *label = @"";
        int ident = 0;
        sdp = @"";
        if (pos.length == 1) {
            label = [candidate substringWithRange:NSMakeRange(1, pos.location - 1)];
            NSRange pos2 = [candidate rangeOfString:@"\t" options:0 range:NSMakeRange(pos.location + 1, length - pos.location - 1)];
            if (pos2.length == 1) {
                ident = (int) [[candidate substringWithRange:NSMakeRange(pos.location + 1, pos2.location - pos.location)] integerValue];
                sdp = [TLTransportCandidateList expand:[candidate substringFromIndex:pos2.location + 1]];
            }
        }
        [result addObject:[[TLTransportCandidate alloc] initWithId:ident label:label sdp:sdp removed:removed]];
    }
    return result;
}

@end

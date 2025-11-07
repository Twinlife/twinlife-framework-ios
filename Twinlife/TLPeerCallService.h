/*
 *  Copyright (c) 2022-2025 twinlife SA.
 *  SPDX-License-Identifier: AGPL-3.0-only
 *
 *  Contributors:
 *   Stephane Carrez (Stephane.Carrez@twin.life)
 */

#import "TLBaseService.h"

typedef enum {
    TLMemberStatusNew,             // member is new
    TLMemberStatusNewNeedSession,  // member is new and a P2P session is necessary
    TLMemberStatusRemoved          // member is removed
} TLMemberStatus;

//
// Interface: TLPeerCallMemberInfo
//

@interface TLPeerCallMemberInfo : NSObject

@property (readonly) TLMemberStatus status;
@property (readonly, nonnull) NSString *memberId;
@property (readonly, nullable) NSUUID *p2pSessionId;

- (nonnull instancetype)initWithMemberId:(nonnull NSString *)memberId;

- (nonnull instancetype)initWithMemberId:(nonnull NSString *)memberId p2pSessionId:(nonnull NSUUID *)p2pSessionId;

@end

//
// Interface: TLPeerSessionInfo
//

@interface TLPeerSessionInfo : NSObject

@property (readonly, nonnull) NSUUID *p2pSessionId;
@property (readonly, nullable) NSString *peerId;

- (nonnull instancetype)initWithSessionId:(nonnull NSUUID *)sessionId peerId:(nullable NSString *)peerId;

@end

//
// Protocol: TLPeerCallServiceDelegate
//

@protocol TLPeerCallServiceDelegate <TLBaseServiceDelegate>

@optional

- (void)onCreateCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId mode:(int)mode maxMemberCount:(int)maxMemberCount;

- (void)onInviteCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId p2pSessionId:(nullable NSUUID *)p2pSessionId mode:(int)mode maxMemberCount:(int)maxMemberCount;

- (void)onJoinCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId members:(nonnull NSArray<TLPeerCallMemberInfo *> *)members;

- (void)onLeaveCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId;

- (void)onMemberJoinCallRoomWithCallRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId p2pSessionId:(nullable NSUUID *)p2pSessionId status:(TLMemberStatus)status;

- (void)onTransferDone;

@end

//
// Interface: TLPeerCallServiceConfiguration
//

@interface TLPeerCallServiceConfiguration : TLBaseServiceConfiguration

@end

//
// Interface: TLPeerCallService
//

@interface TLPeerCallService : TLBaseService

+ (nonnull NSString *)VERSION;

/// Create a call room with the given twincode identification.  The user must be owner of that twincode.
/// A list of member twincode with their optional P2P session id can be passed and those members are invited
/// to join the room.  Members that are invited will receive a call to their `onInviteCallRoom` callback.
///
/// @param requestId the request identifier.
/// @param twincodeOutboundId the owner twincode.
/// @param members the list of members to invite.
- (void)createCallRoomWithRequestId:(int64_t)requestId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId members:(nonnull NSDictionary<NSString *, NSUUID *> *)members;

/// Invite a new member in the call room.  Similar to `createCallRoom` to invite another member in the call room.
///
/// @param requestId the request identifier.
/// @param callRoomId the call room.
/// @param twincodeOutboundId the member to invite.
/// @param p2pSessionId the optional P2P session with that member.
- (void)inviteCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeOutboundId:(nonnull NSUUID *)twincodeOutboundId p2pSessionId:(nonnull NSUUID *)p2pSessionId;

/// Join the call room after having received an invitation through `onInviteCallRoom`.
/// The `twincodeOut` must be owned by the current user and represents the current user in the call room.
///
/// @param requestId the request identifier.
/// @param callRoomId the call room to join.
/// @param twincodeInboundId the member twincode.
/// @param p2pSessionIds the optional P2P sessions that we have with the call room members.
- (void)joinCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId twincodeInboundId:(nonnull NSUUID *)twincodeInboundId p2pSessionIds:(nonnull NSArray<TLPeerSessionInfo *> *)p2pSessionIds;

/// Leave the call room.
///
/// @param requestId the request identifier.
/// @param callRoomId the call room to leave.
/// @param memberId the member id to remove.
- (void)leaveCallRoomWithRequestId:(int64_t)requestId callRoomId:(nonnull NSUUID *)callRoomId memberId:(nonnull NSString *)memberId;

- (void)transferDone;

@end

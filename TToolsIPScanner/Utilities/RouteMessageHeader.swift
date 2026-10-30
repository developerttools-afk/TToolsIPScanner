import Foundation

/// Layout of the kernel `rt_msghdr`. The iOS SDK does not publish `<net/route.h>`,
/// so iOS uses this copy. A Mac test checks that it still matches the SDK struct.
struct RouteMessageHeader {
    var rtm_msglen: UInt16
    var rtm_version: UInt8
    var rtm_type: UInt8
    var rtm_index: UInt16
    var rtm_flags: Int32
    var rtm_addrs: Int32
    var rtm_pid: Int32
    var rtm_seq: Int32
    var rtm_errno: Int32
    var rtm_use: Int32
    var rtm_inits: UInt32
    var rtm_rmx: RouteMetrics
}

struct RouteMetrics {
    var rmx_locks: UInt32
    var rmx_mtu: UInt32
    var rmx_hopcount: UInt32
    var rmx_expire: Int32
    var rmx_recvpipe: UInt32
    var rmx_sendpipe: UInt32
    var rmx_ssthresh: UInt32
    var rmx_rtt: UInt32
    var rmx_rttvar: UInt32
    var rmx_pksent: UInt32
    var rmx_filler0: UInt32
    var rmx_filler1: UInt32
    var rmx_filler2: UInt32
    var rmx_filler3: UInt32
}

#if os(iOS)
typealias rt_msghdr = RouteMessageHeader
let RTF_LLINFO: Int32 = 0x400
let RTA_DST: Int32 = 0x1
let RTA_GATEWAY: Int32 = 0x2
#endif

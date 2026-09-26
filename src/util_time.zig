//! 跨 zig 0.17 版本取 Unix 秒的小工具。

const std = @import("std");

pub fn unixNow() i64 {
    var ts: std.c.timespec = .{ .sec = 0, .nsec = 0 };
    _ = std.c.clock_gettime(.REALTIME, &ts);
    return @intCast(ts.sec);
}

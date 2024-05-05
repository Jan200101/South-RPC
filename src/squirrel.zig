const std = @import("std");
const windows = std.os.windows;

const Class = @import("class.zig").Class;

pub const ScriptContext = enum(c_int) {
    SC_SERVER,
    SC_CLIENT,
    SC_UI,
};

pub const SQObject = extern struct {
    type: c_int,
    structNumber: c_int,
    value: *void,
};

pub const CSquirrelVM = Class(.{}, .{
    .unknown = .{ .type = void, .virtual = true },

    .sqvm = .{ .type = void },
    .gap_10 = .{ .type = [8]u8 },
    .unkObj = .{ .type = SQObject },
    .gap_30 = .{ .type = [12]u8 },
    .context = .{ .type = ScriptContext },
    .gap_40 = .{ .type = [648]u8 },
    .formatString = .{ .type = *const fn (i64, [*]const u8, ...) callconv(.C) [*]u8 },
    .gap_2D0 = .{ .type = [24]u8 },
});

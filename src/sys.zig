const std = @import("std");
const windows = std.os.windows;

const interface = @import("interface.zig");
const northstar = @import("northstar.zig");

const Class = @import("class.zig").Class;

const CSys = Class(.{}, .{
    .log = .{ .type = *const fn (*anyopaque, ?windows.HMODULE, LogLevel, [*:0]const u8) callconv(.C) void, .virtual = true },
    .unload = .{ .type = *const fn (*anyopaque, ?windows.HMODULE) callconv(.C) void, .virtual = true },
    .reload = .{ .type = *const fn (*anyopaque, ?windows.HMODULE) callconv(.C) void, .virtual = true },
});

var sys: ?*CSys = null;

pub const LogLevel = enum(c_int) { LOG_INFO, LOG_WARN, LOG_ERR };

pub fn init() void {
    sys = @ptrCast(@alignCast(northstar.create_interface.?("NSSys001", null)));
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const log_level: LogLevel = switch (level) {
        .err => LogLevel.LOG_ERR,
        .warn => LogLevel.LOG_WARN,
        .info => LogLevel.LOG_INFO,
        .debug => LogLevel.LOG_INFO,
    };

    const msg = std.fmt.allocPrintZ(allocator, format, args) catch unreachable;

    if (sys) |s| {
        s.*.vtable.log(s, northstar.data.handle, log_level, msg);
    }
}

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
    if (northstar.create_interface) |create_interface| {
        var status: interface.InterfaceStatus = .IFACE_OK;
        sys = @ptrCast(@alignCast(create_interface("NSSys001", &status)));

        if (status != .IFACE_OK) {
            std.log.err("Failed to create NSSys001 interface: {}", .{status});
        }
    } else {
        std.log.err("Failed to create NSSys001 interface: {s}", .{"Failed to resolve CreateInterface"});
    }
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = switch (scope) {
        std.log.default_log_scope => "",
        else => "(" ++ @tagName(scope) ++ ")",
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const log_level: LogLevel = switch (level) {
        .err => LogLevel.LOG_ERR,
        .warn => LogLevel.LOG_WARN,
        .info => LogLevel.LOG_INFO,
        .debug => LogLevel.LOG_INFO,
    };

    const msg = std.fmt.allocPrintZ(allocator, scope_prefix ++ format, args) catch unreachable;

    if (sys) |s| {
        s.vtable.log(s, northstar.data.handle, log_level, msg);
    } else {
        //  Northstar log has not been established, fallback to default log
        std.log.defaultLog(level, scope, format, args);
    }
}

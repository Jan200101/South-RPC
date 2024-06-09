const std = @import("std");
const windows = std.os.windows;

const Class = @import("class.zig").Class;

const interface = @import("interface.zig");
const client = @import("client.zig");

const CGameConsole = Class(.{}, .{
    .unknown = .{ .type = void, .virtual = true },

    .initialized = .{ .type = bool },
    .console = .{ .type = ?*const CConsoleDialog },
});

const CConsoleDialog = Class(.{}, .{
    .unknown = .{ .type = void, .virtual = true },

    .padding = .{ .type = [0x398]u8 },
    .console_panel = .{ .type = ?*const CConsolePanel },
});

const CConsolePanel = Class(.{}, .{
    .editable_panel = .{ .type = EditablePanel },
    .iconsole_display_func = .{ .type = IConsoleDisplayFunc },
});

const EditablePanel = Class(.{}, .{
    .unknown = .{ .type = void, .virtual = true },

    .padding = .{ .type = [0x2B0]u8 },
});

const IConsoleDisplayFunc = Class(.{}, .{
    .color_print = .{ .type = *const fn (this: *anyopaque) callconv(.C) void, .virtual = true },
    .print = .{ .type = *const fn (this: *anyopaque, message: [*:0]const u8) callconv(.C) void, .virtual = true },
    .dprint = .{ .type = *const fn (this: *anyopaque, message: [*:0]const u8) callconv(.C) void, .virtual = true },
});

pub fn hook() void {
    const client_create_interface = client.create_interface orelse {
        std.log.err("Client CreateInterface not resolved, cannot hook game console", .{});
        return;
    };

    var status: interface.InterfaceStatus = .IFACE_OK;
    const pgame_console: ?*CGameConsole = @ptrCast(@alignCast(client_create_interface("GameConsole004", &status)));
    if (pgame_console == null or status != .IFACE_OK) {
        std.log.err("Failed to create GameConsole004 interface: {}", .{status});
        return;
    }
    const game_console = pgame_console.?;

    if (!game_console.initialized) {
        std.log.warn("Game console is not initialized yet, waiting for it", .{});
        while (!game_console.initialized) {}
        std.log.info("Game console is now initialized", .{});
    }

    const display_func = blk: {
        if (game_console.console) |console| {
            if (console.console_panel) |console_panel| {
                break :blk console_panel.iconsole_display_func;
            }
        }

        break :blk null;
    };

    const print = blk: {
        if (display_func) |func| {
            if (func.vtable) |vtable| {
                break :blk vtable.print;
            }
        }

        break :blk null;
    };

    _ = print;
}

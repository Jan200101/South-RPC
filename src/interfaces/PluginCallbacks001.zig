const std = @import("std");
const windows = std.os.windows;

const Class = @import("../class.zig").Class;

const interface = @import("../interface.zig");
const northstar = @import("../northstar.zig");
const squirrel = @import("../squirrel.zig");
const sys = @import("../sys.zig");
const server = @import("../server.zig");
const engine = @import("../engine.zig");

const CSquirrelVM = squirrel.CSquirrelVM;

pub const plugin_interface = .{
    .name = "PluginCallbacks001",
    .func = CreatePluginCallbacks,
};

pub fn CreatePluginCallbacks() *void {
    return @ptrCast(
        @constCast(
            &IPluginCallbacks{
                .vtable = &.{
                    .Init = Init,
                    .Finalize = Finalize,
                    .Unload = Unload,
                    .OnSqvmCreated = OnSqvmCreated,
                    .OnSqvmDestroyed = OnSqvmDestroyed,
                    .OnLibraryLoaded = OnLibraryLoaded,
                    .RunFrame = RunFrame,
                },
            },
        ),
    );
}

pub const IPluginCallbacks = Class(.{}, .{
    .Init = .{ .type = *const fn (*anyopaque, windows.HMODULE, *northstar.NorthstarData, u8) callconv(.C) void, .virtual = true },
    .Finalize = .{ .type = *const fn (*anyopaque) callconv(.C) void, .virtual = true },
    .Unload = .{ .type = *const fn (*anyopaque) callconv(.C) bool, .virtual = true },
    .OnSqvmCreated = .{ .type = *const fn (*anyopaque, *CSquirrelVM) callconv(.C) void, .virtual = true },
    .OnSqvmDestroyed = .{ .type = *const fn (*anyopaque, *CSquirrelVM) callconv(.C) void, .virtual = true },
    .OnLibraryLoaded = .{ .type = *const fn (*anyopaque, windows.HMODULE, [*:0]const u8) callconv(.C) void, .virtual = true },
    .RunFrame = .{ .type = *const fn (*anyopaque) callconv(.C) void, .virtual = true },
});

pub fn Init(self: *anyopaque, module: windows.HMODULE, data: *northstar.NorthstarData, reloaded: u8) callconv(.C) void {
    _ = self;

    northstar.init(module, data);
    sys.init();

    if (reloaded != 0) {
        server.stop();
    }

    if (!server.running) {
        server.start() catch std.log.err("Failed to start HTTP Server", .{});
    }

    std.log.info("Loaded", .{});
}

pub fn Finalize(self: *anyopaque) callconv(.C) void {
    _ = self;
}

pub fn Unload(self: *anyopaque) callconv(.C) bool {
    _ = self;

    server.stop();

    return true;
}

pub fn OnSqvmCreated(self: *anyopaque, c_sqvm: *CSquirrelVM) callconv(.C) void {
    _ = self;

    std.log.info("created {s} sqvm", .{@tagName(c_sqvm.context)});
}

pub fn OnSqvmDestroyed(self: *anyopaque, c_sqvm: *CSquirrelVM) callconv(.C) void {
    _ = self;

    std.log.info("destroyed {s} sqvm", .{@tagName(c_sqvm.context)});
}

pub fn OnLibraryLoaded(self: *anyopaque, module: windows.HMODULE, name_ptr: [*:0]const u8) callconv(.C) void {
    _ = self;

    const name = std.mem.span(name_ptr);

    if (std.mem.eql(u8, name, "engine.dll")) {
        engine.Cbuf = .{
            .GetCurrentPlayer = @ptrFromInt(@intFromPtr(module) + 0x120630),
            .AddText = @ptrFromInt(@intFromPtr(module) + 0x1203B0),
            .Execute = @ptrFromInt(@intFromPtr(module) + 0x1204B0),
        };
    }
}

pub fn RunFrame(self: *anyopaque) callconv(.C) void {
    _ = self;
}

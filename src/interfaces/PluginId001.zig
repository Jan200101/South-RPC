const std = @import("std");
const Class = @import("../class.zig").Class;

pub const plugin_interface = .{
    .name = "PluginId001",
    .func = CreatePluginId,
};

fn CreatePluginId() *void {
    return @ptrCast(
        @constCast(
            &IPluginId{
                .vtable = &.{
                    .GetString = GetString,
                    .GetField = GetField,
                },
            },
        ),
    );
}

pub const IPluginId = Class(.{}, .{
    .GetString = .{ .type = *const fn (*anyopaque, PluginString) callconv(.C) ?[*:0]const u8, .virtual = true },
    .GetField = .{ .type = *const fn (*anyopaque, PluginField) callconv(.C) i64, .virtual = true },
});

const PluginString = enum(c_int) {
    ID_NAME = 0,
    ID_LOG_NAME,
    ID_DEPENDENCY_NAME,
    _,
};

const PluginField = enum(c_int) {
    ID_CONTEXT = 0,
    _,
};

const PluginContext = enum(i64) {
    PCTX_DEDICATED = 0x1, // load on dedicated servers
    PCTX_CLIENT = 0x2, // load on clients
    _,
};

pub fn GetString(self: *anyopaque, prop: PluginString) callconv(.C) ?[*:0]const u8 {
    _ = self;

    switch (prop) {
        .ID_NAME => return @import("root").PLUGIN_NAME,
        .ID_LOG_NAME => return @import("root").LOG_NAME,
        .ID_DEPENDENCY_NAME => return @import("root").DEPENDENCY_NAME,
        else => return null,
    }
}

pub fn GetField(self: *anyopaque, prop: PluginField) callconv(.C) i64 {
    _ = self;

    switch (prop) {
        .ID_CONTEXT => {
            return @intFromEnum(PluginContext.PCTX_DEDICATED) | @intFromEnum(PluginContext.PCTX_CLIENT);
        },
        else => return 0,
    }
}

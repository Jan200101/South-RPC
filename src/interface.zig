const std = @import("std");

const PluginCallbacks001 = @import("interfaces/PluginCallbacks001.zig").plugin_interface;
const PluginId001 = @import("interfaces/PluginId001.zig").plugin_interface;

pub const GetInterfaceType = ?*const fn ([*:0]const u8, ?*const InterfaceStatus) callconv(.C) *anyopaque;

pub const interfaces = .{
    PluginCallbacks001,
    PluginId001,
};

pub const InterfaceStatus = enum(c_int) {
    IFACE_OK = 0,
    IFACE_FAILED,
};

pub export fn CreateInterface(name_ptr: [*:0]const u8, status_ptr: ?*InterfaceStatus) callconv(.C) *allowzero void {
    const name = std.mem.span(name_ptr);

    inline for (interfaces) |interface| {
        if (std.mem.eql(u8, interface.name, name)) {
            if (status_ptr) |status| {
                status.* = .IFACE_OK;
            }

            return interface.func();
        }
    }

    if (status_ptr) |status| {
        status.* = .IFACE_FAILED;
    }

    return @ptrFromInt(0);
}

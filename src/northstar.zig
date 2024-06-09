const std = @import("std");
const windows = std.os.windows;

const interface = @import("interface.zig");

pub const NorthstarData = extern struct {
    handle: ?windows.HMODULE,
};

pub var plugin_handle: ?windows.HMODULE = null;

pub var create_interface: interface.GetInterfaceType = null;

pub fn init(ns_module: windows.HMODULE, init_data: *NorthstarData) void {
    create_interface = @ptrCast(windows.kernel32.GetProcAddress(ns_module, "CreateInterface"));
    plugin_handle = init_data.*.handle;
}

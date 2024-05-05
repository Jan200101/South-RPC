const std = @import("std");
const windows = std.os.windows;

const interface = @import("interface.zig");

pub const NorthstarData = extern struct {
    handle: ?windows.HMODULE,
};

pub var data: NorthstarData = .{
    .handle = null,
};

pub var create_interface: ?*const fn ([*:0]const u8, ?*const interface.InterfaceStatus) callconv(.C) *anyopaque = null;

pub fn init(ns_module: windows.HMODULE, init_data: *NorthstarData) void {
    create_interface = @ptrCast(windows.kernel32.GetProcAddress(ns_module, "CreateInterface"));
    data.handle = init_data.*.handle;
}

const std = @import("std");
const windows = std.os.windows;

const interface = @import("interface.zig");

pub var handle: ?windows.HMODULE = null;

pub var create_interface: interface.GetInterfaceType = null;

pub fn init(module: windows.HMODULE) void {
    create_interface = @ptrCast(windows.kernel32.GetProcAddress(module, "CreateInterface"));
}

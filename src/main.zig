const std = @import("std");

pub const PLUGIN_NAME = "Zig Plugin";
pub const LOG_NAME = "ZIGPLUGIN";
pub const DEPENDENCY_NAME = "ZigPlugin";

pub const std_options = struct {
    // Set the log level to info
    pub const log_level = .info;
    // Define logFn to override the std implementation
    pub const logFn = @import("sys.zig").log;
};

comptime {
    _ = @import("interface.zig");
}

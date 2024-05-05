const std = @import("std");

const server = @import("../server.zig");
const RpcMethods = server.RpcMethods;

const Allocator = std.mem.Allocator;

pub const method = .{
    .name = "list_methods",
    .func = list_methods,
};

fn list_methods(allocator: Allocator, params: ?std.json.Value) !?std.json.Value {
    _ = allocator;
    _ = params;

    return null;
}

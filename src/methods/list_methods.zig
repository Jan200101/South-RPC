const std = @import("std");

const rpc_server = @import("../rpc_server.zig");
const RpcMethods = rpc_server.RpcMethods;

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

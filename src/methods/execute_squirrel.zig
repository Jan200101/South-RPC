const std = @import("std");

const squirrel = @import("../squirrel.zig");

const Allocator = std.mem.Allocator;

pub const method = .{
    .name = "execute_squirrel",
    .func = execute_squirrel,
};

fn execute_squirrel(allocator: Allocator, params: ?std.json.Value) !?std.json.Value {
    if (params == null or params.? != .object) {
        return error.InvalidParameters;
    }

    const object = params.?.object;

    const context = blk: {
        const context_object = object.get("context");
        if (context_object != null and context_object.? == .string) {
            const context_string = context_object.?.string;

            if (std.mem.eql(u8, context_string, "server")) {
                break :blk squirrel.ScriptContext.SC_SERVER;
            } else if (std.mem.eql(u8, context_string, "client")) {
                break :blk squirrel.ScriptContext.SC_CLIENT;
            } else if (std.mem.eql(u8, context_string, "ui")) {
                break :blk squirrel.ScriptContext.SC_UI;
            }

            return error.InvalidContext;
        }

        break :blk squirrel.ScriptContext.SC_UI;
    };
    _ = context;

    return .{
        .string = "test",
    };
}

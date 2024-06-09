const std = @import("std");

const engine = @import("../engine.zig");

const Allocator = std.mem.Allocator;

pub const method = .{
    .name = "execute_command",
    .func = execute_command,
};

fn execute_command(allocator: Allocator, params: ?std.json.Value) !?std.json.Value {
    if (params == null) {
        return error.InvalidParameters;
    }

    const command = blk: {
        const command_item = switch (params.?) {
            .array => param_blk: {
                const command_array = params.?.array;

                if (command_array.capacity < 1) {
                    return error.NoCommand;
                }

                break :param_blk command_array.items[0];
            },

            .object => param_blk: {
                const command_object = params.?.object;

                break :param_blk command_object.get("command") orelse return error.NoCommand;
            },

            else => return error.NoCommand,
        };

        if (command_item != .string) {
            return error.InvalidCommand;
        }

        break :blk try allocator.dupeZ(u8, command_item.string);
    };
    defer allocator.free(command);

    if (engine.Cbuf) |Cbuf| {
        const cur_player = Cbuf.GetCurrentPlayer();
        Cbuf.AddText(cur_player, command, .kCommandSrcCode);
    } else {
        return error.NoEngine;
    }

    return null;
}

const std = @import("std");

const http = std.http;
const Server = http.Server;
const NetServer = std.net.Server;
const Thread = std.Thread;

const max_header_size = 8192;

pub var running = false;
var server_thread: ?Thread = null;

var gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};
var allocator = gpa.allocator();

const execute_command = @import("methods/execute_command.zig").method;
const list_methods = @import("methods/list_methods.zig").method;

const server_log = std.log.scoped(.http_server);

pub const RpcMethods = .{
    execute_command,
    list_methods,
};

const JsonRpcRequest = struct {
    jsonrpc: []const u8,
    method: []const u8,
    params: ?std.json.Value = null,
    id: ?std.json.Value = null,
};

const JsonRpcError = struct {
    code: isize,
    message: []const u8,
    data: ?std.json.Value = null,
};

const JsonRpcResponse = struct {
    jsonrpc: []const u8,
    result: ?std.json.Value = null,
    @"error": ?JsonRpcError = null,
    id: ?std.json.Value = null,
};

fn handleRequest(request: *Server.Request) !void {
    server_log.info("{s} {s} {s}", .{ @tagName(request.head.method), @tagName(request.head.version), request.head.target });

    if (!std.mem.startsWith(u8, request.head.target, "/rpc")) {
        try request.respond("not found", .{
            .status = .not_found,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        return;
    }

    const reader = try request.reader();
    const body = try reader.readAllAlloc(allocator, 8192);
    defer allocator.free(body);

    const resp = blk: {
        var response: JsonRpcResponse = .{
            .jsonrpc = "2.0",
        };

        const parsed = std.json.parseFromSlice(JsonRpcRequest, allocator, body, .{}) catch |err| {
            server_log.err("Failed to parse request body {}", .{err});

            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }

            response.@"error" = .{
                .code = -32700,
                .message = "Parse error",
            };

            break :blk response;
        };
        defer parsed.deinit();

        var data = parsed.value;

        if (data.id) |request_id| {
            if (request_id != .integer and request_id != .string) {
                data.id = null;
            }
        }
        response.id = data.id;

        if (data.params) |request_params| {
            if (request_params != .object and request_params != .array) {
                response.@"error" = .{
                    .code = -32602,
                    .message = "Invalid params",
                };

                break :blk response;
            }
        }

        inline for (RpcMethods) |method| {
            if (std.mem.eql(u8, method.name, data.method)) {
                response.result = method.func(allocator, data.params) catch |err| method_blk: {
                    response.@"error" = .{
                        .code = -32603,
                        .message = @errorName(err),
                    };
                    break :method_blk null;
                };
                break;
            }
        } else {
            response.@"error" = .{
                .code = -32601,
                .message = "Method not found",
            };
        }

        break :blk response;
    };

    const json_resp = try std.json.stringifyAlloc(allocator, resp, .{});
    defer allocator.free(json_resp);

    try request.respond(json_resp, .{
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json." },
        },
    });
}
fn serverThread(addr: std.net.Address) !void {
    var read_buffer: [8000]u8 = undefined;
    var http_server = try addr.listen(.{});

    accept: while (true) {
        const connection = try http_server.accept();
        defer connection.stream.close();

        var server = std.http.Server.init(connection, &read_buffer);
        while (server.state == .ready) {
            var request = server.receiveHead() catch |err| {
                std.debug.print("error: {s}\n", .{@errorName(err)});
                continue :accept;
            };
            try handleRequest(&request);
        }
    }
}

pub fn start() !void {
    if (server_thread == null) {
        const addr = try std.net.Address.parseIp("127.0.0.1", 26505);

        running = true;
        server_thread = try Thread.spawn(.{}, serverThread, .{addr});

        server_log.info("Started HTTP Server on {}", .{addr});
    }
}

pub fn stop() void {
    if (server_thread) |thread| {
        running = false;
        thread.join();

        server_log.info("Stopped HTTP Server", .{});
    }
}

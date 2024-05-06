const std = @import("std");

const http = std.http;
const Server = http.Server;
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

fn handleRequest(res: *Server.Response) !void {
    server_log.info("{s} {s} {s}", .{ @tagName(res.request.method), @tagName(res.request.version), res.request.target });

    if (!std.mem.startsWith(u8, res.request.target, "/rpc")) {
        res.status = .not_found;
        try res.do();
        return;
    }

    const body = try res.reader().readAllAlloc(allocator, 8192);
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

        var request = parsed.value;

        if (request.id) |request_id| {
            if (request_id != .integer and request_id != .string) {
                request.id = null;
            }
        }
        response.id = request.id;

        if (request.params) |request_params| {
            if (request_params != .object and request_params != .array) {
                response.@"error" = .{
                    .code = -32602,
                    .message = "Invalid params",
                };

                break :blk response;
            }
        }

        inline for (RpcMethods) |method| {
            if (std.mem.eql(u8, method.name, request.method)) {
                response.result = method.func(allocator, request.params) catch |err| method_blk: {
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
    res.transfer_encoding = .{ .content_length = json_resp.len };

    try res.do();
    try res.writeAll(json_resp);
    try res.finish();
}

fn runServer(srv: *Server) !void {
    outer: while (running) {
        var res = try srv.accept(.{
            .allocator = allocator,
            .header_strategy = .{ .dynamic = max_header_size },
        });
        defer res.deinit();

        while (res.reset() != .closing) {
            res.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            try handleRequest(&res);
        }
    }
}

fn serverThread(addr: std.net.Address) !void {
    var server = Server.init(allocator, .{ .reuse_address = true });

    try server.listen(addr);
    defer server.deinit();

    defer _ = gpa.deinit();

    runServer(&server) catch |err| {
        server_log.err("server error: {}\n", .{err});

        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }

        _ = gpa.deinit();
        std.os.exit(1);
    };
}

pub fn start() !void {
    if (server_thread == null) {
        var addr = try std.net.Address.parseIp("127.0.0.1", 26505);

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

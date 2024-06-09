const std = @import("std");
const windows = std.os.windows;

pub const ECommandTarget_t = enum(c_int) {
    CBUF_FIRST_PLAYER = 0,
    CBUF_LAST_PLAYER = 1, // MAX_SPLITSCREEN_CLIENTS - 1, MAX_SPLITSCREEN_CLIENTS = 2
    CBUF_SERVER, // CBUF_LAST_PLAYER + 1

    CBUF_COUNT,
};

pub const cmd_source_t = enum(c_int) {
    // Added to the console buffer by gameplay code.  Generally unrestricted.
    kCommandSrcCode,

    // Sent from code via engine->ClientCmd, which is restricted to commands visible
    // via FCVAR_GAMEDLL_FOR_REMOTE_CLIENTS.
    kCommandSrcClientCmd,

    // Typed in at the console or via a user key-bind.  Generally unrestricted, although
    // the client will throttle commands sent to the server this way to 16 per second.
    kCommandSrcUserInput,

    // Came in over a net connection as a clc_stringcmd
    // host_client will be valid during this state.
    //
    // Restricted to FCVAR_GAMEDLL commands (but not convars) and special non-ConCommand
    // server commands hardcoded into gameplay code (e.g. "joingame")
    kCommandSrcNetClient,

    // Received from the server as the client
    //
    // Restricted to commands with FCVAR_SERVER_CAN_EXECUTE
    kCommandSrcNetServer,

    // Being played back from a demo file
    //
    // Not currently restricted by convar flag, but some commands manually ignore calls
    // from this source.  FIXME: Should be heavily restricted as demo commands can come
    // from untrusted sources.
    kCommandSrcDemoFile,

    // Invalid value used when cleared
    kCommandSrcInvalid = -1,
};

pub const CbufType = struct {
    GetCurrentPlayer: *const fn () callconv(.C) ECommandTarget_t,
    AddText: *const fn (ECommandTarget_t, [*:0]const u8, cmd_source_t) callconv(.C) void,
    Execute: *const fn () callconv(.C) void,
};

pub var Cbuf: ?CbufType = null;

pub fn init(module: windows.HMODULE) void {
    Cbuf = .{
        .GetCurrentPlayer = @ptrFromInt(@intFromPtr(module) + 0x120630),
        .AddText = @ptrFromInt(@intFromPtr(module) + 0x1203B0),
        .Execute = @ptrFromInt(@intFromPtr(module) + 0x1204B0),
    };
}
